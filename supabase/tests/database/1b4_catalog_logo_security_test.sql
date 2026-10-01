begin;

select plan(10);

select has_column(
  'public', 'app_settings', 'catalog_logo_object_name',
  'configuración conserva la referencia canónica del logo'
);
select ok(
  not has_table_privilege('anon', 'public.app_settings', 'INSERT,UPDATE,DELETE'),
  'anon no modifica app_settings directamente'
);
select ok(
  not has_table_privilege(
    'authenticated', 'public.app_settings', 'INSERT,UPDATE,DELETE'
  ),
  'authenticated no modifica app_settings directamente'
);
select ok(
  has_function_privilege(
    'anon',
    'public.register_catalog_logo_version(uuid,text,text,integer,text,text,text)'::regprocedure,
    'EXECUTE'
  ),
  'el cliente local puede registrar un logo versionado'
);
select ok(
  has_function_privilege(
    'anon', 'public.claim_local_superadmin(text)'::regprocedure, 'EXECUTE'
  ),
  'el puente local de superadministrador está disponible en desarrollo'
);

update public.app_settings set superadmin_device_identifier = null where id = true;
select ok(
  public.claim_local_superadmin('device-first'),
  'el primer equipo reclama la instalación sin autenticación'
);
select is(
  (select superadmin_device_identifier from public.app_settings where id = true),
  'device-first',
  'queda registrado el primer equipo'
);
select is(
  public.claim_local_superadmin('device-second'),
  null::boolean,
  'un segundo equipo no sustituye al superadministrador'
);
select is(
  (select superadmin_device_identifier from public.app_settings where id = true),
  'device-first',
  'la identidad provisional no puede sobrescribirse'
);
select ok(
  not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname in (
        'catalog_assets_local_insert',
        'catalog_assets_local_update',
        'catalog_assets_local_delete'
      )
  ),
  'las políticas amplias anteriores de Storage fueron eliminadas'
);

select * from finish();
rollback;
