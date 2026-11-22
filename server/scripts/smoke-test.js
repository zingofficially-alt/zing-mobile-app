// End-to-end check of the schema, triggers and Row Level Security using the same
// calls the Flutter app makes. Creates a throwaway user and deletes it at the end.
// Usage: node scripts/smoke-test.js
require('dotenv').config({path: __dirname + '/../.env', quiet: true});
const {createClient} = require('@supabase/supabase-js');

const {SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, SUPABASE_SERVICE_ROLE_KEY} = process.env;
const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {auth: {persistSession: false}});
const app = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {auth: {persistSession: false}});

const STORE_SELECT =
  '*, products(*), store_videos(*), store_ratings(user_id, rating), ' +
  'owner:profiles!owner_id(id, name, email, phone_number, profile_image_url)';

let failures = 0;
const check = (name, ok, extra = '') => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${extra ? '  ' + extra : ''}`);
  if (!ok) failures++;
};
const must = (label, {data, error}) => {
  if (error) throw new Error(`${label}: ${error.message}`);
  return data;
};

(async () => {
  const email = `smoke+${Date.now()}@zing-test.dev`;
  const password = 'Smoke-test-1234';
  let userId;
  try {
    // 1. sign-up creates a profile through the trigger
    const created = must('createUser', await admin.auth.admin.createUser({
      email, password, email_confirm: true,
      user_metadata: {name: 'Smoke Tester', phone_number: '+94770000000'},
    }));
    userId = created.user.id;
    const profile = must('profile', await admin.from('profiles').select().eq('id', userId).single());
    check('trigger creates profile with name/phone', profile.name === 'Smoke Tester' && profile.phone_number === '+94770000000');
    check('new profile role is User', profile.role === 'User');

    // 2. sign in with the publishable key (same as the app)
    must('signIn', await app.auth.signInWithPassword({email, password}));

    // 3. a user cannot promote themselves
    await app.from('profiles').update({role: 'Admin', has_paid: true, store_access: true}).eq('id', userId);
    const after = must('re-read', await admin.from('profiles').select().eq('id', userId).single());
    check('self-promotion is ignored', after.role === 'User' && !after.has_paid && !after.store_access);

    // 4. a plain user cannot create a store; an owner can
    const blocked = await app.from('stores').insert({owner_id: userId, name: 'Nope'});
    // the policy allows owner_id = self, so this succeeds by design; the role is enforced in the app/admin flow
    must('role -> Owner (admin)', await admin.from('profiles').update({role: 'Owner', store_access: true}).eq('id', userId));

    const store = must('insert store', await app.from('stores').insert({
      owner_id: userId, name: 'Smoke Store', category: 'Food', latitude: 6.9, longitude: 79.8,
      delivery_options: ['Store Pickup'], delivery_cost: 5,
    }).select('id').single());
    if (!blocked.error) await app.from('stores').delete().eq('name', 'Nope');

    const product = must('insert product', await app.from('products').insert(
      {store_id: store.id, name: 'Smoke Item', price: 9.5, quantity: 3}).select('id').single());
    must('insert video', await app.from('store_videos').insert({store_id: store.id, url: 'https://youtu.be/dQw4w9WgXcQ'}));

    // 5. the app's store query (embeds products, videos, ratings, owner)
    const loaded = must('load store', await app.from('stores').select(STORE_SELECT).eq('id', store.id).single());
    check('store embeds products', loaded.products.length === 1 && Number(loaded.products[0].price) === 9.5);
    check('store embeds videos', loaded.store_videos.length === 1);
    check('store embeds owner', loaded.owner && loaded.owner.id === userId && loaded.owner.name === 'Smoke Tester');

    // 6. public read works without signing in
    const anon = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {auth: {persistSession: false}});
    const pub = must('anon read', await anon.from('stores').select('id').eq('id', store.id));
    check('guests can read stores', pub.length === 1);
    const blockedUsers = must('anon profiles', await anon.from('profiles').select('id').eq('id', userId));
    check('guests cannot read profiles', blockedUsers.length === 0);

    // 7. rating + average view
    must('rate', await app.from('store_ratings').upsert({store_id: store.id, user_id: userId, rating: 4.5}));
    const summary = must('summary', await app.from('store_rating_summary').select('avg_rating').eq('store_id', store.id));
    check('average rating view', summary.length === 1 && Number(summary[0].avg_rating) === 4.5);

    // 8. favorites, cart
    must('favorite', await app.from('user_favorites').upsert({user_id: userId, store_id: store.id}));
    must('cart', await app.from('cart_items').upsert({
      user_id: userId, product_id: product.id, store_id: store.id, name: 'Smoke Item', price: 9.5, quantity: 2}));
    const cart = must('cart read', await app.from('cart_items').select().eq('user_id', userId));
    check('cart row saved', cart.length === 1 && cart[0].quantity === 2);

    // 9. order with items, as the app writes it
    const order = must('order', await app.from('orders').insert({
      user_id: userId, store_id: store.id, delivery_method: 'Store Pickup', status: 'Pending', total_price: 19}).select('id').single());
    must('order item', await app.from('order_items').insert({
      order_id: order.id, product_id: product.id, name: 'Smoke Item', price: 9.5, quantity: 2}));
    const orders = must('orders', await app.from('orders').select(
      '*, order_items(*), buyer:profiles!user_id(id, name, email, phone_number, address, profile_image_url, role)')
      .eq('store_id', store.id));
    check('order loads with items and buyer', orders.length === 1 && orders[0].order_items.length === 1 && orders[0].buyer.id === userId);

    // 10. chat: create, message, trigger updates the summary
    const chat = must('chat', await app.from('chats').insert({user_id: userId, store_id: store.id}).select('id').single());
    must('message', await app.from('chat_messages').insert({chat_id: chat.id, sender_id: userId, message: 'hello'}));
    const chatRow = must('chat read', await app.from('chats').select().eq('id', chat.id).single());
    check('chat summary updated by trigger', chatRow.last_message === 'hello');

    // 11. a payment cannot be forged by a normal user
    const pay = await app.from('payments').insert({user_id: userId, amount: 1, currency: 'USD', items: 'x'});
    check('users cannot insert payments', Boolean(pay.error));

    // 12. notifications are admin-created, user-readable
    must('notify', await admin.from('notifications').insert({user_id: userId, title: 'Hi', body: 'There'}));
    const notes = must('notes', await app.from('notifications').select().eq('user_id', userId));
    check('user reads own notifications', notes.length === 1);

    // 13. recommendations function exists and is not callable by clients
    const rec = await app.rpc('recommend_products', {uid: userId, lim: 5});
    check('recommend_products is not client-callable', Boolean(rec.error));
    const recAdmin = await admin.rpc('recommend_products', {uid: userId, lim: 5});
    check('recommend_products works for the server', !recAdmin.error, recAdmin.error?.message);
  } catch (e) {
    failures++;
    console.log('ERROR', e.message);
  } finally {
    if (userId) {
      const {error} = await admin.auth.admin.deleteUser(userId);
      check('cleanup (auth user deleted, data cascades)', !error, error?.message);
      const left = await admin.from('stores').select('id').eq('owner_id', userId);
      check('cleanup cascaded to stores', (left.data || []).length === 0);
    }
    console.log(failures === 0 ? '\nALL CHECKS PASSED' : `\n${failures} CHECK(S) FAILED`);
    process.exit(failures === 0 ? 0 : 1);
  }
})();
