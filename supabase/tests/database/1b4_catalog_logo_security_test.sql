begin;

select plan(5);

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
