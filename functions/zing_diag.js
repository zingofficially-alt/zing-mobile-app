/**
 * ZING — Vertex AI Retail Full Diagnostic
 * Run: GOOGLE_APPLICATION_CREDENTIALS=/tmp/zing-diag-key.json node zing_diag.js
 */
const {
  ProductServiceClient,
  ModelServiceClient,
  ServingConfigServiceClient,
  PredictionServiceClient,
  UserEventServiceClient,
} = require('@google-cloud/retail').v2;

const PARENT = 'projects/zing-262ad/locations/global/catalogs/default_catalog';
const BRANCH = PARENT + '/branches/0';

function pass(msg) { console.log('  PASS  ' + msg); }
function fail(msg) { console.log('  FAIL  ' + msg); }
function warn(msg) { console.log('  WARN  ' + msg); }
function info(msg) { console.log('  INFO  ' + msg); }

async function checkCatalog() {
  console.log('\n[1] Catalog Products');
  const client = new ProductServiceClient();
  try {
    const iterable = client.listProductsAsync({ parent: BRANCH, pageSize: 5 });
    const items = [];
    for await (const item of iterable) {
      items.push(item);
      if (items.length >= 20) break;
    }
    if (items.length === 0) {
      fail('Catalog is EMPTY — run syncCatalog');
    } else {
      pass('Catalog has products. Sample:');
      items.slice(0, 5).forEach(p => info('    ' + p.id + ' | ' + p.title));
      if (items.length === 20) info('    ... (showing first 20)');
    }
    return items.length;
  } catch (e) {
    fail('Error reading catalog: ' + e.message);
    return 0;
  }
}

async function checkModels() {
  console.log('\n[2] Recommendation Models');
  const client = new ModelServiceClient();
  try {
    const [models] = await client.listModels({ parent: PARENT });
    if (models.length === 0) {
      fail('No models found — create zing-recommendations model');
      return null;
    }
    models.forEach(m => {
      const id = m.name.split('/').pop();
      const ok = m.servingState === 'ACTIVE';
      const fn = ok ? pass : warn;
      fn(id + ' | type: ' + m.type + ' | serving: ' + m.servingState + ' | training: ' + m.trainingState);
    });
    const zingModel = models.find(m => m.name.endsWith('/zing-recommendations'));
    const activeModel = models.find(m => m.servingState === 'ACTIVE');
    if (!zingModel) {
      warn('"zing-recommendations" not yet created (events still indexing — retry in ~1-2 hrs)');
    } else if (zingModel.servingState !== 'ACTIVE') {
      warn('"zing-recommendations" exists but not ACTIVE yet (still training — takes 2-5 days)');
    } else {
      pass('"zing-recommendations" is ACTIVE and ready');
    }
    return activeModel || null;
  } catch (e) {
    fail('Error reading models: ' + e.message);
    return null;
  }
}

async function checkServingConfigs() {
  console.log('\n[3] Serving Configs');
  const client = new ServingConfigServiceClient();
  const required = ['home_recommended', 'store_also_viewed', 'cart_bought_together', 'post_order_stores'];
  try {
    const [configs] = await client.listServingConfigs({ parent: PARENT });
    const configMap = {};
    configs.forEach(c => { configMap[c.name.split('/').pop()] = c; });

    let allPresent = true;
    for (const id of required) {
      if (configMap[id]) {
        const c = configMap[id];
        const usingZing = c.modelId === 'zing-recommendations';
        const fn = usingZing ? pass : warn;
        fn(id + ' | model: ' + (c.modelId || '(none)') + (usingZing ? '' : ' <- update to zing-recommendations'));
      } else {
        fail(id + ' — MISSING');
        allPresent = false;
      }
    }
    return allPresent;
  } catch (e) {
    fail('Error reading serving configs: ' + e.message);
    return false;
  }
}

async function testPrediction(placementId) {
  const client = new PredictionServiceClient();
  const placement = PARENT + '/servingConfigs/' + placementId;
  // home-page-view doesn't require productDetails; others use detail-page-view with a dummy product
  const needsProduct = placementId !== 'home_recommended' && placementId !== 'post_order_stores';
  const userEvent = {
    eventType: needsProduct ? 'detail-page-view' : 'home-page-view',
    visitorId: 'diag_visitor_001',
    eventTime: { seconds: Math.floor(Date.now() / 1000), nanos: 0 },
  };
  if (needsProduct) {
    userEvent.productDetails = [{ product: { id: 'store_diag' } }];
  }
  try {
    const [response] = await client.predict({
      placement,
      userEvent,
      pageSize: 5,
      validateOnly: false,
    });
    const results = (response.results || []).map(r => r.id);
    if (results.length > 0) {
      pass(placementId + ' → ' + results.length + ' results: ' + results.slice(0,3).join(', ') + (results.length > 3 ? '...' : ''));
    } else {
      warn(placementId + ' → 0 results (model training or cold start — fallback active)');
    }
    return results.length;
  } catch (e) {
    if (e.message.includes('NOT_FOUND')) {
      fail(placementId + ' → serving config NOT FOUND');
    } else {
      fail(placementId + ' → ' + e.message.split('\n')[0]);
    }
    return -1;
  }
}

async function checkPredictions() {
  console.log('\n[4] Live Prediction Test (all 4 placements)');
  const placements = ['home_recommended', 'store_also_viewed', 'cart_bought_together', 'post_order_stores'];
  let anyResults = false;
  for (const p of placements) {
    const count = await testPrediction(p);
    if (count > 0) anyResults = true;
  }
  return anyResults;
}

async function checkEventData() {
  console.log('\n[5] User Event Service');
  const client = new UserEventServiceClient();
  try {
    // Write a test event to confirm the pipeline is live
    await client.writeUserEvent({
      parent: PARENT,
      userEvent: {
        eventType: 'home-page-view',
        visitorId: 'diag_visitor_001',
        eventTime: { seconds: Math.floor(Date.now() / 1000), nanos: 0 },
      },
    });
    pass('Event write OK — pipeline is live');
  } catch (e) {
    fail('Event write FAILED: ' + e.message.split('\n')[0]);
  }
}

async function main() {
  console.log('='.repeat(58));
  console.log('ZING — Vertex AI Retail Full Diagnostic');
  console.log('='.repeat(58));

  const catalogCount = await checkCatalog();
  const activeModel  = await checkModels();
  const configsOk    = await checkServingConfigs();
  const predictionsOk = await checkPredictions();
  await checkEventData();

  // Summary
  console.log('\n' + '='.repeat(58));
  console.log('SUMMARY');
  console.log('='.repeat(58));

  const items = [
    ['Catalog populated',      catalogCount > 0],
    ['Active model exists',    !!activeModel],
    ['All 4 serving configs',  configsOk],
    ['Predictions returning',  predictionsOk],
  ];
  items.forEach(([label, ok]) => {
    console.log('  ' + (ok ? 'OK  ' : 'NO  ') + label);
  });

  const allGood = items.every(([, ok]) => ok);
  console.log('\n' + (allGood
    ? 'System is FULLY OPERATIONAL.'
    : 'Action needed — see items marked FAIL/WARN above.')
  );

  if (!predictionsOk) {
    console.log('\nPredictions returning 0 results — this is normal while:');
    console.log('  - "zing-recommendations" model is still training (2-5 days)');
    console.log('  - Seeded events are still being indexed (1-2 hrs)');
    console.log('  App will show fallback (popular stores / shuffled products) until ready.');
  }

  console.log('='.repeat(58));
}

main().catch(e => {
  console.error('Fatal:', e.message);
  process.exit(1);
});
