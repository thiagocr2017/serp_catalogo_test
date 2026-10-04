begin;

select plan(7);

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
select hasnt_view(
  'public',
  'catalog_agents',
  'la vista heredada catalog_agents ya no existe'
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
