-- Server-side order rules, status history, store hours and order notifications.
--
-- * place_order(): one transaction that checks stock, prices the items from the
--   products table (the client cannot set prices), reserves stock and tells
--   the store owner. Direct inserts into orders/order_items are closed.
-- * guard_order_update: a customer may only cancel a Pending order; a store
--   moves an order one step forward (Pending -> Processed -> Shipped ->
--   Delivered) or cancels it. Other columns are kept as they were.
-- * order_status_history: one row per status, written by triggers.
-- * Cancelling an order puts the reserved stock back (once).
-- * Notifications: new order -> owner; status change by the store -> customer;
--   cancellation by the customer -> owner.

-- ---------------------------------------------------------------- columns
alter table public.stores
  add column if not exists is_active boolean not null default true,
  add column if not exists opening_hours jsonb,
  add column if not exists temporarily_closed boolean not null default false;

alter table public.orders
  add column if not exists cancelled_by text check (cancelled_by in ('customer','store','admin')),
  add column if not exists stock_reserved boolean not null default false;

-- ---------------------------------------------------------------- history
create table if not exists public.order_status_history (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.orders(id) on delete cascade,
  status text not null,
  changed_by uuid references public.profiles(id) on delete set null,
  changed_at timestamptz not null default now()
);
create index if not exists order_status_history_order_idx
  on public.order_status_history(order_id, changed_at);

alter table public.order_status_history enable row level security;
drop policy if exists order_history_read on public.order_status_history;
create policy order_history_read on public.order_status_history for select to authenticated using (
  exists (select 1 from public.orders o where o.id = order_id
          and (o.user_id = auth.uid() or public.is_store_owner(o.store_id) or public.is_admin())));
-- No write policies: only the triggers below (security definer) write here.

-- Earlier orders get a starting entry so their timeline is not empty.
insert into public.order_status_history(order_id, status, changed_at)
select o.id, o.status, o.placed_at from public.orders o
where not exists (select 1 from public.order_status_history h where h.order_id = o.id);

-- ---------------------------------------------------------------- helpers
create or replace function public.notify(uid uuid, t text, b text, d jsonb)
returns void language sql security definer set search_path = public as $$
  insert into public.notifications(user_id, title, body, type, data)
  select uid, t, b, 'order', d where uid is not null;
