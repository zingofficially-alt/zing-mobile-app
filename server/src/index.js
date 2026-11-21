require('dotenv').config({quiet: true});
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const {createClient} = require('@supabase/supabase-js');

const {SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, PORT = 3000} = process.env;

// Service-role client: bypasses RLS. Use only for admin work after verifying the caller.
const admin = SUPABASE_SERVICE_ROLE_KEY
  ? createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {auth: {persistSession: false}})
  : null;

const app = express();
app.use(helmet());
app.use(cors());
app.use(express.json({limit: '1mb'}));

// Railway health check
app.get('/health', (_req, res) => res.json({ok: true, supabase: Boolean(admin)}));

// Verifies the Supabase access token sent by the Flutter app (Authorization: Bearer <jwt>)
async function requireUser(req, res, next) {
  const token = (req.headers.authorization || '').replace(/^Bearer /, '');
  if (!token || !admin) return res.status(401).json({error: 'unauthorized'});
  const {data, error} = await admin.auth.getUser(token);
  if (error || !data.user) return res.status(401).json({error: 'unauthorized'});
  const {data: profile} = await admin.from('profiles').select('role').eq('id', data.user.id).single();
  req.user = {id: data.user.id, role: profile?.role ?? 'User'};
  next();
}

const requireAdmin = (req, res, next) =>
  req.user.role === 'Admin' ? next() : res.status(403).json({error: 'forbidden'});

// Replaces the deleteUser Cloud Function.
app.delete('/admin/users/:id', requireUser, requireAdmin, async (req, res) => {
  const {error} = await admin.auth.admin.deleteUser(req.params.id); // cascades to profiles
  if (error) return res.status(400).json({error: error.message});
  res.json({ok: true});
});

// Replaces logUserEvent.
app.post('/events', requireUser, async (req, res) => {
  const {event_type, product_id, store_id} = req.body || {};
  if (!event_type) return res.status(400).json({error: 'event_type required'});
  const {error} = await admin.from('user_events').insert({user_id: req.user.id, event_type, product_id, store_id});
  if (error) return res.status(400).json({error: error.message});
  res.status(201).json({ok: true});
});

// Replaces getRecommendations: simple popularity + recent-interest query.
app.get('/recommendations', requireUser, async (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 10, 50);
  const {data, error} = await admin.rpc('recommend_products', {uid: req.user.id, lim: limit});
  if (error) return res.status(400).json({error: error.message});
  res.json({items: data});
});

app.listen(PORT, () => console.log(`zing-server listening on :${PORT}`));
