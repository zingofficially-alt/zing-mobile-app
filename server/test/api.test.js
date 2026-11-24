const test = require('node:test');
const assert = require('node:assert/strict');
const {createApp} = require('../src/app');

const U1 = '11111111-1111-4111-8111-111111111111';
const U2 = '22222222-2222-4222-8222-222222222222';
const P1 = '33333333-3333-4333-8333-333333333333';

// Tokens map to users; roles map to profiles. Calls are recorded.
function fakeAdmin({calls = []} = {}) {
  const tokens = {userToken: U1, otherToken: U2, adminToken: 'admin-id'};
  const roles = {[U1]: 'User', [U2]: 'Owner', 'admin-id': 'Admin'};
  return {
    calls,
    auth: {
      getUser: async (t) => (tokens[t]
        ? {data: {user: {id: tokens[t]}}, error: null}
        : {data: {user: null}, error: {message: 'bad jwt'}}),
      admin: {
        deleteUser: async (id) => { calls.push(['deleteUser', id]); return {error: null}; },
        createUser: async (args) => {
          calls.push(['createUser', args]);
          return args.email === 'dup@t.com'
            ? {data: null, error: {message: 'already registered'}}
            : {data: {user: {id: 'new-id'}}, error: null};
        },
      },
    },
    from: (table) => ({
      select: () => ({eq: (_c, id) => ({single: async () => ({data: {role: roles[id]}})})}),
      update: (row) => ({eq: async (_c, id) => { calls.push(['update', table, row, id]); return {error: null}; }}),
      insert: async (row) => { calls.push(['insert', table, row]); return {error: null}; },
    }),
    rpc: async (name, args) => { calls.push(['rpc', name, args]); return {data: [{id: 'p'}], error: null}; },
  };
}

async function start(opts = {}) {
  const calls = [];
  const app = createApp({admin: opts.noAdmin ? null : fakeAdmin({calls}), env: opts.env ?? {}, fetchImpl: opts.fetchImpl, now: opts.now});
  const server = await new Promise((resolve) => { const s = app.listen(0, () => resolve(s)); });
  const base = `http://127.0.0.1:${server.address().port}`;
  const call = (method, path, {token, body, raw, headers} = {}) => fetch(base + path, {
    method,
    headers: {'Content-Type': 'application/json', ...(token ? {Authorization: `Bearer ${token}`} : {}), ...headers},
    body: raw ?? (body === undefined ? undefined : JSON.stringify(body)),
  }).then(async (r) => ({status: r.status, json: await r.json().catch(() => null), headers: r.headers}));
  return {call, calls, close: () => server.close()};
}

test('health works without a login', async (t) => {
  const s = await start(); t.after(s.close);
  const r = await s.call('GET', '/health');
  assert.equal(r.status, 200);
  assert.deepEqual(r.json, {ok: true, supabase: true});
});

test('routes refuse a missing or bad token', async (t) => {
  const s = await start(); t.after(s.close);
  assert.equal((await s.call('GET', '/recommendations')).status, 401);
  assert.equal((await s.call('GET', '/recommendations', {token: 'nope'})).status, 401);
  assert.equal((await s.call('POST', '/translate', {body: {text: 'hi', target: 'ta'}})).status, 401);
});

test('without a Supabase client the routes answer 503, not a crash', async (t) => {
  const s = await start({noAdmin: true}); t.after(s.close);
  assert.equal((await s.call('GET', '/recommendations', {token: 'userToken'})).status, 503);
  assert.deepEqual((await s.call('GET', '/health')).json, {ok: true, supabase: false});
});

test('a user can delete their own account but not someone else\'s', async (t) => {
  const s = await start(); t.after(s.close);
  assert.equal((await s.call('DELETE', `/users/${U2}`, {token: 'userToken'})).status, 403);
  assert.equal((await s.call('DELETE', `/users/${U1}`, {token: 'userToken'})).status, 200);
  assert.equal((await s.call('DELETE', '/users/not-a-uuid', {token: 'userToken'})).status, 400);
  assert.deepEqual(s.calls, [['deleteUser', U1]]);
});

test('an admin can delete another account', async (t) => {
  const s = await start(); t.after(s.close);
  assert.equal((await s.call('DELETE', `/users/${U1}`, {token: 'adminToken'})).status, 200);
});

test('only an admin can create users, with validated input', async (t) => {
  const s = await start(); t.after(s.close);
  const body = {email: 'a@t.com', password: 'secret1', name: 'A', role: 'Owner'};
  assert.equal((await s.call('POST', '/admin/users', {token: 'userToken', body})).status, 403);
  assert.equal((await s.call('POST', '/admin/users', {token: 'otherToken', body})).status, 403);
  const ok = await s.call('POST', '/admin/users', {token: 'adminToken', body});
  assert.equal(ok.status, 201);
  assert.deepEqual(ok.json, {id: 'new-id'});
  assert.equal((await s.call('POST', '/admin/users', {token: 'adminToken', body: {...body, role: 'Root'}})).status, 400);
  assert.equal((await s.call('POST', '/admin/users', {token: 'adminToken', body: {...body, password: '123'}})).status, 400);
  assert.equal((await s.call('POST', '/admin/users', {token: 'adminToken', body: {...body, email: 'nope'}})).status, 400);
  const dup = await s.call('POST', '/admin/users', {token: 'adminToken', body: {...body, email: 'dup@t.com'}});
  assert.equal(dup.status, 400);
  assert.equal(dup.json.error, 'already registered');
});

