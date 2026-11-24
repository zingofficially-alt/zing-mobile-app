require('dotenv').config({quiet: true});
const {createClient} = require('@supabase/supabase-js');
const {createApp} = require('./app');

const {SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, PORT = 3000} = process.env;

// Fail at start-up, not on the first request, so a bad deploy shows in the logs.
const missing = ['SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY'].filter((k) => !process.env[k]);
if (missing.length) {
  console.error(`zing-server: missing environment variable(s): ${missing.join(', ')}`);
  process.exit(1);
}

// Service-role client: bypasses RLS. Use only for admin work after verifying the caller.
const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {auth: {persistSession: false}});

createApp({admin}).listen(PORT, () => console.log(`zing-server listening on :${PORT}`));
