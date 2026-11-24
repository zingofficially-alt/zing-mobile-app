\set ON_ERROR_STOP 1
\pset format unaligned
\pset tuples_only on
create or replace function public.t_expect(q text, pat text) returns text language plpgsql as $$
begin
  execute q;
  return 'FAIL (no error): ' || q;
exception when others then
  if sqlerrm ilike '%' || pat || '%' then return 'ok  (' || sqlerrm || ')'; end if;
  return 'FAIL (wrong error "' || sqlerrm || '"): ' || q;
end $$;
create or replace function public.t_assert(label text, cond boolean) returns text language sql as $$
  select case when cond then 'ok   ' else 'FAIL ' end || label $$;

-- users: A customer, B owner, C other customer, D admin, E second owner
insert into auth.users(id,email) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@t'),('bbbbbbbb-0000-0000-0000-000000000002','b@t'),
 ('cccccccc-0000-0000-0000-000000000003','c@t'),('dddddddd-0000-0000-0000-000000000004','d@t'),
 ('eeeeeeee-0000-0000-0000-000000000005','e@t');
update public.profiles set role='Admin' where email='d@t';
update public.profiles set role='Owner', store_access=true where email in ('b@t','e@t');

-- B creates a store and products
select set_config('request.jwt.claim.sub','bbbbbbbb-0000-0000-0000-000000000002',false);
set role authenticated;
insert into public.stores(id,owner_id,name,delivery_options,delivery_cost) values
 ('51000000-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000002','Shop B','{"Store Pickup","Home Delivery"}',80);
insert into public.stores(id,owner_id,name,delivery_options) values
 ('52000000-0000-0000-0000-000000000002','bbbbbbbb-0000-0000-0000-000000000002','Pickup only','{"Store Pickup"}');
insert into public.products(id,store_id,name,price,quantity,discount) values
 ('90000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001','Widget',100,5,10),
 ('90000000-0000-0000-0000-000000000002','51000000-0000-0000-0000-000000000001','Gadget',40,2,null),
 ('90000000-0000-0000-0000-000000000003','52000000-0000-0000-0000-000000000002','Thing',10,9,null);
reset role;

-- ===== customer A places orders
select set_config('request.jwt.claim.sub','aaaaaaaa-0000-0000-0000-000000000001',false);
set role authenticated;
select public.place_order('51000000-0000-0000-0000-000000000001',
  '[{"product_id":"90000000-0000-0000-0000-000000000001","quantity":2},{"product_id":"90000000-0000-0000-0000-000000000002","quantity":1}]'::jsonb,
  'Pickup', null) as id \gset o1_
select t_assert('total = 2*90 + 40 = 220 (discount applied server side, pickup has no fee)',
  (select total_price from public.orders where id=:'o1_id')=220);
select t_assert('stock reserved: Widget 5->3, Gadget 2->1',
  (select quantity from public.products where id='90000000-0000-0000-0000-000000000001')=3
  and (select quantity from public.products where id='90000000-0000-0000-0000-000000000002')=1);
select t_assert('status history has Pending', (select count(*) from public.order_status_history where order_id=:'o1_id' and status='Pending')=1);

select t_expect($$select public.place_order('51000000-0000-0000-0000-000000000001','[{"product_id":"90000000-0000-0000-0000-000000000002","quantity":2}]','Pickup',null)$$, 'Only 1 of Gadget');
select t_assert('failed order left stock untouched and created no order',
  (select quantity from public.products where id='90000000-0000-0000-0000-000000000002')=1
  and (select count(*) from public.orders)=1);
select t_expect($$select public.place_order('51000000-0000-0000-0000-000000000001','[{"product_id":"90000000-0000-0000-0000-000000000001","quantity":1}]','Home Delivery','')$$, 'delivery address');
select t_expect($$select public.place_order('52000000-0000-0000-0000-000000000002','[{"product_id":"90000000-0000-0000-0000-000000000003","quantity":1}]','Home Delivery','1 Road')$$, 'pickup only');
select t_expect($$select public.place_order('51000000-0000-0000-0000-000000000001','[{"product_id":"90000000-0000-0000-0000-000000000003","quantity":1}]','Pickup',null)$$, 'no longer sold');
select t_expect($$select public.place_order('51000000-0000-0000-0000-000000000001','[]','Pickup',null)$$, 'empty');
select t_expect($$select public.place_order('51000000-0000-0000-0000-000000000001','[{"product_id":"90000000-0000-0000-0000-000000000001","quantity":-3}]','Pickup',null)$$, 'Invalid quantity');
select t_expect($$insert into public.orders(user_id,store_id,total_price) values ('aaaaaaaa-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001',1)$$, 'row-level security');
select t_expect($$insert into public.order_items(order_id,name,price) values ('$$||:'o1_id'||$$','x',0)$$, 'row-level security');

