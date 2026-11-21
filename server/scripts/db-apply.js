// Usage: node scripts/db-apply.js <sql-file>   (reads SUPABASE_DB_* from server/.env)
require('dotenv').config({path: __dirname + '/../.env', quiet: true});
const fs = require('fs');
const {Client} = require('pg');
const e = process.env;

const targets = [
  {host: e.SUPABASE_DB_HOST, port: 5432, user: e.SUPABASE_DB_USER},
  ...(e.SUPABASE_POOLER_HOST
    ? [{host: e.SUPABASE_POOLER_HOST, port: 5432, user: `postgres.${e.SUPABASE_PROJECT_REF}`}]
    : []),
];

(async () => {
  for (const t of targets) {
    const c = new Client({
      ...t,
      password: e.SUPABASE_DB_PASSWORD,
      database: e.SUPABASE_DB_NAME,
      ssl: {rejectUnauthorized: false},
      connectionTimeoutMillis: 15000,
    });
    try {
      await c.connect();
      console.log('connected via', t.host);
      await c.query(fs.readFileSync(process.argv[2], 'utf8'));
      console.log('applied', process.argv[2]);
      await c.end();
      return;
    } catch (err) {
      console.log(t.host, '->', err.code || '', err.message);
      try { await c.end(); } catch {}
    }
  }
  process.exit(1);
})();
