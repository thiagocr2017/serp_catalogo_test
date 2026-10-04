begin;
select plan(27);

-- 1. Tablas y columnas
select has_table('public', 'countries', 'countries table exists');
select has_table('public', 'administrative_areas', 'administrative_areas table exists');
select has_table('public', 'cities', 'cities table exists');

select columns_are(
  'public', 'countries',
  array['code', 'name', 'is_active', 'created_at'],
  'countries has expected columns'
);

select columns_are(
  'public', 'administrative_areas',
  array['id', 'country_code', 'code', 'name', 'is_active', 'created_at'],
  'administrative_areas has expected columns'
);

select columns_are(
  'public', 'cities',
  array['id', 'country_code', 'administrative_area_id', 'province_name', 'name', 'is_active', 'created_at'],
  'cities has expected columns'
);

-- 2. Precarga básica
select is(
  (select count(*)::integer from public.countries where code = 'CR' and is_active),
  1,
  'Costa Rica is preloaded and active'
);

select is(
  (select count(*)::integer from public.administrative_areas where country_code = 'CR' and is_active),
  7,
  'All 7 provinces of Costa Rica are preloaded'
);

select ok(
  (select count(*)::integer from public.cities where country_code = 'CR') > 200,
  'Costa Rica INEC districts are preloaded'
);

select is(
  (select count(*)::integer from public.cities where country_code = 'CR' and province_name = 'San José' and name = 'Pavas'),
  1,
  'Pavas is preloaded in San José'
);

-- 3. customers tiene country_code y city
select has_column('public', 'customers', 'country_code', 'customers has country_code');
select has_column('public', 'customers', 'city', 'customers has city');

-- 4. Privilegios de anon / authenticated (solo SELECT)
set local role authenticated;

select is(
  (select count(*)::integer from public.countries where is_active),
  (select count(*)::integer from public.countries),
  'authenticated can select countries'
);

select is(
  (select count(*)::integer from public.administrative_areas where country_code = 'CR'),
  7,
  'authenticated can select administrative areas'
);

prepare direct_insert_country as
  insert into public.countries (code, name) values ('PA', 'Panamá');
select throws_matching(
  'direct_insert_country',
  'permission denied',
  'authenticated cannot insert directly into countries'
);

prepare direct_insert_city as
  insert into public.cities (country_code, province_name, name) values ('CR', 'San José', 'Distrito Falso');
select throws_matching(
  'direct_insert_city',
  'permission denied',
  'authenticated cannot insert directly into cities'
);

-- 5. Creacion de cliente con pais, provincia y ciudad precargada
set local role postgres;

select lives_ok(
  $$
    select public.create_customer(
      p_name := 'Cliente San José Test',
      p_display_name := 'San José Fantasia',
      p_phone := '50622223333',
      p_email := 'sanjose@test.cr',
      p_address := 'De la rotonda 100 norte',
      p_tax_id := '3101999888',
      p_credit_limit := 0,
      p_country_code := 'CR',
      p_province := 'San José',
      p_city := 'Pavas',
      p_gira := 'Ruta Central',
      p_preferred_carrier_id := null,
      p_customer_type := 'CASH',
      p_credit_days := null,
      p_document_preference := 'E_INVOICE',
      p_requires_e_invoice := false,
      p_identification_type_id := null,
      p_economic_activity := null,
      p_actor_name := 'test_actor',
      p_device_name := 'test_mac',
      p_device_identifier := 'mac-001'
    );
  $$,
  'create_customer works with country, province and preloaded city'
);

select is(
  (select city from public.customers where name = 'Cliente San José Test'),
  'Pavas',
  'customer persisted city Pavas'
);

select is(
  (select country_code from public.customers where name = 'Cliente San José Test'),
  'CR',
  'customer persisted country_code CR'
);

-- 6. Autoaprendizaje de ciudad no existente (Decisión 29)
select is(
  (select count(*)::integer from public.cities where country_code = 'CR' and lower(name) = lower('Valle Escondido')),
  0,
  'Valle Escondido does not exist yet in cities'
);

