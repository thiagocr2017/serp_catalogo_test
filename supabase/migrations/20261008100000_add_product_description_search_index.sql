create index if not exists products_description_trgm_idx
  on public.products using gin (description gin_trgm_ops);
