const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const {z} = require('zod');

const LANGUAGES = ['en', 'ta', 'si'];

const schemas = {
  id: z.uuid(),
  createUser: z.object({
    email: z.email(),
    password: z.string().min(6).max(72),
    name: z.string().max(100).default(''),
    phone_number: z.string().max(20).default(''),
    role: z.enum(['User', 'Owner', 'Admin']).default('User'),
  }),
  event: z.object({
    event_type: z.string().min(1).max(50),
    product_id: z.uuid().nullish(),
    store_id: z.uuid().nullish(),
  }),
  translate: z.object({
    text: z.string().min(1).max(2000),
    target: z.enum(LANGUAGES),
  }),
};

const firstIssue = (error) => {
  const issue = error.issues[0];
  const field = issue.path.length ? `${issue.path.join('.')}: ` : '';
  return `${field}${issue.message}`;
};

/**
 * Builds the API. `admin` is a Supabase client that uses the service-role key
 * (it bypasses Row Level Security, so every route verifies the caller first).
 * `fetchImpl` and `env` are injectable so the routes can be tested.
 */
function createApp({admin, env = process.env, fetchImpl = globalThis.fetch, now = Date.now}) {
  const app = express();
  app.use(helmet());

  // The phone app does not need CORS. Allow browsers only for listed origins.
  const origins = (env.CORS_ORIGINS || '').split(',').map((s) => s.trim()).filter(Boolean);
  app.use(cors({origin: origins.length ? origins : false}));
  app.use(express.json({limit: '32kb'}));

  // Railway health check
  app.get('/health', (_req, res) => res.json({ok: true, supabase: Boolean(admin)}));

  // Verifies the Supabase access token sent by the Flutter app (Authorization: Bearer <jwt>)
  async function requireUser(req, res, next) {
    if (!admin) return res.status(503).json({error: 'Server is not configured.'});
    const token = (req.headers.authorization || '').replace(/^Bearer /, '');
    if (!token) return res.status(401).json({error: 'unauthorized'});
    const {data, error} = await admin.auth.getUser(token);
    if (error || !data?.user) return res.status(401).json({error: 'unauthorized'});
    const {data: profile} = await admin
        .from('profiles').select('role').eq('id', data.user.id).single();
    req.user = {id: data.user.id, role: profile?.role ?? 'User'};
    next();
  }

  const requireAdmin = (req, res, next) =>
    req.user.role === 'Admin' ? next() : res.status(403).json({error: 'forbidden'});

  // Small per-user limiter (in memory, fine for a single instance).
  const hits = new Map();
  const limit = (name, max, windowMs) => (req, res, next) => {
    const key = `${name}:${req.user.id}`;
    const t = now();
    const recent = (hits.get(key) || []).filter((at) => t - at < windowMs);
    if (recent.length >= max) {
      res.set('Retry-After', String(Math.ceil(windowMs / 1000)));
      return res.status(429).json({error: 'Too many requests. Try again shortly.'});
    }
    recent.push(t);
    hits.set(key, recent);
    next();
  };

  // A user may delete their own account; anyone else's needs an Admin.
  // Deleting the auth user cascades to profile, store, orders, chats, etc.
  app.delete('/users/:id', requireUser, async (req, res) => {
    const id = schemas.id.safeParse(req.params.id);
    if (!id.success) return res.status(400).json({error: 'invalid user id'});
    if (id.data !== req.user.id && req.user.role !== 'Admin') {
      return res.status(403).json({error: 'Only an admin can delete other accounts.'});
    }
    const {error} = await admin.auth.admin.deleteUser(id.data);
    if (error) return res.status(400).json({error: error.message});
    res.json({ok: true});
  });

  // Admin creates a user (Auth + role) without signing the admin out.
  app.post('/admin/users', requireUser, requireAdmin, async (req, res) => {
    const body = schemas.createUser.safeParse(req.body ?? {});
    if (!body.success) return res.status(400).json({error: firstIssue(body.error)});
    const {email, password, name, phone_number, role} = body.data;
    const {data, error} = await admin.auth.admin.createUser({
      email, password, email_confirm: true, user_metadata: {name},
    });
    if (error) return res.status(400).json({error: error.message});
    const {error: pErr} = await admin.from('profiles')
        .update({name, phone_number, role, email}).eq('id', data.user.id);
    if (pErr) return res.status(400).json({error: pErr.message});
    res.status(201).json({id: data.user.id});
  });

  // Recommendation input.
  app.post('/events', requireUser, limit('events', 120, 60_000), async (req, res) => {
    const body = schemas.event.safeParse(req.body ?? {});
    if (!body.success) return res.status(400).json({error: firstIssue(body.error)});
    const {event_type, product_id = null, store_id = null} = body.data;
    const {error} = await admin.from('user_events')
        .insert({user_id: req.user.id, event_type, product_id, store_id});
    if (error) return res.status(400).json({error: error.message});
    res.status(201).json({ok: true});
  });

  // Popularity + recent-interest products (SQL function recommend_products).
  app.get('/recommendations', requireUser, async (req, res) => {
    const limitParam = Math.min(Math.max(Number(req.query.limit) || 10, 1), 50);
    const {data, error} = await admin.rpc('recommend_products', {uid: req.user.id, lim: limitParam});
    if (error) return res.status(400).json({error: error.message});
    res.json({items: data});
  });

  // Chat translation through the Cloud Translation API. The key lives only on
  // this server, so it never ships inside the app.
  app.post('/translate', requireUser, limit('translate', 60, 60_000), async (req, res) => {
    const body = schemas.translate.safeParse(req.body ?? {});
    if (!body.success) return res.status(400).json({error: firstIssue(body.error)});
    const key = env.GOOGLE_TRANSLATE_API_KEY;
    if (!key) return res.status(503).json({error: 'Translation is not configured.'});
    try {
      const r = await fetchImpl('https://translation.googleapis.com/language/translate/v2', {
        method: 'POST',
        headers: {'Content-Type': 'application/json', 'X-goog-api-key': key},
        body: JSON.stringify({q: body.data.text, target: body.data.target, format: 'text'}),
      });
      if (!r.ok) return res.status(502).json({error: 'Translation failed.'});
      const json = await r.json();
      const text = json?.data?.translations?.[0]?.translatedText;
      if (typeof text !== 'string') return res.status(502).json({error: 'Translation failed.'});
      res.json({text});
    } catch (_) {
      res.status(502).json({error: 'Translation failed.'});
    }
  });

  // Malformed JSON and anything unexpected; never leak internals.
  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    if (err.type === 'entity.parse.failed') return res.status(400).json({error: 'invalid JSON'});
    if (err.type === 'entity.too.large') return res.status(413).json({error: 'request too large'});
    console.error(err);
    res.status(500).json({error: 'internal error'});
  });

  return app;
}

module.exports = {createApp, LANGUAGES};
