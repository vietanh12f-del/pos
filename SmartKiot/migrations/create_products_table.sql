-- Create products table if missing (finished goods catalog)
create extension if not exists "uuid-ossp";

create table if not exists products (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  price double precision not null default 0,
  category text not null default 'Khác',
  image_name text,
  color text,
  stock_quantity integer not null default 0,
  cost_price double precision default 0,
  barcode text,
  image_url text,
  store_id uuid,
  created_at timestamp with time zone default now()
);

create index if not exists idx_products_name on products (lower(name));
create index if not exists idx_products_category on products (category);
create index if not exists idx_products_barcode on products (barcode);

-- Optional RLS policies; enable if using per-store isolation
alter table products enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'products' and policyname = 'Products read'
  ) then
    create policy "Products read" on products
      for select using (true);
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'products' and policyname = 'Products write'
  ) then
    create policy "Products write" on products
      for insert with check (true);
    create policy "Products update" on products
      for update using (true);
    create policy "Products delete" on products
      for delete using (true);
  end if;
end $$;

-- PostgREST cache refresh (Supabase)
notify pgrst, 'reload schema';
