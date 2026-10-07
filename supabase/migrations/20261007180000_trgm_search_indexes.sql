-- Migration: trgm_search_indexes
-- Optimización de búsquedas usando trigramas para PostgreSQL

create extension if not exists pg_trgm;

create index if not exists products_sku_trgm_idx on public.products using gin (sku gin_trgm_ops);
create index if not exists products_name_trgm_idx on public.products using gin (name gin_trgm_ops);
create index if not exists products_barcode_idx on public.products (barcode) where barcode is not null;

create index if not exists customers_name_trgm_idx on public.customers using gin (name gin_trgm_ops);
create index if not exists customers_tax_id_idx on public.customers (tax_id);
create index if not exists customers_phone_idx on public.customers (phone);
