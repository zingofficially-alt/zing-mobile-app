/**
 * ZING — Create Serving Configs + Model
 * Run: GOOGLE_APPLICATION_CREDENTIALS=/tmp/zing-appengine-key.json node zing_setup.js
 */
const { ModelServiceClient, ServingConfigServiceClient } = require('@google-cloud/retail').v2;

const PARENT = 'projects/zing-262ad/locations/global/catalogs/default_catalog';

async function run() {
  const mc = new ModelServiceClient();
  const sc = new ServingConfigServiceClient();

  console.log('='.repeat(55));
  console.log('ZING — Vertex AI Retail Setup');
  console.log('='.repeat(55));

  // List existing models
  const [models] = await mc.listModels({ parent: PARENT });
  console.log('\nAvailable models:');
  models.forEach(m => {
    const id = m.name.split('/').pop();
    console.log('  ' + id + ' | type: ' + m.type + ' | serving: ' + m.servingState);
  });

  // Pick first active model as placeholder
  const activeModel = models.find(m => m.servingState === 'ACTIVE');
  if (!activeModel) {
    console.error('\nNo active model found. Cannot create serving configs yet.');
    process.exit(1);
  }
  const modelId = activeModel.name.split('/').pop();
  console.log('\nUsing model "' + modelId + '" as placeholder for serving configs.');
  console.log('(Update to "zing-recommendations" after it finishes training.)\n');

  // Create 4 serving configs
  const configs = [
    { id: 'home_recommended',     displayName: 'Home Recommended'     },
    { id: 'store_also_viewed',    displayName: 'Store Also Viewed'    },
    { id: 'cart_bought_together', displayName: 'Cart Bought Together' },
    { id: 'post_order_stores',    displayName: 'Post Order Stores'    },
  ];

  console.log('Creating serving configs:');
  for (const cfg of configs) {
    try {
      await sc.createServingConfig({
        parent: PARENT,
        servingConfigId: cfg.id,
        servingConfig: {
          displayName: cfg.displayName,
          solutionTypes: ['SOLUTION_TYPE_RECOMMENDATION'],
          modelId: modelId,
          diversityLevel: 'medium-diversity',
        },
      });
      console.log('  CREATED  ' + cfg.id);
    } catch (e) {
      if (e.message.includes('ALREADY_EXISTS') || e.message.includes('already exists')) {
        console.log('  EXISTS   ' + cfg.id + '  (skipped)');
      } else {
        console.error('  FAILED   ' + cfg.id + '  - ' + e.message);
      }
    }
  }

  // Try creating zing-recommendations model
  console.log('\nAttempting to create "zing-recommendations" model...');
  try {
    const [op] = await mc.createModel({
      parent: PARENT,
      model: {
        name: PARENT + '/models/zing-recommendations',
        displayName: 'zing-recommendations',
        type: 'others-you-may-like',
        optimizationObjective: 'ctr',
      },
    });
    console.log('  Model creation queued. Operation: ' + (op.name || '(submitted)'));
    console.log('  Will train once event data is fully processed (1-2 hrs).');
  } catch (e) {
    if (e.message.includes('ALREADY_EXISTS') || e.message.includes('already exists')) {
      console.log('  "zing-recommendations" already exists.');
    } else if (e.code === 9) {
      console.log('  Events still being indexed — not enough data yet.');
      console.log('  Re-run this script in 1-2 hours to create the model.');
    } else {
      console.error('  ERROR: ' + e.message);
    }
  }

  // Print summary
  console.log('\n' + '='.repeat(55));
  console.log('Current Serving Configs:');
  const [all] = await sc.listServingConfigs({ parent: PARENT });
  const zingIds = ['home_recommended','store_also_viewed','cart_bought_together','post_order_stores'];
  all.forEach(c => {
    const id = c.name.split('/').pop();
    const mark = zingIds.includes(id) ? 'ZING' : '    ';
    console.log('  [' + mark + '] ' + id.padEnd(28) + ' model: ' + (c.modelId || '(none)'));
  });

  console.log('\n' + '='.repeat(55));
  console.log('NEXT STEPS:');
  console.log('  1. Wait 1-2 hrs, then re-run to create zing-recommendations model');
  console.log('  2. Monitor: https://console.cloud.google.com/ai/retail/models?project=zing-262ad');
  console.log('  3. After training, update serving configs to use zing-recommendations:');
  console.log('     https://console.cloud.google.com/ai/retail/serving-configs?project=zing-262ad');
  console.log('='.repeat(55));
}

run().catch(e => {
  console.error('Fatal error:', e.message);
  process.exit(1);
});
