require('dotenv').config({path: __dirname + '/../.env', quiet: true});
const {Client} = require('pg'); const e = process.env;
(async () => {
  const c = new Client({host: e.SUPABASE_DB_HOST, port: 5432, user: e.SUPABASE_DB_USER, password: e.SUPABASE_DB_PASSWORD, database: e.SUPABASE_DB_NAME, ssl: {rejectUnauthorized: false}, connectionTimeoutMillis: 15000});
  await c.connect();
  const r = await c.query("select table_name from information_schema.tables where table_schema='public'");
  console.log('public tables:', r.rows.map(x => x.table_name));
  await c.end();
})().catch(err => { console.log(err.code, err.message); process.exit(1); });
