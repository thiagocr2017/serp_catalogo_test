begin;
select plan(11);

select has_column(
  'public', 'packaging_presentations', 'units_per_presentation',
  'el catalogo de configuracion guarda el factor de unidades'
);
select has_column(
  'public', 'product_catalog', 'units_per_presentation',
  'la vista de producto publica el factor configurado'
);
select has_function(
  'public', 'create_packaging_presentation',
  array['uuid', 'text', 'integer', 'text', 'text', 'text']::name[],
  'crear presentacion requiere nombre y cantidad de unidades'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.create_packaging_presentation(uuid,text,integer,text,text,text)',
    'EXECUTE'
  ) and not has_function_privilege(
    'authenticated',
    'public.create_packaging_presentation(uuid,text,text,text,text)',
    'EXECUTE'
  ),
  'solo se permite crear presentacion mediante RPC con factor'
);
select has_function(
  'public', 'update_packaging_presentation',
  array['uuid', 'text', 'integer', 'integer', 'text', 'text', 'text']::name[],
  'editar presentacion permite cambiar factor con version esperada'
);
select is(
  (public.create_packaging_presentation(
    '71000000-0000-4000-8000-000000000001', 'Caja pgTAP', 6,
    'pgTAP', 'device', 'device-id'
  )).name,
  'Caja pgTAP',
  'crea presentacion de caja'
);
select is(
  (select units_per_presentation from public.packaging_presentations
   where name = 'Caja pgTAP'),
  6,
  'persiste seis unidades por caja'
);
select is(
  (public.update_packaging_presentation(
    (select id from public.packaging_presentations where name = 'Caja pgTAP'),
    'Caja de 12 unidades', 12, 1, 'pgTAP', 'device', 'device-id'
  )).name,
  'Caja de 12 unidades',
  'actualiza nombre y devuelve el resultado compuesto correctamente'
);
select is(
  (select units_per_presentation from public.packaging_presentations
   where name = 'Caja de 12 unidades'),
  12,
  'edicion persiste el factor que coincide con el nombre'
);
select is(
  (select version from public.packaging_presentations
   where name = 'Caja de 12 unidades'),
  2,
  'edicion incrementa la version una vez'
);
select throws_ok(
  $$select public.update_packaging_presentation(
    (select id from public.packaging_presentations where name = 'Caja de 12 unidades'),
    'Caja de 12 unidades', 12, 1, 'pgTAP', 'device', 'device-id'
  )$$,
  'P0001', 'VERSION_CONFLICT', 'edicion obsoleta no sobrescribe el factor'
);

select * from finish();
rollback;
