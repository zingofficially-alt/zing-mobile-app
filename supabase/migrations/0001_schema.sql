-- ZING: Firestore -> Supabase Postgres. Schema, triggers and Row Level Security.
create extension if not exists pgcrypto;

-- ------------------------------------------------------------------ tables
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  email text not null default '',
  phone_number text not null default '',
  address text not null default '',
  profile_image_url text not null default '',
  role text not null default 'User' check (role in ('User','Owner','Admin')),
  store_access boolean not null default false,
  has_paid boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.stores (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  description text not null default '',
  category text not null default '',
  image_url text not null default '',
  phone_number text not null default '',
  latitude double precision,
  longitude double precision,
  registration_amount numeric(12,2),
  delivery_options text[] not null default '{}',
  delivery_cost numeric(12,2),
  created_at timestamptz not null default now()
);
create index on public.stores(owner_id);
create index on public.stores(category);

create table public.store_videos (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  url text not null
);
create index on public.store_videos(store_id);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null,
  description text,
  price numeric(12,2) not null default 0,
  rating numeric(3,2),
  image_url text,
  is_available boolean not null default true,
  discount numeric(5,2),
  quantity integer not null default 0,
  created_at timestamptz not null default now()
);
create index on public.products(store_id);

create table public.store_ratings (
  store_id uuid not null references public.stores(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  rating numeric(3,2) not null check (rating between 0 and 5),
  created_at timestamptz not null default now(),
  primary key (store_id, user_id)
);

create table public.user_favorites (
  user_id uuid not null references public.profiles(id) on delete cascade,
  store_id uuid not null references public.stores(id) on delete cascade,
  primary key (user_id, store_id)
);

create table public.cart_items (
  user_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  store_id uuid references public.stores(id) on delete cascade,
  name text not null,
  price numeric(12,2) not null,
  image_url text,
  quantity integer not null default 1 check (quantity > 0),
  primary key (user_id, product_id)
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  store_id uuid not null references public.stores(id) on delete cascade,
  total_price numeric(12,2) not null default 0,
  status text not null default 'Pending',
  delivery_method text not null default 'Unknown',
  placed_at timestamptz not null default now()
);
create index on public.orders(user_id);
create index on public.orders(store_id);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  name text not null,
  price numeric(12,2) not null,
  image_url text,
  quantity integer not null default 1
);
create index on public.order_items(order_id);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  store_id uuid references public.stores(id) on delete set null,
  external_payment_id text,
  amount numeric(12,2) not null,
  currency text not null default 'INR',
  items text not null default '',
  payment_status text not null default 'Pending',
  paid_at timestamptz not null default now()
);
create index on public.payments(user_id);

create table public.chats (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  store_id uuid not null references public.stores(id) on delete cascade,
  last_message text not null default '',
  last_updated timestamptz not null default now(),
  unique (user_id, store_id)
);

create table public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.chats(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  message text not null,
  is_image boolean not null default false,
  reply_to_text text,
  reply_to_sender_name text,
  created_at timestamptz not null default now()
);
create index on public.chat_messages(chat_id, created_at);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null default '',
  body text not null default '',
  type text not null default 'system',
  is_read boolean not null default false,
  data jsonb,
  created_at timestamptz not null default now()
);
create index on public.notifications(user_id, created_at desc);

create table public.offers (
  id uuid primary key default gen_random_uuid(),
  text text not null default '',
  image_url text not null default '',
  created_at timestamptz not null default now()
);

create table public.advertisements (
  id uuid primary key default gen_random_uuid(),
  image_url text not null default '',
  description text not null default '',
  created_at timestamptz not null default now()
);

create table public.app_settings (
  id text primary key default 'default',
  registration_amount numeric(12,2) not null default 0,
  currency text not null default 'INR'
);
insert into public.app_settings(id) values ('default') on conflict do nothing;

-- replaces logUserEvent (recommendation input)
create table public.user_events (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles(id) on delete cascade,
  event_type text not null,
  product_id uuid references public.products(id) on delete set null,
  store_id uuid references public.stores(id) on delete set null,
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------------ helpers
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'Admin');
$$;

create or replace function public.is_store_owner(sid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.stores where id = sid and owner_id = auth.uid());
$$;

create or replace function public.is_chat_member(cid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.chats c join public.stores s on s.id = c.store_id
    where c.id = cid and (c.user_id = auth.uid() or s.owner_id = auth.uid())
  );
$$;

-- new auth user -> profile row (role is always 'User'; only an admin can change it)
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id, email, phone_number, name)
  values (new.id, coalesce(new.email,''), coalesce(new.phone,''),
          coalesce(new.raw_user_meta_data->>'name',''))
  on conflict do nothing;
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- block privilege escalation (role / store_access / has_paid) by non-admins
create or replace function public.guard_profile_update() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    new.role := old.role;
    new.store_access := old.store_access;
    new.has_paid := old.has_paid;
  end if;
  return new;
end $$;
create trigger guard_profile before update on public.profiles
  for each row execute function public.guard_profile_update();

-- keep the chat summary current
create or replace function public.touch_chat() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update public.chats
     set last_message = case when new.is_image then 'Image' else new.message end,
         last_updated = now()
   where id = new.chat_id;
  return new;
end $$;
create trigger chat_touch after insert on public.chat_messages
  for each row execute function public.touch_chat();