select lives_ok(
  $$
    select public.create_customer(
      p_name := 'Cliente Ciudad Nueva Test',
      p_display_name := 'Ciudad Nueva Fantasia',
      p_phone := '50688889999',
      p_email := 'nueva@test.cr',
      p_address := 'Frente al lago',
      p_tax_id := '3101777666',
      p_credit_limit := 0,
      p_country_code := 'CR',
      p_province := 'Alajuela',
      p_city := 'Valle Escondido',
      p_gira := 'Ruta Norte',
      p_preferred_carrier_id := null,
      p_customer_type := 'CASH',
      p_credit_days := null,
      p_document_preference := 'E_INVOICE',
      p_requires_e_invoice := false,
      p_identification_type_id := null,
      p_economic_activity := null,
      p_actor_name := 'test_actor',
      p_device_name := 'test_mac',
      p_device_identifier := 'mac-001'
    );
  $$,
  'create_customer auto-learns new city'
);

select is(
  (select count(*)::integer from public.cities where country_code = 'CR' and province_name = 'Alajuela' and name = 'Valle Escondido'),
  1,
  'Valle Escondido was auto-learned into cities table'
);

select is(
  (select city from public.customers where name = 'Cliente Ciudad Nueva Test'),
  'Valle Escondido',
  'customer persisted auto-learned city'
);

select public.update_customer(
  p_customer_id := (select id from public.customers where name = 'Cliente Ciudad Nueva Test'),
  p_name := 'Cliente Ciudad Nueva Test',
  p_display_name := 'Ciudad Nueva Fantasia',
  p_phone := '50688889999',
  p_email := 'nueva@test.cr',
  p_address := 'Frente al lago',
  p_tax_id := '3101777666',
  p_credit_limit := 0,
  p_country_code := 'CR',
  p_province := 'Alajuela',
  p_city := ' valle escondido ',
  p_gira := 'Ruta Norte',
  p_preferred_carrier_id := null,
  p_customer_type := 'CASH',
  p_credit_days := null,
  p_document_preference := 'E_INVOICE',
  p_requires_e_invoice := false,
  p_identification_type_id := null,
  p_economic_activity := null,
  p_actor_name := 'test_actor',
  p_device_name := 'test_mac',
  p_device_identifier := 'mac-001'
);

select is(
  (select count(*)::integer from public.cities where country_code = 'CR' and lower(btrim(province_name)) = 'alajuela' and lower(btrim(name)) = 'valle escondido'),
  1,
  'update de una ciudad existente con otro casing no duplica el catalogo'
);

select is(
  (select city from public.customers where name = 'Cliente Ciudad Nueva Test'),
  'valle escondido',
  'update normaliza espacios exteriores sin forzar casing'
);

-- 7. Rechazo por pais inactivo o invalido
select throws_matching(
  $$
    select public.create_customer(
      p_name := 'Cliente Pais Invalido',
      p_display_name := 'Pais Invalido Fantasia',
      p_phone := '50600000000',
      p_email := 'invalido@test.cr',
      p_address := 'Sin direccion',
      p_tax_id := '3101000000',
      p_credit_limit := 0,
      p_country_code := 'XX',
      p_province := 'Provincia X',
      p_city := 'Ciudad X',
      p_gira := 'Ruta Invalida',
      p_preferred_carrier_id := null,
      p_customer_type := 'CASH',
      p_credit_days := null,
      p_document_preference := 'E_INVOICE',
      p_requires_e_invoice := false,
      p_identification_type_id := null,
      p_economic_activity := null,
      p_actor_name := 'test_actor',
      p_device_name := 'test_mac',
      p_device_identifier := 'mac-001'
    );
  $$,
  'COUNTRY_INACTIVE_OR_INVALID',
  'create_customer rejects invalid or inactive country'
);

select is(
  (select count(*)::integer from public.cities where country_code = 'XX' and province_name = 'Provincia X' and name = 'Ciudad X'),
  0,
  'error por pais invalido no deja ciudad aprendida parcialmente'
);

select * from finish();
rollback;