$$;
revoke all on function public.notify(uuid, text, text, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------- place_order
-- p_items: [{"product_id": "<uuid>", "quantity": 2}, ...]
create or replace function public.place_order(
  p_store_id uuid,
  p_items jsonb,
  p_delivery_method text,
  p_delivery_address text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  s public.stores;
  is_delivery boolean := coalesce(p_delivery_method, '') ilike '%delivery%';
  line record;
  p public.products;
  unit numeric(12,2);
  ids uuid[] := '{}';
  qtys int[] := '{}';
  units numeric(12,2)[] := '{}';
  subtotal numeric(12,2) := 0;
  fee numeric(12,2) := 0;
  new_id uuid;
  buyer_name text;
begin
  if uid is null then
    raise exception 'Sign in to place an order.' using errcode = '42501';
  end if;

  select * into s from public.stores where id = p_store_id;
  if not found or not s.is_active then
    raise exception 'This store is not taking orders right now.';
  end if;
  if s.owner_id = uid then
    raise exception 'You cannot order from your own store.';
  end if;

  if is_delivery then
    if cardinality(s.delivery_options) > 0
       and not exists (select 1 from unnest(s.delivery_options) o where o ilike '%home delivery%') then
      raise exception '% offers pickup only.', s.name;
    end if;
    if coalesce(trim(p_delivery_address), '') = '' then
      raise exception 'Add a delivery address.';
    end if;
    fee := coalesce(s.delivery_cost, 50);
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Your order is empty.';
  end if;

  -- Price and check every line first (locking the products), then write.
  for line in
    select x.product_id, sum(x.quantity)::int as qty
    from jsonb_to_recordset(p_items) as x(product_id uuid, quantity int)
    group by x.product_id
  loop
    if line.product_id is null or line.qty is null or line.qty < 1 or line.qty > 999 then
      raise exception 'Invalid quantity in your order.';
    end if;
    select * into p from public.products where id = line.product_id for update;
    if not found or p.store_id <> p_store_id then
      raise exception 'An item in your order is no longer sold by this store.';
    end if;
    if not p.is_available or p.quantity < line.qty then
      raise exception 'Only % of % left in stock.', greatest(p.quantity, 0), p.name;
    end if;
    unit := case when coalesce(p.discount, 0) > 0
                 then round(p.price * (1 - p.discount / 100), 2) else p.price end;
    subtotal := subtotal + unit * line.qty;
    ids := ids || p.id;
    qtys := qtys || line.qty;
    units := units || unit;
  end loop;

  insert into public.orders(user_id, store_id, total_price, status, delivery_method,
                            delivery_fee, delivery_address, stock_reserved)
  values (uid, p_store_id, subtotal + fee, 'Pending',
          coalesce(nullif(p_delivery_method, ''), 'Unknown'),
          fee, case when is_delivery then trim(p_delivery_address) end, true)
  returning id into new_id;

  insert into public.order_items(order_id, product_id, name, price, image_url, quantity)
  select new_id, pr.id, pr.name, l.unit, pr.image_url, l.qty
  from unnest(ids, qtys, units) as l(id, qty, unit)
  join public.products pr on pr.id = l.id;

  update public.products pr set quantity = pr.quantity - l.qty
  from unnest(ids, qtys) as l(id, qty)
  where pr.id = l.id;

  select coalesce(nullif(name, ''), 'A customer') into buyer_name from public.profiles where id = uid;
  perform public.notify(s.owner_id, 'New order',
    format('%s placed an order (Rs %s).', buyer_name, to_char(subtotal + fee, 'FM999999990.00')),
    jsonb_build_object('orderId', new_id, 'storeId', p_store_id));

  return new_id;
end $$;
revoke all on function public.place_order(uuid, jsonb, text, text) from public, anon;
grant execute on function public.place_order(uuid, jsonb, text, text) to authenticated;

-- Orders are created only through place_order().
drop policy if exists orders_insert on public.orders;
drop policy if exists order_items_insert on public.order_items;

-- ---------------------------------------------------------------- update rules
create or replace function public.guard_order_update() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  requested text := new.status;
  flow text[] := array['Pending','Processed','Shipped','Delivered'];
  i int;
begin
  if auth.uid() is null or public.is_admin() then
    -- Service role, SQL editor or an admin: no step rules.
    if requested = 'Cancelled' and old.status <> 'Cancelled' and new.cancelled_by is null then
      new.cancelled_by := 'admin';
    end if;

  elsif public.is_store_owner(old.store_id) then
    new.user_id := old.user_id;
    new.store_id := old.store_id;
    new.total_price := old.total_price;
    new.delivery_fee := old.delivery_fee;
    new.stock_reserved := old.stock_reserved;
    new.cancelled_by := old.cancelled_by;
    if requested is distinct from old.status then
      if old.status in ('Delivered','Cancelled') then
        raise exception 'This order is already %.', lower(old.status);
      end if;
      if requested = 'Cancelled' then
        new.cancelled_by := 'store';
      else
        i := array_position(flow, old.status);
        if i is null or flow[i + 1] is distinct from requested then
          raise exception 'Move the order to the next step only.';
        end if;
      end if;
    end if;

  elsif old.user_id = auth.uid() then
    if requested is distinct from old.status
       and not (old.status = 'Pending' and requested = 'Cancelled') then
      raise exception 'You can cancel an order only before the store starts on it.';
    end if;
    new := old;           -- the customer can change nothing else
    new.status := requested;
    if requested = 'Cancelled' and old.status <> 'Cancelled' then
      new.cancelled_by := 'customer';
    end if;

  else
    raise exception 'Not allowed.' using errcode = '42501';
  end if;

  -- Cancelling puts the reserved stock back, once.
  if new.status = 'Cancelled' and old.status <> 'Cancelled' and old.stock_reserved then
    update public.products p set quantity = p.quantity + oi.quantity
      from public.order_items oi
     where oi.order_id = old.id and oi.product_id = p.id;
    new.stock_reserved := false;
  end if;
  return new;
end $$;

drop trigger if exists guard_order on public.orders;
create trigger guard_order before update on public.orders
  for each row execute function public.guard_order_update();

-- ---------------------------------------------------------------- after triggers
create or replace function public.order_after_write() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  store_name text;
  owner uuid;
  buyer_name text;
  d jsonb := jsonb_build_object('orderId', new.id, 'storeId', new.store_id);
begin
  if tg_op = 'INSERT' then
    insert into public.order_status_history(order_id, status, changed_by, changed_at)
    values (new.id, new.status, auth.uid(), new.placed_at);
    return new;
  end if;

  if new.status is not distinct from old.status then
    return new;
  end if;

  insert into public.order_status_history(order_id, status, changed_by)
  values (new.id, new.status, auth.uid());

  select s.name, s.owner_id into store_name, owner from public.stores s where s.id = new.store_id;

  if new.cancelled_by = 'customer' and new.status = 'Cancelled' then
    select coalesce(nullif(name, ''), 'A customer') into buyer_name
      from public.profiles where id = new.user_id;
    perform public.notify(owner, 'Order cancelled',
      format('%s cancelled their order.', buyer_name), d);
  else
    perform public.notify(new.user_id, 'Order update',
      format('Your order from %s is now %s.', coalesce(store_name, 'the store'), new.status), d);
  end if;
  return new;
end $$;

drop trigger if exists order_after_insert on public.orders;
create trigger order_after_insert after insert on public.orders
  for each row execute function public.order_after_write();
drop trigger if exists order_after_update on public.orders;
create trigger order_after_update after update of status on public.orders
  for each row execute function public.order_after_write();

-- Deleting an order that still holds stock puts it back as well.
create or replace function public.order_before_delete() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if old.stock_reserved then
    update public.products p set quantity = p.quantity + oi.quantity
      from public.order_items oi
     where oi.order_id = old.id and oi.product_id = p.id;
  end if;
  return old;
end $$;
drop trigger if exists order_before_delete on public.orders;
create trigger order_before_delete before delete on public.orders
  for each row execute function public.order_before_delete();

-- The order list reads live status changes.
do $$ begin
  alter publication supabase_realtime add table public.orders;
exception when duplicate_object then null;
end $$;
