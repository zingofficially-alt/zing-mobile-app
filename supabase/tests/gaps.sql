\pset format unaligned
\pset tuples_only on
grant usage on schema storage to authenticated;
create or replace function public.t_assert(label text, cond boolean) returns text language sql as $$
  select case when cond then 'ok   ' else 'FAIL ' end || label $$;
create or replace function public.t_expect(q text, pat text) returns text language plpgsql as $$
begin execute q; return 'FAIL (no error): ' || q;
exception when others then
  if sqlerrm ilike '%' || pat || '%' then return 'ok  (' || sqlerrm || ')'; end if;
  return 'FAIL (wrong error "' || sqlerrm || '"): ' || q; end $$;

-- U plain user, N owner without access, B owner with access, D admin, C customer
insert into auth.users(id,email) values
 ('11111111-0000-0000-0000-00000000000a','u@t'),('22222222-0000-0000-0000-00000000000b','n@t'),
 ('33333333-0000-0000-0000-00000000000c','b@t'),('44444444-0000-0000-0000-00000000000d','d@t'),
 ('55555555-0000-0000-0000-00000000000e','c@t');
update public.profiles set role='Admin' where email='d@t';
update public.profiles set role='Owner', store_access=false where email='n@t';
update public.profiles set role='Owner', store_access=true where email='b@t';

-- 1. who may create a store
select set_config('request.jwt.claim.sub','11111111-0000-0000-0000-00000000000a',false); set role authenticated;
select t_expect($$insert into public.stores(owner_id,name) values ('11111111-0000-0000-0000-00000000000a','Sneaky')$$, 'row-level security');
reset role;
select set_config('request.jwt.claim.sub','22222222-0000-0000-0000-00000000000b',false); set role authenticated;
select t_expect($$insert into public.stores(owner_id,name) values ('22222222-0000-0000-0000-00000000000b','No access')$$, 'row-level security');
reset role;
select set_config('request.jwt.claim.sub','33333333-0000-0000-0000-00000000000c',false); set role authenticated;
insert into public.stores(id,owner_id,name,is_active) values ('b1000000-0000-0000-0000-000000000001','33333333-0000-0000-0000-00000000000c','Mine',false);
select t_assert('owner with store access can create a store (and it starts active even if they sent false)',
  (select is_active from public.stores where id='b1000000-0000-0000-0000-000000000001'));
select t_expect($$insert into public.stores(owner_id,name) values ('55555555-0000-0000-0000-00000000000e','For someone else')$$, 'row-level security');
reset role;
select set_config('request.jwt.claim.sub','44444444-0000-0000-0000-00000000000d',false); set role authenticated;
insert into public.stores(id,owner_id,name) values ('b2000000-0000-0000-0000-000000000002','22222222-0000-0000-0000-00000000000b','Admin made');
select t_assert('admin can create a store for an owner', (select count(*) from public.stores)=2);
reset role;

-- 2. is_active
update public.stores set is_active=false where id='b1000000-0000-0000-0000-000000000001';   -- expiry (no signed-in user)
select set_config('request.jwt.claim.sub','33333333-0000-0000-0000-00000000000c',false); set role authenticated;
update public.stores set is_active=true, name='Renamed', temporarily_closed=true where id='b1000000-0000-0000-0000-000000000001';
select t_assert('owner cannot switch the store back on, but can still edit it',
  (select not is_active and name='Renamed' and temporarily_closed from public.stores where id='b1000000-0000-0000-0000-000000000001'));
reset role;
select set_config('request.jwt.claim.sub','44444444-0000-0000-0000-00000000000d',false); set role authenticated;
update public.stores set is_active=true where id='b1000000-0000-0000-0000-000000000001';
select t_assert('admin can switch it back on', (select is_active from public.stores where id='b1000000-0000-0000-0000-000000000001'));
reset role;
-- the daily job and a completed payment still flip it
update public.profiles set store_access=true, has_paid=true where email='b@t';
select public.expire_store_access() as n \gset exp_
select t_assert('expire_store_access still hides a lapsed owner (job has no signed-in user)',
  :exp_n >= 1 and not (select is_active from public.stores where id='b1000000-0000-0000-0000-000000000001'));
select set_config('request.jwt.claim.sub','44444444-0000-0000-0000-00000000000d',false); set role authenticated;
insert into public.payments(user_id,amount,payment_status) values ('33333333-0000-0000-0000-00000000000c',5,'Completed');
reset role;
select t_assert('a completed payment (written by an admin) switches it back on',
  (select is_active from public.stores where id='b1000000-0000-0000-0000-000000000001'));

-- 3. order deletion
insert into public.products(id,store_id,name,price,quantity) values ('c1000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','Item',10,5);
select set_config('request.jwt.claim.sub','55555555-0000-0000-0000-00000000000e',false); set role authenticated;
select public.place_order('b1000000-0000-0000-0000-000000000001','[{"product_id":"c1000000-0000-0000-0000-000000000001","quantity":2}]'::jsonb,'Pickup',null) as id \gset o_
delete from public.orders where id=:'o_id';
select t_assert('customer delete is ignored; order still there', (select count(*) from public.orders where id=:'o_id')=1);
reset role;
select set_config('request.jwt.claim.sub','33333333-0000-0000-0000-00000000000c',false); set role authenticated;
delete from public.orders where id=:'o_id';
select t_assert('store owner delete is ignored too', (select count(*) from public.orders where id=:'o_id')=1);
reset role;
select set_config('request.jwt.claim.sub','44444444-0000-0000-0000-00000000000d',false); set role authenticated;
delete from public.orders where id=:'o_id';
reset role;
select t_assert('admin can delete, and the reserved stock goes back (3 -> 5)',
  (select count(*) from public.orders where id=:'o_id')=0 and (select quantity from public.products where id='c1000000-0000-0000-0000-000000000001')=5);

-- 4. notifications
insert into public.notifications(id,user_id,title,body) values
 ('d1000000-0000-0000-0000-000000000001','55555555-0000-0000-0000-00000000000e','Order update','Your order is Shipped'),
 ('d2000000-0000-0000-0000-000000000002','33333333-0000-0000-0000-00000000000c','Mine','x');
select set_config('request.jwt.claim.sub','55555555-0000-0000-0000-00000000000e',false); set role authenticated;
update public.notifications set title='You won!', body='send money', type='promo', is_read=true where id='d1000000-0000-0000-0000-000000000001';
select t_assert('user can mark read but cannot rewrite the text',
  (select is_read and title='Order update' and body='Your order is Shipped' and type='system' from public.notifications where id='d1000000-0000-0000-0000-000000000001'));
update public.notifications set is_read=true where id='d2000000-0000-0000-0000-000000000002';
select t_assert('and cannot touch someone else''s notification', (select count(*) from public.notifications)=1);
reset role;
select t_assert('the other user''s notification is still unread', not (select is_read from public.notifications where id='d2000000-0000-0000-0000-000000000002'));
