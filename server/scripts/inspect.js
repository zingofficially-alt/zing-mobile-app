require('dotenv').config({path: __dirname + '/../.env'});
const {initializeApp, cert} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {getAuth} = require('firebase-admin/auth');
const {getStorage} = require('firebase-admin/storage');
const sa = require(require('path').resolve(__dirname, '..', process.env.FIREBASE_SERVICE_ACCOUNT));
initializeApp({credential: cert(sa), storageBucket: sa.project_id + '.appspot.com'});
const db = getFirestore();
(async () => {
  const cols = await db.listCollections();
  for (const c of cols) {
    const snap = await c.limit(500).get();
    const keys = {};
    const subs = new Set();
    for (const d of snap.docs) {
      for (const [k, v] of Object.entries(d.data())) {
        const t = v === null ? 'null' : Array.isArray(v) ? 'array' : (v && v.toDate) ? 'timestamp' : (v && v.latitude !== undefined) ? 'geopoint' : (v && v._path) ? 'ref' : typeof v;
        (keys[k] = keys[k] || new Set()).add(t);
      }
      (await d.ref.listCollections()).forEach(s => subs.add(s.id));
    }
    console.log(`\n== ${c.id} (${snap.size}${snap.size === 500 ? '+' : ''} docs) subcollections: ${[...subs].join(',') || '-'}`);
    for (const [k, t] of Object.entries(keys)) console.log(`  ${k}: ${[...t].join('|')}`);
  }
  const u = await getAuth().listUsers(1000);
  const prov = {};
  u.users.forEach(x => x.providerData.forEach(p => prov[p.providerId] = (prov[p.providerId] || 0) + 1));
  console.log('\nAuth users:', u.users.length, prov);
  const [files] = await getStorage().bucket().getFiles({maxResults: 1000}).catch(e => [[e.message]]);
  console.log('Storage files:', files.length, files.slice(0,5).map(f => f.name || f));
})().catch(e => { console.error('ERR', e.message); process.exit(1); });
