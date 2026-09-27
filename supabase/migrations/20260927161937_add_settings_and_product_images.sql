create table public.app_settings (
  id boolean primary key default true check (id),
  default_currency char(3) not null default 'USD',
  decimal_places integer not null default 2 check (decimal_places between 0 and 4),
  tax_percentage numeric(5, 2) not null default 0 check (tax_percentage between 0 and 100),
  prices_include_tax boolean not null default false,
  rounding_mode text not null default 'HALF_UP' check (rounding_mode in ('HALF_UP', 'UP', 'DOWN')),
  rounding_increment numeric(18, 2) not null default 0.01 check (rounding_increment > 0),
  company_name text not null default 'SERP',
  payment_methods text not null default '',
  updated_at timestamptz not null default now(),
  updated_by text,
  updated_device_name text,
  updated_device_identifier text
);

insert into public.app_settings (id) values (true);
alter table public.app_settings enable row level security;
create policy app_settings_local_access on public.app_settings for all to anon, authenticated using (true) with check (true);
grant select, insert, update on public.app_settings to anon, authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-images', 'product-images', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create policy product_images_public_read on storage.objects for select to anon, authenticated using (bucket_id = 'product-images');
create policy product_images_local_insert on storage.objects for insert to anon, authenticated with check (bucket_id = 'product-images');
create policy product_images_local_update on storage.objects for update to anon, authenticated using (bucket_id = 'product-images') with check (bucket_id = 'product-images');
create policy product_images_local_delete on storage.objects for delete to anon, authenticated using (bucket_id = 'product-images');
