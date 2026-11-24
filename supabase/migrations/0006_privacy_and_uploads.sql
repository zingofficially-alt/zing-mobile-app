-- Privacy of profiles and who may upload what.
--
-- * profiles: until now every signed-in user could read every profile (email,
--   phone, address). A profile is now readable by its owner, by admins, by a
--   store owner for customers who ordered from or chat with their store, and by
--   a customer for the owner of a store they chat with.
-- * store_owner_info(): the public part of a store's owner (name, photo) for
--   store pages, since customers can no longer read the profile itself.
-- * storage: uploads were open to any signed-in user in every bucket. Now
--   store/product images need an Owner or Admin, a profile image goes in the
--   user's own folder, and a chat image goes in a chat the user belongs to
--   (and only members can read it).

-- ---------------------------------------------------------------- profiles
create or replace function public.can_see_profile(pid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select pid = auth.uid()
      or public.is_admin()
      or exists (select 1 from public.orders o
                 join public.stores s on s.id = o.store_id
                 where o.user_id = pid and s.owner_id = auth.uid())
      or exists (select 1 from public.chats c
                 join public.stores s on s.id = c.store_id
                 where (c.user_id = pid and s.owner_id = auth.uid())
                    or (s.owner_id = pid and c.user_id = auth.uid()));
$$;

drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select to authenticated
  using (public.can_see_profile(id));

create or replace function public.store_owner_info(p_store_ids uuid[])
returns table(store_id uuid, id uuid, name text, profile_image_url text)
language sql stable security definer set search_path = public as $$
  select s.id, p.id, p.name, p.profile_image_url
  from public.stores s join public.profiles p on p.id = s.owner_id
  where s.id = any(p_store_ids);
$$;
revoke all on function public.store_owner_info(uuid[]) from public;
grant execute on function public.store_owner_info(uuid[]) to anon, authenticated;

-- ---------------------------------------------------------------- storage
create or replace function public.is_owner_or_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles
                 where id = auth.uid() and role in ('Owner', 'Admin'));
$$;

-- Chat images are stored as "<chat id>/<file>".
create or replace function public.can_use_chat_image(obj text) returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  return public.is_chat_member(split_part(obj, '/', 1)::uuid) or public.is_admin();
exception when others then
  return false;
end $$;

drop policy if exists "upload user images" on storage.objects;
drop policy if exists "read chat images" on storage.objects;

create policy "owners upload store and product images" on storage.objects
  for insert to authenticated
  with check (bucket_id in ('store-images', 'product-images') and public.is_owner_or_admin());

create policy "users upload their own profile image" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'profile-images'
              and (split_part(name, '/', 1) = auth.uid()::text or public.is_admin()));

create policy "members upload chat images" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'chat-images' and public.can_use_chat_image(name));

create policy "members read chat images" on storage.objects
  for select to authenticated
  using (bucket_id = 'chat-images' and public.can_use_chat_image(name));
