-- Store subscriptions: access ends 30 days after an owner's latest payment.
--
-- expire_store_access() is the SQL version of the old daily Cloud Function:
-- every owner with store access whose latest payment is older than 30 days
-- (or who has none) loses access and their stores are hidden from customers
-- (stores.is_active = false). A completed payment turns the stores back on.

create or replace function public.expire_store_access(period_days int default 30)
returns int
language plpgsql security definer set search_path = public as $$
declare
  n int;
begin
  with lapsed as (
    select p.id
    from public.profiles p
    where p.role = 'Owner' and p.store_access
      and coalesce((select max(pay.paid_at) from public.payments pay where pay.user_id = p.id),
                   'epoch'::timestamptz) < now() - make_interval(days => period_days)
  ), off as (
    update public.profiles p set store_access = false, has_paid = false
    from lapsed where p.id = lapsed.id
    returning p.id
  )
  update public.stores s set is_active = false
  from off where s.owner_id = off.id and s.is_active;

  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function public.expire_store_access(int) from public, anon, authenticated;

-- A completed payment shows the owner's stores again.
create or replace function public.payment_reactivates_stores() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.payment_status = 'Completed' then
    update public.stores set is_active = true where owner_id = new.user_id and not is_active;
  end if;
  return new;
end $$;

drop trigger if exists payment_reactivate on public.payments;
create trigger payment_reactivate after insert or update of payment_status on public.payments
  for each row execute function public.payment_reactivates_stores();

-- Run it every day at 01:00 UTC where pg_cron is available (enable it under
-- Database > Extensions in the Supabase dashboard). Elsewhere, call
-- `select public.expire_store_access();` from any scheduler.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule('expire-store-access', '0 1 * * *', 'select public.expire_store_access()');
  end if;
end $$;
