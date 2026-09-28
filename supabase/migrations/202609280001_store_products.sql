create table if not exists public.store_products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  image_url text,
  description text not null,
  condition text not null check (condition in ('Novo', 'Seminovo')),
  quantity integer not null default 0 check (quantity >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists store_products_available_idx
  on public.store_products (active, quantity, updated_at desc);

drop trigger if exists store_products_touch on public.store_products;
create trigger store_products_touch
  before update on public.store_products
  for each row execute function public.touch_updated_at();

alter table public.store_products enable row level security;

drop policy if exists "public reads available products" on public.store_products;
create policy "public reads available products"
  on public.store_products for select to anon, authenticated
  using (active and quantity > 0);

drop policy if exists "admins manage products" on public.store_products;
create policy "admins manage products"
  on public.store_products for all to authenticated
  using (public.is_plfix_admin())
  with check (public.is_plfix_admin());

do $$
begin
  alter publication supabase_realtime add table public.store_products;
exception
  when duplicate_object then null;
end
$$;
