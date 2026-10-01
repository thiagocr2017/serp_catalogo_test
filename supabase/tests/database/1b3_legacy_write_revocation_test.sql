begin;

select plan(8);

select ok(
  has_table_privilege('anon', 'public.sales_agents', 'SELECT'),
  'anon conserva lectura de agentes'
);
select ok(
  not has_table_privilege('anon', 'public.sales_agents', 'INSERT,UPDATE,DELETE'),
  'anon no escribe agentes directamente'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.sales_agents',
    'INSERT,UPDATE,DELETE'
  ),
  'authenticated no escribe agentes directamente'
);
select ok(
  not has_table_privilege(
    'anon',
    'public.catalog_agents',
    'INSERT,UPDATE,DELETE'
  ),
  'la vista heredada tampoco admite escritura de anon'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.catalog_agents',
    'INSERT,UPDATE,DELETE'
  ),
  'la vista heredada tampoco admite escritura autenticada'
);
select ok(
  has_table_privilege('authenticated', 'public.packaging_presentations', 'SELECT'),
  'authenticated conserva lectura de presentaciones'
);
select ok(
  not has_table_privilege(
    'anon',
    'public.packaging_presentations',
    'INSERT,UPDATE,DELETE'
  ),
  'anon no escribe presentaciones directamente'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.packaging_presentations',
    'INSERT,UPDATE,DELETE'
  ),
  'authenticated no escribe presentaciones directamente'
);

select * from finish();
rollback;
