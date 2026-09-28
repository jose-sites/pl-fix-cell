alter table public.store_products
  add column if not exists brand text not null default 'iPhone';

alter table public.store_products drop constraint if exists store_products_android_condition_check;
alter table public.store_products add constraint store_products_android_condition_check
  check (brand = 'iPhone' or condition = 'Novo');

create index if not exists store_products_brand_idx
  on public.store_products (brand, condition, active, updated_at desc);
