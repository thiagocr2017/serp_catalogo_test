begin;
select plan(5);

insert into public.categories (id, name, catalog_sort_order)
values
  ('10000000-0000-0000-0000-000000000001', 'Orden Cat A', 0),
  ('10000000-0000-0000-0000-000000000002', 'Orden Cat B', 1);

insert into public.products (
  id, sku, name, category_id, unit_price, packaging_presentation_id,
  catalog_sort_order
)
select ids.id, ids.sku, ids.name, ids.category_id, 1,
       (select id from public.packaging_presentations limit 1), 0
from (values
  ('20000000-0000-0000-0000-000000000001'::uuid, 'ORDER-A1', 'Orden A1', '10000000-0000-0000-0000-000000000001'::uuid),
  ('20000000-0000-0000-0000-000000000002'::uuid, 'ORDER-A2', 'Orden A2', '10000000-0000-0000-0000-000000000001'::uuid),
  ('20000000-0000-0000-0000-000000000003'::uuid, 'ORDER-B1', 'Orden B1', '10000000-0000-0000-0000-000000000002'::uuid)
) as ids(id, sku, name, category_id);

select public.save_catalog_order(
  array[
    '20000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000003'::uuid
  ],
  array[
    '10000000-0000-0000-0000-000000000002'::uuid,
    '10000000-0000-0000-0000-000000000001'::uuid
  ],
  'pgTAP', 'device', 'device-id'
);

select is(
  (select catalog_sort_order from public.categories where name = 'Orden Cat B'),
  0,
  'persiste el primer orden de categoría'
);
select is(
  (select catalog_sort_order from public.categories where name = 'Orden Cat A'),
  1,
  'persiste el segundo orden de categoría'
);
select is(
  (select catalog_sort_order from public.products where sku = 'ORDER-A2'),
  0,
  'primera posición independiente dentro de categoría A'
);
select is(
  (select catalog_sort_order from public.products where sku = 'ORDER-A1'),
  1,
  'segunda posición independiente dentro de categoría A'
);
select is(
  (select catalog_sort_order from public.products where sku = 'ORDER-B1'),
  0,
  'posición de categoría B empieza nuevamente en cero'
);

select * from finish();
rollback;
