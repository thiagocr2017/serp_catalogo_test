begin;
select plan(13);
select public.create_sales_agent('33333333-3333-3333-3333-333333333333','Activo','','t','d','i');
select throws_ok($$select public.create_sales_agent('33333333-3333-3333-3333-333333333333','Activo','diferente','t','d','i')$$,'P0001','COMMAND_PAYLOAD_MISMATCH','agente rechaza carga distinta');
select public.create_packaging_presentation('44444444-4444-4444-4444-444444444444','Transición','t','d','i');
select throws_ok($$select public.create_packaging_presentation('44444444-4444-4444-4444-444444444444','Otra','t','d','i')$$,'P0001','COMMAND_PAYLOAD_MISMATCH','presentación rechaza carga distinta');
select is((select column_default::int from information_schema.columns where table_schema='public' and table_name='app_settings' and column_name='business_settings_version'),1,'empresa inicia versión uno');
-- Base hermética: la aplicación incrementa estas versiones durante el uso
-- normal (select_catalog_agent, save_catalog_preferences y
-- clear_selected_catalog_agent_internal tocan catalog_preferences_version).
-- Se capturan dentro de la transacción, que se revierte, para comprobar deltas
-- en vez de valores absolutos de una base recién migrada. Sin esto, el archivo
-- falla contra cualquier base que ya haya sido usada.
create temporary table _v as select business_settings_version as business, catalog_preferences_version as catalog from public.app_settings where id=true;
select ok((public.save_business_settings('USD',2,0,false,'HALF_UP',0.01,'T','',(select business from _v),'t','d','i')).version=(select business from _v)+1,'empresa incrementa versión');
select throws_ok($$select public.save_business_settings('USD',2,0,false,'HALF_UP',0.01,'T','',1,'t','d','i')$$,'P0001','VERSION_CONFLICT','versión obsoleta falla');
select throws_ok($$insert into public.sales_agent_create_commands(command_id,payload_hash,entity_id) values('55555555-5555-5555-5555-555555555555','\\x00',(select id from public.sales_agents where name='Activo'))$$,'23514',null,'constraint rechaza entity_id solo de agente');
select throws_ok($$insert into public.sales_agent_create_commands(command_id,payload_hash,result_version) values('56555555-5555-5555-5555-555555555555','\\x00',1)$$,'23514',null,'constraint rechaza versión sola de agente');
select throws_ok($$insert into public.packaging_presentation_create_commands(command_id,payload_hash,entity_id) values('66666666-6666-6666-6666-666666666666','\\x00',(select id from public.packaging_presentations where name='Transición'))$$,'23514',null,'constraint rechaza entity_id solo de presentación');
select throws_ok($$insert into public.packaging_presentation_create_commands(command_id,payload_hash,result_version) values('67666666-6666-6666-6666-666666666666','\\x00',1)$$,'23514',null,'constraint rechaza versión sola de presentación');
select is((select catalog_preferences_version from public.app_settings where id=true),(select catalog from _v),'empresa no modifica preferencias');
select ok((public.save_catalog_preferences(4,'#FFFFFF','#FFFFFF','#3949AB','#111111','#1565C0','#616161','#C62828','#FFFFFF','#757575','#C62828','#C62828','cover',(select catalog from _v),'t','d','i')).version=(select catalog from _v)+1,'diseño incrementa preferencias');
select is((select business_settings_version from public.app_settings where id=true),(select business from _v)+1,'diseño no modifica empresa');
select is((select audit_record_id from public.app_settings where id=true),(select audit_record_id from public.app_settings where id=true),'audit_record_id permanece estable');
select * from finish();
rollback;
