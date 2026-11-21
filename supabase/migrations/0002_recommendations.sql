-- Replaces Google Cloud Retail recommendations with a Postgres query:
-- products from stores/categories the user touched recently, then overall popularity.
create or replace function public.recommend_products(uid uuid, lim int default 10)
returns setof public.products
language sql stable security definer set search_path = public as $$
  with interest as (
    select distinct s.category
    from public.user_events e
    join public.stores s on s.id = e.store_id
    where e.user_id = uid and e.created_at > now() - interval '30 days'
  ),
  popularity as (
    select product_id, count(*) as n from public.user_events
    where product_id is not null group by product_id
  )
  select p.*
  from public.products p
  join public.stores s on s.id = p.store_id
  left join popularity pop on pop.product_id = p.id
  where p.is_available
  order by (s.category in (select category from interest)) desc,
           coalesce(pop.n, 0) desc, p.created_at desc
  limit lim;
$$;
revoke all on function public.recommend_products(uuid, int) from public, anon, authenticated;
