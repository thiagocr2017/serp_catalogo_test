begin;

select plan(6);

select ok(
  not has_function_privilege(
    'anon', 'public.claim_local_superadmin(text)'::regprocedure, 'EXECUTE'
  ),
  'anon no puede reclamar superadministrador usando identidad de dispositivo'
);
select ok(
  not has_function_privilege(
    'authenticated', 'public.claim_local_superadmin(text)'::regprocedure,
    'EXECUTE'
  ),
  'ninguna sesión cliente puede usar el bootstrap legado por dispositivo'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.purge_test_data_and_go_production(text,text)'::regprocedure,
    'EXECUTE'
  ),
  'anon no puede purgar datos ni cambiar a producción'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.purge_test_data_and_go_production(text,text)'::regprocedure,
    'EXECUTE'
  ),
  'la purga y producción siguen cerradas hasta el bootstrap Auth'
);
select ok(
  not exists (
    select 1
    from pg_proc p
    cross join lateral aclexplode(
      coalesce(p.proacl, acldefault('f', p.proowner))
    ) acl
    where p.oid = 'public.claim_local_superadmin(text)'::regprocedure
      and acl.grantee = 0
      and acl.privilege_type = 'EXECUTE'
  ),
  'PUBLIC no recibe EXECUTE sobre el bootstrap legado'
);
select ok(
  not exists (
    select 1
    from pg_proc p
    cross join lateral aclexplode(
      coalesce(p.proacl, acldefault('f', p.proowner))
    ) acl
    where p.oid =
      'public.purge_test_data_and_go_production(text,text)'::regprocedure
      and acl.grantee = 0
      and acl.privilege_type = 'EXECUTE'
  ),
  'PUBLIC no recibe EXECUTE sobre la purga y el cambio de entorno'
);

select * from finish();
rollback;