select public.place_order('51000000-0000-0000-0000-000000000001',
  '[{"product_id":"90000000-0000-0000-0000-000000000001","quantity":1}]'::jsonb,'Home Delivery','12 Palm Rd') as id \gset o2_
select t_assert('delivery order: 90 + fee 80 = 170, address saved',
  (select total_price=170 and delivery_fee=80 and delivery_address='12 Palm Rd' from public.orders where id=:'o2_id'));

-- customer cannot tamper
update public.orders set total_price=1, delivery_fee=0, user_id='cccccccc-0000-0000-0000-000000000003' where id=:'o2_id';
select t_assert('customer edits to price/owner are ignored',
  (select total_price=170 and user_id='aaaaaaaa-0000-0000-0000-000000000001' from public.orders where id=:'o2_id'));
select t_expect($$update public.orders set status='Processed' where id='$$||:'o2_id'||$$'$$, 'cancel an order only before');
select t_expect($$update public.orders set status='Delivered' where id='$$||:'o2_id'||$$'$$, 'cancel an order only before');

-- customer cancels order 2 while pending
update public.orders set status='Cancelled' where id=:'o2_id';
select t_assert('cancel: cancelled_by=customer, stock restored (Widget back to 3)',
  (select cancelled_by='customer' and not stock_reserved from public.orders where id=:'o2_id')
  and (select quantity from public.products where id='90000000-0000-0000-0000-000000000001')=3);
update public.orders set status='Cancelled' where id=:'o2_id';
select t_assert('cancelling twice does not restore stock twice',
  (select quantity from public.products where id='90000000-0000-0000-0000-000000000001')=3);
select t_expect($$update public.orders set status='Pending' where id='$$||:'o2_id'||$$'$$, 'cancel an order only before');
select t_assert('history: Pending, Cancelled',
  (select string_agg(status, ',' order by id) from public.order_status_history where order_id=:'o2_id')='Pending,Cancelled');
reset role;

-- ===== owner B moves order 1
select set_config('request.jwt.claim.sub','bbbbbbbb-0000-0000-0000-000000000002',false);
set role authenticated;
select t_assert('owner was notified of both new orders and the cancellation',
  (select count(*) from public.notifications where user_id='bbbbbbbb-0000-0000-0000-000000000002' and title='New order')=2
  and (select count(*) from public.notifications where user_id='bbbbbbbb-0000-0000-0000-000000000002' and title='Order cancelled')=1);
select t_expect($$update public.orders set status='Shipped' where id='$$||:'o1_id'||$$'$$, 'next step only');
update public.orders set status='Processed', total_price=1 where id=:'o1_id';
select t_assert('owner Pending->Processed ok; owner cannot change the price',
  (select status='Processed' and total_price=220 from public.orders where id=:'o1_id'));
select t_expect($$update public.orders set status='Pending' where id='$$||:'o1_id'||$$'$$, 'next step only');
update public.orders set status='Shipped' where id=:'o1_id';
reset role;

select set_config('request.jwt.claim.sub','aaaaaaaa-0000-0000-0000-000000000001',false);
set role authenticated;
select t_expect($$update public.orders set status='Cancelled' where id='$$||:'o1_id'||$$'$$, 'cancel an order only before');
select t_assert('customer got "Order update" notifications for Processed and Shipped',
  (select count(*) from public.notifications where user_id='aaaaaaaa-0000-0000-0000-000000000001' and title='Order update')=2);
select t_assert('customer sees history Pending,Processed,Shipped',
  (select string_agg(status, ',' order by id) from public.order_status_history where order_id=:'o1_id')='Pending,Processed,Shipped');
reset role;

-- owner cancels a shipped order (store cancellation)
select set_config('request.jwt.claim.sub','bbbbbbbb-0000-0000-0000-000000000002',false);
set role authenticated;
update public.orders set status='Cancelled' where id=:'o1_id';
select t_assert('store cancel: cancelled_by=store, stock restored (Widget 5, Gadget 2)',
  (select cancelled_by='store' from public.orders where id=:'o1_id')
  and (select quantity from public.products where id='90000000-0000-0000-0000-000000000001')=5
  and (select quantity from public.products where id='90000000-0000-0000-0000-000000000002')=2);
