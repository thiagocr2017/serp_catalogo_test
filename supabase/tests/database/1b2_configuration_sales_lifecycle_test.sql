begin;

select plan(13);

create temp table _settings_before as
select audit_record_id, catalog_preferences_version
from public.app_settings
where id = true;

insert into public.sales_agent_create_commands(command_id, payload_hash)
values (
  '71000000-0000-0000-0000-000000000001',
  extensions.digest(
    convert_to(
      jsonb_build_object(
        'operation', 'create_sales_agent',
        'name', 'Agente incompleto',
        'phone', ''
      )::text,
      'UTF8'
    ),
    'sha256'
  )
);

select throws_ok(
  $$select public.create_sales_agent(
    '71000000-0000-0000-0000-000000000001',
    'Agente incompleto', '', 'test', 'pgTAP', 'lifecycle'
  )$$,
  'P0001',
  'COMMAND_INCOMPLETE',
  'un recibo reservado de agente no se interpreta como comando terminado'
);

insert into public.packaging_presentation_create_commands(command_id, payload_hash)
values (
  '72000000-0000-0000-0000-000000000001',
  extensions.digest(
    convert_to(
      jsonb_build_object(
        'operation', 'create_packaging_presentation',
        'name', 'Presentación incompleta'
      )::text,
      'UTF8'
    ),
    'sha256'
  )
);

select throws_ok(
  $$select public.create_packaging_presentation(
    '72000000-0000-0000-0000-000000000001',
    'Presentación incompleta', 'test', 'pgTAP', 'lifecycle'
  )$$,
  'P0001',
  'COMMAND_INCOMPLETE',
  'un recibo reservado de presentación no se interpreta como comando terminado'
);

create temp table _selected_agent as
select (result).*
from (
  select public.create_sales_agent(
    '73000000-0000-0000-0000-000000000001',
    'Agente seleccionado', '7000-0001', 'test', 'pgTAP', 'lifecycle'
  ) as result
) created;

update _selected_agent
set name = (public.update_sales_agent(
  id, 'Agente seleccionado actualizado', phone, version,
  'test', 'pgTAP', 'lifecycle'
)).name,
version = version + 1;

select is(
  (select version from public.sales_agents where id = (select id from _selected_agent)),
  2,
  'editar un agente incrementa exactamente una versión'
);

select public.select_catalog_agent(
  (select id from _selected_agent),
  (select catalog_preferences_version from public.app_settings where id = true),
  'test', 'pgTAP', 'lifecycle'
);

create temp table _selected_state as
select catalog_preferences_version
from public.app_settings
where id = true;

select public.deactivate_sales_agent(
  (select id from _selected_agent),
  (select version from public.sales_agents where id = (select id from _selected_agent)),
  'test', 'pgTAP', 'lifecycle'
);

select is(
  (select selected_catalog_agent_id from public.app_settings where id = true),
  null::uuid,
  'desactivar el agente seleccionado limpia la selección'
);

select is(
  (select catalog_preferences_version from public.app_settings where id = true),
  (select catalog_preferences_version + 1 from _selected_state),
  'limpiar el agente seleccionado incrementa preferencias una sola vez'
);

select is(
  (
    select count(*)
    from public.audit_actions
    where module = 'sales'
      and entity_type = 'sales_agents'
      and entity_id = (select id from _selected_agent)
      and operation = 'DEACTIVATE'
  ),
  1::bigint,
  'la desactivación produce una sola cabecera de auditoría'
);

select is(
  (
    select count(*)
    from public.audit_logs logs
    join public.audit_actions actions on actions.id = logs.action_id
    where actions.module = 'sales'
      and actions.entity_id = (select id from _selected_agent)
      and actions.operation = 'DEACTIVATE'
      and logs.table_name in ('sales_agents', 'app_settings')
  ),
  2::bigint,
  'la desactivación y la limpieza comparten una acción con dos detalles'
);

select throws_ok(
  format(
    'select public.select_catalog_agent(%L, %s, %L, %L, %L)',
    (select id from _selected_agent),
    (select catalog_preferences_version from public.app_settings where id = true),
    'test', 'pgTAP', 'lifecycle'
  ),
  'P0001',
  'AGENT_INACTIVE',
  'un agente inactivo no puede seleccionarse para el catálogo'
);

select is(
  (public.activate_sales_agent(
    (select id from _selected_agent),
    (select version from public.sales_agents where id = (select id from _selected_agent)),
    'test', 'pgTAP', 'lifecycle'
  )).version,
  4,
  'reactivar un agente incrementa exactamente una versión'
);

create temp table _other_agent as
select (result).*
from (
  select public.create_sales_agent(
    '74000000-0000-0000-0000-000000000001',
    'Agente no seleccionado', '7000-0002', 'test', 'pgTAP', 'lifecycle'
  ) as result
) created;

create temp table _preferences_before_other_deactivation as
select catalog_preferences_version
from public.app_settings
where id = true;

select public.deactivate_sales_agent(
  (select id from _other_agent),
  (select version from _other_agent),
  'test', 'pgTAP', 'lifecycle'
);

select is(
  (select catalog_preferences_version from public.app_settings where id = true),
  (select catalog_preferences_version from _preferences_before_other_deactivation),
  'desactivar un agente no seleccionado no modifica preferencias'
);

select is(
  (select audit_record_id from public.app_settings where id = true),
  (select audit_record_id from _settings_before),
  'audit_record_id permanece estable después de cambios reales'
);

select hasnt_view(
  'public',
  'catalog_agents',
  'la vista heredada catalog_agents ya no existe'
);

select ok(
  not exists (
    select 1
    from pg_type result_type
    join pg_namespace namespace on namespace.oid = result_type.typnamespace
    join pg_attribute attribute on attribute.attrelid = result_type.typrelid
    where namespace.nspname = 'public'
      and result_type.typname in (
        'business_settings_rpc_result',
        'catalog_preferences_rpc_result',
        'catalog_logo_rpc_result',
        'packaging_presentation_rpc_result',
        'sales_agent_rpc_result'
      )
      and attribute.attnum > 0
      and not attribute.attisdropped
      and attribute.attname in (
        'app_mode', 'superadmin_device_identifier', 'created_by',
        'updated_by', 'created_device_identifier', 'updated_device_identifier'
      )
  ),
  'los DTO de retorno no filtran campos administrativos'
);

select * from finish();
rollback;
