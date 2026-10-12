begin;

select plan(2);

select has_index(
  'public',
  'products',
  'products_description_trgm_idx',
  'descripción de productos tiene índice para búsqueda parcial'
);

select ok(
  (select indexdef like '%USING gin (description gin_trgm_ops)%'
   from pg_indexes
   where schemaname = 'public'
     and tablename = 'products'
     and indexname = 'products_description_trgm_idx'),
  'el índice de descripción usa trigramas GIN'
);

select * from finish();
rollback;
