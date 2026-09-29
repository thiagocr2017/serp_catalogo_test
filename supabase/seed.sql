insert into public.categories (id, name, created_by, created_device_name, created_device_identifier)
values
  ('10000000-0000-0000-0000-000000000001', 'Hogar', 'local-seed', 'Supabase Local', 'seed'),
  ('10000000-0000-0000-0000-000000000002', 'Cocina', 'local-seed', 'Supabase Local', 'seed'),
  ('10000000-0000-0000-0000-000000000003', 'Organización', 'local-seed', 'Supabase Local', 'seed');

insert into public.products (
  id, sku, name, description, category_id, unit_price, package_price,
  min_order_quantity, packaging_presentation_id, cbm_per_moq, factory_cost,
  reorder_point, created_by, created_device_name, created_device_identifier
)
values
  ('20000000-0000-0000-0000-000000000001', 'HJ300-1', 'Organizador modular',
   'Organizador plástico apilable.', '10000000-0000-0000-0000-000000000003',
   2.63, 31.56, 12,
   (select id from public.packaging_presentations where name = 'Caja'),
   0.045000, 1.20, 12, 'local-seed', 'Supabase Local', 'seed'),
  ('20000000-0000-0000-0000-000000000002', 'KT100-1', 'Set de utensilios',
   'Set básico de utensilios para cocina.', '10000000-0000-0000-0000-000000000002',
   8.50, 51.00, 6,
   (select id from public.packaging_presentations where name = 'Set'),
   0.032000, 4.10, 6, 'local-seed', 'Supabase Local', 'seed');

select public.create_and_confirm_inventory_document(
  '32000000-0000-0000-0000-000000000001', 'OPENING',
  jsonb_build_array(jsonb_build_object(
    'product_id', '20000000-0000-0000-0000-000000000001',
    'quantity', 48,
    'notes', 'Datos iniciales locales'
  )),
  null, null, '30000000-0000-0000-0000-000000000001', null,
  'SEED-HJ300-1', 'Apertura de inventario local',
  'local-seed', 'Supabase Local', 'seed'
);

select public.create_and_confirm_inventory_document(
  '32000000-0000-0000-0000-000000000002', 'OPENING',
  jsonb_build_array(jsonb_build_object(
    'product_id', '20000000-0000-0000-0000-000000000002',
    'quantity', 18,
    'notes', 'Datos iniciales locales'
  )),
  null, null, '30000000-0000-0000-0000-000000000001', null,
  'SEED-KT100-1', 'Apertura de inventario local',
  'local-seed', 'Supabase Local', 'seed'
);