select t_expect($$update public.orders set status='Processed' where id='$$||:'o1_id'||$$'$$, 'already cancelled');
reset role;
select t_assert('customer notified of the store cancellation (not told the owner cancelled themselves)',
  (select count(*) from public.notifications where user_id='aaaaaaaa-0000-0000-0000-000000000001' and body like '%now Cancelled%')=1
  and (select count(*) from public.notifications where user_id='bbbbbbbb-0000-0000-0000-000000000002' and title='Order cancelled')=1);

-- ===== outsiders
select set_config('request.jwt.claim.sub','cccccccc-0000-0000-0000-000000000003',false);
set role authenticated;
select t_assert('another customer cannot see the order, items or history',
  (select count(*) from public.orders)=0 and (select count(*) from public.order_items)=0
  and (select count(*) from public.order_status_history)=0);
update public.orders set status='Cancelled' where id=:'o1_id';
reset role;
select set_config('request.jwt.claim.sub','eeeeeeee-0000-0000-0000-000000000005',false);
set role authenticated;
update public.orders set status='Processed' where id=:'o1_id';
select t_assert('another owner cannot touch it', (select status from public.orders limit 1) is null);
reset role;
select t_assert('status unchanged by outsiders', (select status from public.orders where id=:'o1_id')='Cancelled');

-- owner cannot order from own store
select set_config('request.jwt.claim.sub','bbbbbbbb-0000-0000-0000-000000000002',false);
set role authenticated;
select t_expect($$select public.place_order('51000000-0000-0000-0000-000000000001','[{"product_id":"90000000-0000-0000-0000-000000000001","quantity":1}]','Pickup',null)$$, 'own store');
reset role;

-- inactive store
select set_config('request.jwt.claim.sub','',false);
update public.stores set is_active=false where id='51000000-0000-0000-0000-000000000001';
select set_config('request.jwt.claim.sub','aaaaaaaa-0000-0000-0000-000000000001',false);
set role authenticated;
select t_expect($$select public.place_order('51000000-0000-0000-0000-000000000001','[{"product_id":"90000000-0000-0000-0000-000000000001","quantity":1}]','Pickup',null)$$, 'not taking orders');
reset role;
select set_config('request.jwt.claim.sub','',false);
update public.stores set is_active=true where id='51000000-0000-0000-0000-000000000001';

-- deleting an order with reserved stock restores it; anonymous cannot order
select set_config('request.jwt.claim.sub','aaaaaaaa-0000-0000-0000-000000000001',false);
set role authenticated;
select public.place_order('51000000-0000-0000-0000-000000000001','[{"product_id":"90000000-0000-0000-0000-000000000001","quantity":3}]'::jsonb,'Pickup',null) as id \gset o3_
select t_assert('stock 5->2 after order 3', (select quantity from public.products where id='90000000-0000-0000-0000-000000000001')=2);
reset role;
select set_config('request.jwt.claim.sub','dddddddd-0000-0000-0000-000000000004',false);
set role authenticated;
delete from public.orders where id=:'o3_id';
select t_assert('deleting a pending order restores stock', (select quantity from public.products where id='90000000-0000-0000-0000-000000000001')=5);
reset role;
select set_config('request.jwt.claim.sub','',false);
set role anon;
select t_expect($$select public.place_order('51000000-0000-0000-0000-000000000001','[]','Pickup',null)$$, 'permission denied');
reset role;
select set_config('request.jwt.claim.sub','aaaaaaaa-0000-0000-0000-000000000001',false);
set role authenticated;
update public.profiles set role='Admin', store_access=true, has_paid=true where id='aaaaaaaa-0000-0000-0000-000000000001';
select t_assert('a customer cannot promote themselves (role/store_access/has_paid unchanged)',
  (select role='User' and not store_access and not has_paid from public.profiles where id='aaaaaaaa-0000-0000-0000-000000000001'));
select public.place_order('51000000-0000-0000-0000-000000000001','[{"product_id":"90000000-0000-0000-0000-000000000001","quantity":2}]'::jsonb,'Pickup',null) as id \gset o4_
reset role;
select set_config('request.jwt.claim.sub','dddddddd-0000-0000-0000-000000000004',false);
set role authenticated;
update public.orders set status='Cancelled' where id=:'o4_id';
reset role;
select t_assert('admin cancel: cancelled_by=admin, stock restored, customer told',
  (select cancelled_by='admin' from public.orders where id=:'o4_id')
  and (select quantity from public.products where id='90000000-0000-0000-0000-000000000001')=5
  and exists (select 1 from public.notifications where user_id='aaaaaaaa-0000-0000-0000-000000000001' and data->>'orderId'=:'o4_id'));
set role authenticated;
select t_assert('admin can read all 3 remaining orders and their history',
  (select count(*) from public.orders)=3 and (select count(*) from public.order_status_history)>=6);
reset role;