test('events are validated and recorded for the caller only', async (t) => {
  const s = await start(); t.after(s.close);
  assert.equal((await s.call('POST', '/events', {token: 'userToken', body: {}})).status, 400);
  assert.equal((await s.call('POST', '/events', {token: 'userToken', body: {event_type: 'view', product_id: 'x'}})).status, 400);
  const ok = await s.call('POST', '/events', {token: 'userToken', body: {event_type: 'view', product_id: P1, user_id: U2}});
  assert.equal(ok.status, 201);
  assert.deepEqual(s.calls.at(-1), ['insert', 'user_events', {user_id: U1, event_type: 'view', product_id: P1, store_id: null}]);
});

test('recommendations clamp the limit', async (t) => {
  const s = await start(); t.after(s.close);
  await s.call('GET', '/recommendations?limit=9999', {token: 'userToken'});
  await s.call('GET', '/recommendations?limit=-3', {token: 'userToken'});
  assert.deepEqual(s.calls.map((c) => c[2].lim), [50, 1]);
  assert.ok(s.calls.every((c) => c[2].uid === U1));
});

test('bad or huge JSON gets a clean error', async (t) => {
  const s = await start(); t.after(s.close);
  assert.equal((await s.call('POST', '/events', {token: 'userToken', raw: '{oops'})).status, 400);
  assert.equal((await s.call('POST', '/events', {token: 'userToken', raw: JSON.stringify({event_type: 'x'.repeat(40000)})})).status, 413);
});

test('translate: validation, missing key, success and upstream failure', async (t) => {
  const seen = [];
  const fetchImpl = async (url, init) => {
    seen.push({url, init});
    return JSON.parse(init.body).q === 'boom'
      ? {ok: false, json: async () => ({})}
      : {ok: true, json: async () => ({data: {translations: [{translatedText: 'வணக்கம்'}]}})};
  };
  const noKey = await start({fetchImpl}); t.after(noKey.close);
  assert.equal((await noKey.call('POST', '/translate', {token: 'userToken', body: {text: 'hi', target: 'ta'}})).status, 503);

  const s = await start({fetchImpl, env: {GOOGLE_TRANSLATE_API_KEY: 'secret-key'}}); t.after(s.close);
  assert.equal((await s.call('POST', '/translate', {token: 'userToken', body: {text: '', target: 'ta'}})).status, 400);
  assert.equal((await s.call('POST', '/translate', {token: 'userToken', body: {text: 'hi', target: 'fr'}})).status, 400);
  assert.equal((await s.call('POST', '/translate', {token: 'userToken', body: {text: 'x'.repeat(2001), target: 'ta'}})).status, 400);
  assert.equal(seen.length, 0, 'invalid requests never reach the translation API');

  const ok = await s.call('POST', '/translate', {token: 'userToken', body: {text: 'hello', target: 'ta'}});
  assert.equal(ok.status, 200);
  assert.deepEqual(ok.json, {text: 'வணக்கம்'});
  assert.equal(seen[0].init.headers['X-goog-api-key'], 'secret-key');
  assert.ok(!seen[0].url.includes('secret-key'), 'the key is sent in a header, not the URL');

  assert.equal((await s.call('POST', '/translate', {token: 'userToken', body: {text: 'boom', target: 'ta'}})).status, 502);
});

test('translate is rate limited per user', async (t) => {
  let clock = 1_000_000;
  const s = await start({
    now: () => clock,
    env: {GOOGLE_TRANSLATE_API_KEY: 'k'},
    fetchImpl: async () => ({ok: true, json: async () => ({data: {translations: [{translatedText: 'x'}]}})}),
  });
  t.after(s.close);
  const go = (token) => s.call('POST', '/translate', {token, body: {text: 'hi', target: 'en'}});
  for (let i = 0; i < 60; i++) assert.equal((await go('userToken')).status, 200);
  const blocked = await go('userToken');
  assert.equal(blocked.status, 429);
  assert.ok(blocked.headers.get('retry-after'));
  assert.equal((await go('otherToken')).status, 200, 'another user is not affected');
  clock += 61_000;
  assert.equal((await go('userToken')).status, 200, 'the window resets');
});

test('browsers are blocked by default and allowed only for listed origins', async (t) => {
  const closed = await start(); t.after(closed.close);
  const open = await start({env: {CORS_ORIGINS: 'https://zing.example, https://admin.zing.example'}}); t.after(open.close);
  const allowOrigin = async (s, origin) =>
    (await s.call('GET', '/health', {headers: {Origin: origin}})).headers.get('access-control-allow-origin');

  assert.equal(await allowOrigin(closed, 'https://zing.example'), null);
  assert.equal(await allowOrigin(open, 'https://zing.example'), 'https://zing.example');
  assert.equal(await allowOrigin(open, 'https://admin.zing.example'), 'https://admin.zing.example');
  assert.equal(await allowOrigin(open, 'https://evil.example'), null);
});
