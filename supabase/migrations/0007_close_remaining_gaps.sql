-- Closes four gaps left by 0001-0006.
--
-- 1. Anyone signed in could create a store. Now only an Owner whose store
--    access is active (or an admin) can.
-- 2. An owner could switch their own store back on (stores.is_active) after
--    the subscription lapsed. Only admins and the database jobs can change it.
-- 3. Customers and store owners could delete orders, erasing the history.
--    Only admins can delete an order now (cancel it instead).
-- 4. Users could rewrite the text of their own notifications. They can only
--    mark them read now.

-- ---------------------------------------------------------------- 1. store creation
create or replace function public.can_create_store() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles
                 where id = auth.uid() and role = 'Owner' and store_access);
$$;

drop policy if exists stores_insert on public.stores;
create policy stores_insert on public.stores for insert to authenticated
  with check (public.is_admin() or (owner_id = auth.uid() and public.can_create_store()));

-- ---------------------------------------------------------------- 2. is_active
-- A new store starts active; after that only an admin (or a job running
-- without a signed-in user, such as expire_store_access) can change it.
create or replace function public.guard_store_write() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    if tg_op = 'INSERT' then
      new.is_active := true;
    else
      new.is_active := old.is_active;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists guard_store on public.stores;
create trigger guard_store before insert or update on public.stores
  for each row execute function public.guard_store_write();

-- ---------------------------------------------------------------- 3. order deletion
drop policy if exists orders_delete on public.orders;
create policy orders_delete on public.orders for delete to authenticated
  using (public.is_admin());

-- ---------------------------------------------------------------- 4. notifications
create or replace function public.guard_notification_update() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  read_flag boolean := new.is_read;
begin
  if auth.uid() is not null and not public.is_admin() then
    new := old;
    new.is_read := read_flag;
  end if;
  return new;
end $$;

drop trigger if exists guard_notification on public.notifications;
create trigger guard_notification before update on public.notifications
  for each row execute function public.guard_notification_update();
