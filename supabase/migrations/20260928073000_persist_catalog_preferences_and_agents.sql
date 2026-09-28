create table public.catalog_agents (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  phone text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  created_by text,
  updated_by text,
  created_device_name text,
  created_device_identifier text,
  updated_device_name text,
  updated_device_identifier text
);

alter table public.catalog_agents enable row level security;
create policy catalog_agents_local_access on public.catalog_agents
  for all to anon, authenticated using (true) with check (true);
grant select, insert, update on public.catalog_agents to anon, authenticated;

alter table public.app_settings
  add column catalog_cards_per_page integer not null default 4
    check (catalog_cards_per_page in (0, 1, 2, 4, 6)),
  add column catalog_background_color text not null default '#FFFFFF',
  add column catalog_card_color text not null default '#FFFFFF',
  add column catalog_design_accent_color text not null default '#3949AB',
  add column catalog_text_color text not null default '#111111',
  add column catalog_highlight_text_color text not null default '#1565C0',
  add column catalog_secondary_text_color text not null default '#616161',
  add column catalog_promotion_color text not null default '#C62828',
  add column catalog_promotion_text_color text not null default '#FFFFFF',
  add column catalog_promotion_previous_price_color text not null default '#757575',
  add column catalog_promotion_price_color text not null default '#C62828',
  add column catalog_promotion_description_color text not null default '#C62828',
  add column catalog_image_fit text not null default 'cover'
    check (catalog_image_fit in ('cover', 'contain', 'fitWidth')),
  add column catalog_logo_url text,
  add column selected_catalog_agent_id uuid references public.catalog_agents(id);

insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
) values (
  'catalog-assets', 'catalog-assets', true, 5242880,
  array['image/jpeg', 'image/png', 'image/webp']
) on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy catalog_assets_public_read on storage.objects
  for select to anon, authenticated using (bucket_id = 'catalog-assets');
create policy catalog_assets_local_insert on storage.objects
  for insert to anon, authenticated with check (bucket_id = 'catalog-assets');
create policy catalog_assets_local_update on storage.objects
  for update to anon, authenticated using (bucket_id = 'catalog-assets')
  with check (bucket_id = 'catalog-assets');
create policy catalog_assets_local_delete on storage.objects
  for delete to anon, authenticated using (bucket_id = 'catalog-assets');