create or replace view public.store_rating_summary with (security_invoker = true) as
  select store_id, avg(rating)::numeric(3,2) as avg_rating, count(*) as rating_count
  from public.store_ratings group by store_id;

-- ------------------------------------------------------------------ RLS
alter table public.profiles enable row level security;
alter table public.stores enable row level security;
alter table public.store_videos enable row level security;
alter table public.products enable row level security;
alter table public.store_ratings enable row level security;
alter table public.user_favorites enable row level security;
alter table public.cart_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.payments enable row level security;
alter table public.chats enable row level security;
alter table public.chat_messages enable row level security;
alter table public.notifications enable row level security;
alter table public.offers enable row level security;
alter table public.advertisements enable row level security;
alter table public.app_settings enable row level security;
alter table public.user_events enable row level security;

create policy profiles_read on public.profiles for select to authenticated using (true);
create policy profiles_insert on public.profiles for insert to authenticated with check (id = auth.uid());
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid() or public.is_admin()) with check (id = auth.uid() or public.is_admin());
create policy profiles_delete on public.profiles for delete to authenticated
  using (id = auth.uid() or public.is_admin());

create policy stores_read on public.stores for select using (true);
create policy stores_insert on public.stores for insert to authenticated
  with check (owner_id = auth.uid() or public.is_admin());
create policy stores_update on public.stores for update to authenticated
  using (owner_id = auth.uid() or public.is_admin()) with check (owner_id = auth.uid() or public.is_admin());
create policy stores_delete on public.stores for delete to authenticated
  using (owner_id = auth.uid() or public.is_admin());

create policy products_read on public.products for select using (true);
create policy products_write on public.products for all to authenticated
  using (public.is_store_owner(store_id) or public.is_admin())
  with check (public.is_store_owner(store_id) or public.is_admin());

create policy videos_read on public.store_videos for select using (true);
create policy videos_write on public.store_videos for all to authenticated
  using (public.is_store_owner(store_id) or public.is_admin())
  with check (public.is_store_owner(store_id) or public.is_admin());

create policy ratings_read on public.store_ratings for select using (true);
create policy ratings_write on public.store_ratings for all to authenticated
  using (user_id = auth.uid() or public.is_admin()) with check (user_id = auth.uid());

create policy favorites_self on public.user_favorites for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy cart_self on public.cart_items for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy orders_read on public.orders for select to authenticated
  using (user_id = auth.uid() or public.is_store_owner(store_id) or public.is_admin());
create policy orders_insert on public.orders for insert to authenticated with check (user_id = auth.uid());
create policy orders_update on public.orders for update to authenticated
  using (public.is_store_owner(store_id) or public.is_admin() or user_id = auth.uid());
create policy orders_delete on public.orders for delete to authenticated
  using (public.is_store_owner(store_id) or public.is_admin() or user_id = auth.uid());

create policy order_items_read on public.order_items for select to authenticated using (
  exists (select 1 from public.orders o where o.id = order_id
          and (o.user_id = auth.uid() or public.is_store_owner(o.store_id) or public.is_admin())));
create policy order_items_insert on public.order_items for insert to authenticated with check (
  exists (select 1 from public.orders o where o.id = order_id and o.user_id = auth.uid()));

create policy payments_read on public.payments for select to authenticated
  using (user_id = auth.uid() or public.is_admin());
create policy payments_write on public.payments for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy chats_read on public.chats for select to authenticated
  using (public.is_chat_member(id) or public.is_admin());
create policy chats_insert on public.chats for insert to authenticated with check (user_id = auth.uid());
create policy chats_update on public.chats for update to authenticated
  using (public.is_chat_member(id) or public.is_admin());
create policy chats_delete on public.chats for delete to authenticated
  using (public.is_chat_member(id) or public.is_admin());
create policy messages_read on public.chat_messages for select to authenticated
  using (public.is_chat_member(chat_id) or public.is_admin());
create policy messages_insert on public.chat_messages for insert to authenticated
  with check (sender_id = auth.uid() and public.is_chat_member(chat_id));
create policy messages_delete on public.chat_messages for delete to authenticated
  using (sender_id = auth.uid() or public.is_admin());

create policy notifications_read on public.notifications for select to authenticated
  using (user_id = auth.uid() or public.is_admin());
create policy notifications_update on public.notifications for update to authenticated
  using (user_id = auth.uid() or public.is_admin());
create policy notifications_delete on public.notifications for delete to authenticated
  using (user_id = auth.uid() or public.is_admin());
create policy notifications_insert on public.notifications for insert to authenticated
  with check (public.is_admin());

create policy offers_read on public.offers for select using (true);
create policy offers_write on public.offers for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy ads_read on public.advertisements for select using (true);
create policy ads_write on public.advertisements for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy settings_read on public.app_settings for select using (true);
create policy settings_write on public.app_settings for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy events_insert on public.user_events for insert to authenticated
  with check (user_id = auth.uid());

-- realtime for chat and notifications
alter publication supabase_realtime add table public.chat_messages, public.chats, public.notifications;

-- ------------------------------------------------------------------ storage buckets
insert into storage.buckets (id, name, public) values
  ('store-images','store-images',true),
  ('product-images','product-images',true),
  ('profile-images','profile-images',true),
  ('chat-images','chat-images',false),
  ('banners','banners',true)
on conflict do nothing;
