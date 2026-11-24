\pset format unaligned
\pset tuples_only on
grant usage on schema storage to authenticated;
grant all on storage.objects to authenticated;
create or replace function public.t_assert(label text, cond boolean) returns text language sql as $$
  select case when cond then 'ok   ' else 'FAIL ' end || label $$;
create or replace function public.t_expect(q text, pat text) returns text language plpgsql as $$
begin execute q; return 'FAIL (no error): ' || q;
exception when others then
  if sqlerrm ilike '%' || pat || '%' then return 'ok  (' || sqlerrm || ')'; end if;
  return 'FAIL (wrong error "' || sqlerrm || '"): ' || q; end $$;
create or replace function public.t_count(q text) returns int language plpgsql as $$
declare n int; begin execute q into n; return n; end $$;

insert into auth.users(id,email) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@t'),('bbbbbbbb-0000-0000-0000-000000000002','b@t'),
 ('cccccccc-0000-0000-0000-000000000003','c@t'),('dddddddd-0000-0000-0000-000000000004','d@t'),
 ('eeeeeeee-0000-0000-0000-000000000005','e@t');
update public.profiles set role='Admin' where email='d@t';
update public.profiles set role='Owner', name='Bee Owner' where email='b@t';
update public.profiles set role='Owner' where email='e@t';
insert into public.stores(id,owner_id,name) values
 ('51000000-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000002','Shop B'),
 ('52000000-0000-0000-0000-000000000002','eeeeeeee-0000-0000-0000-000000000005','Shop E');
-- A ordered from B (placed directly, as the service role) and chats with Shop B
insert into public.orders(user_id,store_id,total_price) values ('aaaaaaaa-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001',10);
insert into public.chats(id,user_id,store_id) values ('ca000000-0000-0000-0000-00000000000a','aaaaaaaa-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001');
-- C chats with Shop E only
insert into public.chats(id,user_id,store_id) values ('cb000000-0000-0000-0000-00000000000b','cccccccc-0000-0000-0000-000000000003','52000000-0000-0000-0000-000000000002');

-- who can read which profile
select set_config('request.jwt.claim.sub','aaaaaaaa-0000-0000-0000-000000000001',false); set role authenticated;
select t_assert('customer A sees self + owner B of the store they ordered from/chat with only',
  (select string_agg(email, ',' order by email) from public.profiles)='a@t,b@t');
select t_assert('A cannot read the email/phone of C, D or owner E', t_count($$select count(*) from public.profiles where email in ('c@t','d@t','e@t')$$)=0);
select t_assert('store_owner_info gives A the public owner details of any store',
  (select count(*) from public.store_owner_info(array['51000000-0000-0000-0000-000000000001','52000000-0000-0000-0000-000000000002']::uuid[]))=2
  and (select name from public.store_owner_info(array['51000000-0000-0000-0000-000000000001']::uuid[]))='Bee Owner');
select t_assert('store_owner_info exposes no email or phone',
  (select count(*) from information_schema.routines r join information_schema.parameters p on p.specific_name=r.specific_name
   where r.routine_name='store_owner_info' and p.parameter_name in ('email','phone_number','address'))=0);
reset role;
select set_config('request.jwt.claim.sub','bbbbbbbb-0000-0000-0000-000000000002',false); set role authenticated;
select t_assert('owner B sees self and their customer A, not C or E',
  (select string_agg(email, ',' order by email) from public.profiles)='a@t,b@t');
reset role;
select set_config('request.jwt.claim.sub','cccccccc-0000-0000-0000-000000000003',false); set role authenticated;
select t_assert('C sees self + owner E (chats with Shop E), not A or B',
  (select string_agg(email, ',' order by email) from public.profiles)='c@t,e@t');
reset role;
select set_config('request.jwt.claim.sub','eeeeeeee-0000-0000-0000-000000000005',false); set role authenticated;
select t_assert('owner E sees self + customer C, not A or B',
  (select string_agg(email, ',' order by email) from public.profiles)='c@t,e@t');
reset role;
select set_config('request.jwt.claim.sub','dddddddd-0000-0000-0000-000000000004',false); set role authenticated;
select t_assert('admin sees all 5', (select count(*) from public.profiles)=5);
reset role;
set role anon;
select t_assert('signed-out visitors can call store_owner_info (store pages are public)',
  (select count(*) from public.store_owner_info(array['51000000-0000-0000-0000-000000000001']::uuid[]))=1);
select t_assert('a signed-out visitor sees no profiles at all', t_count($$select count(*) from public.profiles$$)=0);
reset role;

-- uploads
select set_config('request.jwt.claim.sub','aaaaaaaa-0000-0000-0000-000000000001',false); set role authenticated;
select t_expect($$insert into storage.objects(bucket_id,name) values ('store-images','store_images/1.jpg')$$, 'row-level security');
select t_expect($$insert into storage.objects(bucket_id,name) values ('product-images','products/p.jpg')$$, 'row-level security');
insert into storage.objects(bucket_id,name) values ('profile-images','aaaaaaaa-0000-0000-0000-000000000001/profile.jpg');
select t_expect($$insert into storage.objects(bucket_id,name) values ('profile-images','cccccccc-0000-0000-0000-000000000003/profile.jpg')$$, 'row-level security');
insert into storage.objects(bucket_id,name) values ('chat-images','ca000000-0000-0000-0000-00000000000a/1.jpg');
select t_expect($$insert into storage.objects(bucket_id,name) values ('chat-images','cb000000-0000-0000-0000-00000000000b/1.jpg')$$, 'row-level security');
select t_expect($$insert into storage.objects(bucket_id,name) values ('chat-images','not-a-uuid/1.jpg')$$, 'row-level security');
select t_assert('A uploaded a profile image and a chat image of their own (reads back the chat image)', t_count($$select count(*) from storage.objects where bucket_id='chat-images'$$)=1);
reset role; select t_assert('both of A''s uploads exist', (select count(*) from storage.objects)=2); set role authenticated;
reset role;
select set_config('request.jwt.claim.sub','bbbbbbbb-0000-0000-0000-000000000002',false); set role authenticated;
insert into storage.objects(bucket_id,name) values ('store-images','store_images/1.jpg'),('product-images','products/p.jpg');
insert into storage.objects(bucket_id,name) values ('chat-images','ca000000-0000-0000-0000-00000000000a/2.jpg');
select t_assert('owner B can upload store/product images and answer in their chat; sees that chat image',
  t_count($$select count(*) from storage.objects where bucket_id='chat-images'$$)=2);
select t_expect($$insert into storage.objects(bucket_id,name) values ('chat-images','cb000000-0000-0000-0000-00000000000b/9.jpg')$$, 'row-level security');
reset role;
select set_config('request.jwt.claim.sub','cccccccc-0000-0000-0000-000000000003',false); set role authenticated;
select t_assert('another customer cannot read or list A and B''s chat images', t_count($$select count(*) from storage.objects where bucket_id='chat-images'$$)=0);
reset role;
select set_config('request.jwt.claim.sub','dddddddd-0000-0000-0000-000000000004',false); set role authenticated;
select t_assert('admin can read chat images', t_count($$select count(*) from storage.objects where bucket_id='chat-images'$$)=2);
