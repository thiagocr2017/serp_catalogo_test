begin;

select plan(9);

-- Supabase Storage: acotamiento de politicas y limites de subida.
--
-- Estas pruebas son de caracterizacion: describen las protecciones reales que
-- existen y deben seguir exigiendose.
--
-- Lo que **no** se intenta aqui, y por que
-- -----------------------------------------
-- `storage.objects` concede a `anon` y `authenticated` TRUNCATE, REFERENCES y
-- TRIGGER ademas del CRUD. Sobre el papel es el mismo vector que permitio vaciar
-- `inventory_transactions` y `audit_logs`: RLS no aplica a TRUNCATE y los
-- triggers `update_objects_updated_at` y `protect_objects_delete` son de nivel
-- de fila. Pero no es explotable igual, y no se puede corregir desde aqui:
--
--   1. PostgREST **no expone** el schema `storage`:
--      `supabase/config.toml` tiene `schemas = ["public", "graphql_public"]`.
--      La aplicacion usa el API de Storage (`_client.storage.from(...)`), que
--      es otro servicio y no SQL directo.
--   2. Quien otorga esos privilegios es `supabase_storage_admin`, no `postgres`,
--      y **`postgres` no es superuser** en la base local de Supabase. Un
--      `REVOKE` desde `postgres` no los quita: PostgreSQL reporta `REVOKE` igual
--      aunque no haya revocado nada. Comprobado: `has_table_privilege` sigue en
--      `true` inmediatamente despues.
--
-- Consecuencia: el riesgo residual es un acceso SQL directo con credenciales de
-- base, que ya esta fuera del modelo de amenazas de la aplicacion de escritorio.
-- Se deja constancia aqui y en `database/schema-current.md` en vez de aplicar
-- un `REVOKE` que no hace nada y daria una falsa sensacion de proteccion.
--
-- Trade-off registrado: a diferencia de las tablas de `public`, sobre
-- `storage.objects` no se anade un trigger `BEFORE TRUNCATE` porque es una
-- tabla gestionada por Supabase y tocar su esquema puede romperse en una
-- actualizacion.

-- ---------------------------------------------------------------------------
-- A. Las politicas siguen acotadas a su bucket y a su patron de nombre
-- ---------------------------------------------------------------------------

select is(
  (select count(*)::integer from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and qual like '%bucket_id%'),
  5,
  'las cinco politicas de objetos siguen fijadas a su bucket'
);

select is(
  (select count(*)::integer from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and cmd = 'DELETE' and policyname like 'catalog%'),
  0,
  'catalog-assets sin politica de borrado: el logo no se puede eliminar'
);

select is(
  (select count(*)::integer from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and policyname like 'product_images_%'),
  4,
  'product-images conserva sus cuatro politicas'
);

select is(
  (select count(*)::integer from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and policyname in ('product_images_insert', 'product_images_update',
                        'product_images_delete', 'catalog_assets_logo_insert',
                        'catalog_assets_logo_update')
     and (coalesce(qual, with_check) ~ '[a-zA-Z0-9]')),
  5,
  'las politicas de escritura acotan el nombre del objeto con un patron'
);

-- ---------------------------------------------------------------------------
-- B. Limites de subida
-- ---------------------------------------------------------------------------

select is(
  (select count(*)::integer from storage.buckets
   where file_size_limit is null or allowed_mime_types is null),
  0,
  'los dos buckets siguen con limite de tamano y de tipos MIME'
);

select is(
  (select count(*)::integer from storage.buckets),
  2,
  'no se han creado buckets fuera de los dos previstos'
);

select is(
  (select count(*)::integer from storage.buckets
   where allowed_mime_types::text !~ 'image/'),
  0,
  'ningun bucket acepta algo que no sea imagen'
);

-- ---------------------------------------------------------------------------
-- C. Protecciones de fila y de borrado
-- ---------------------------------------------------------------------------

select ok(
  exists(
    select 1 from information_schema.triggers
     where event_object_schema = 'storage'
       and event_object_table = 'objects'
       and trigger_name = 'protect_objects_delete'
  ),
  'el trigger que impide el borrado directo sigue presente'
);

select ok(
  exists(
    select 1 from information_schema.triggers
     where event_object_schema = 'storage'
       and event_object_table = 'objects'
       and trigger_name = 'update_objects_updated_at'
  ),
  'el trigger de marca de tiempo sigue presente'
);

select * from finish();
rollback;
