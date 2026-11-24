\pset format unaligned
\pset tuples_only on
create or replace function public.t_expect(q text, pat text) returns text language plpgsql as $$
begin execute q; return 'FAIL (no error): ' || q;
exception when others then
  if sqlerrm ilike '%' || pat || '%' then return 'ok  (' || sqlerrm || ')'; end if;
  return 'FAIL (wrong error "' || sqlerrm || '"): ' || q; end $$;
create or replace function public.t_assert(label text, cond boolean) returns text language sql as $$
  select case when cond then 'ok   ' else 'FAIL ' end || label $$;
insert into auth.users(id,email) values
 ('11111111-0000-0000-0000-000000000001','late@t'),('22222222-0000-0000-0000-000000000002','fresh@t'),
 ('33333333-0000-0000-0000-000000000003','nopay@t'),('44444444-0000-0000-0000-000000000004','user@t');
update public.profiles set role='Owner', store_access=true, has_paid=true where email in ('late@t','fresh@t','nopay@t');
update public.profiles set store_access=true where email='user@t';
insert into public.stores(id,owner_id,name) values
 ('a1000000-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000001','Late'),
 ('a2000000-0000-0000-0000-000000000002','22222222-0000-0000-0000-000000000002','Fresh'),
 ('a3000000-0000-0000-0000-000000000003','33333333-0000-0000-0000-000000000003','NoPay');
insert into public.payments(user_id, amount, payment_status, paid_at) values
 ('11111111-0000-0000-0000-000000000001', 10, 'Completed', now() - interval '31 days'),
 ('11111111-0000-0000-0000-000000000001', 10, 'Completed', now() - interval '45 days'),
 ('22222222-0000-0000-0000-000000000002', 10, 'Completed', now() - interval '29 days');
select t_assert('3 owners lapse or not: expire returns 2 stores hidden', public.expire_store_access()=2);
select t_assert('late owner: access off, has_paid off, store hidden',
  (select not store_access and not has_paid from public.profiles where email='late@t')
  and not (select is_active from public.stores where name='Late'));
select t_assert('owner with no payment is expired too (same as the old function)',
  not (select is_active from public.stores where name='NoPay'));
select t_assert('paid 29 days ago stays active', (select is_active from public.stores where name='Fresh')
  and (select store_access from public.profiles where email='fresh@t'));
select t_assert('a non-owner is never touched', (select store_access from public.profiles where email='user@t'));
select t_assert('running again changes nothing', public.expire_store_access()=0);
insert into public.payments(user_id, amount, payment_status) values ('11111111-0000-0000-0000-000000000001', 10, 'Completed');
select t_assert('a completed payment shows the store again', (select is_active from public.stores where name='Late'));
insert into public.payments(user_id, amount, payment_status) values ('33333333-0000-0000-0000-000000000003', 10, 'Pending');
select t_assert('a pending payment does not', not (select is_active from public.stores where name='NoPay'));
update public.payments set payment_status='Completed' where user_id='33333333-0000-0000-0000-000000000003';
select t_assert('approving it (update) does', (select is_active from public.stores where name='NoPay'));
set role authenticated;
select t_expect($$select public.expire_store_access()$$, 'permission denied');
reset role;
