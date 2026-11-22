-- Orders carried a delivery fee and address in Firestore.
alter table public.orders
  add column if not exists delivery_fee numeric(12,2) not null default 0,
  add column if not exists delivery_address text;

-- ---------------------------------------------------------------- storage policies
-- Public buckets are readable by URL. Signed-in users upload; owners/admins manage.
create policy "upload user images" on storage.objects for insert to authenticated
  with check (bucket_id in ('store-images','product-images','profile-images','chat-images'));
create policy "admin uploads banners" on storage.objects for insert to authenticated
  with check (bucket_id = 'banners' and public.is_admin());
create policy "read chat images" on storage.objects for select to authenticated
  using (bucket_id = 'chat-images');
create policy "manage own uploads" on storage.objects for update to authenticated
  using (owner_id = auth.uid()::text or public.is_admin());
create policy "delete own uploads" on storage.objects for delete to authenticated
  using (owner_id = auth.uid()::text or public.is_admin());

-- Chat "last seen" (read by the chat screen).
alter table public.profiles add column if not exists last_active_at timestamptz;

-- Sign-up metadata (name, phone_number) fills the new profile row.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id, email, phone_number, name)
  values (new.id, coalesce(new.email,''),
          coalesce(nullif(new.phone,''), new.raw_user_meta_data->>'phone_number', ''),
          coalesce(new.raw_user_meta_data->>'name',''))
  on conflict do nothing;
  return new;
end $$;

-- Chat policies must not call a function that re-reads the new row (INSERT ... RETURNING
-- cannot see it), so test the columns directly.
drop policy if exists chats_read on public.chats;
drop policy if exists chats_update on public.chats;
drop policy if exists chats_delete on public.chats;
create policy chats_read on public.chats for select to authenticated
  using (user_id = auth.uid() or public.is_store_owner(store_id) or public.is_admin());
create policy chats_update on public.chats for update to authenticated
  using (user_id = auth.uid() or public.is_store_owner(store_id) or public.is_admin());
create policy chats_delete on public.chats for delete to authenticated
  using (user_id = auth.uid() or public.is_store_owner(store_id) or public.is_admin());
