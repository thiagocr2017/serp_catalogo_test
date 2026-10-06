# Puerta obligatoria de Autenticación antes de producción

La aplicación está migrando del acceso de negocio sin sesión y de la identidad
por dispositivo a Supabase Auth. El modelo aprobado aprovisiona cuentas sin
registro abierto ni inicio anónimo; la configuración local todavía permite
signup y debe cerrarse al migrar el setup E2E a aprovisionamiento controlado.
En la primera fase, todos los usuarios autenticados comparten los permisos
comerciales. La única distinción de instalación es el
superadministrador inicial, creado desde Supabase Auth y vinculado por
`auth.uid()`; no se reutiliza identidad de dispositivo. La purga y el cambio a
`PRODUCTION` quedan bloqueados en UI y RPC hasta completar y probar ese
bootstrap.

Avance local: el reclamo heredado por dispositivo y la purga/transición están
revocados para roles cliente, y la UI permanece bloqueada. Esto no equivale a
haber implementado el inicio de sesión ni a haber retirado todos los accesos
de negocio de `anon`.

La auditoría del 2026-10-06 encontró que el alcance actual no es mínimo: 48
objetos con `SELECT`, 53 políticas que mencionan `anon`/`public` y 84 funciones
`SECURITY DEFINER` ejecutables por `anon` en la base local auditada. Ver
`.specs/refactors/05-anonymous-access-removal.md` para evidencia, límites y
plan de retiro gradual. Estos conteos deben verificarse por entorno.

Este modelo es **provisional y no está autorizado para producción**.

Antes de distribuir una versión de producción, el módulo de Autenticación debe:

1. provisionar cuentas desde Supabase Auth; auto-registro y sign-in anónimo
   deben permanecer desactivados;
2. implementar y probar el bootstrap atómico del primer superadministrador
   autenticado, con `auth.uid()` y sin identidad de dispositivo;
3. bloquear purga y cambio a `PRODUCTION` tanto en interfaz como en RPC hasta
   completar el bootstrap;
4. retirar permisos de negocio de `anon` y `PUBLIC`, conservando las RPC de
   negocio para sesiones Auth no anónimas;
5. reemplazar actor/autorización basados en dispositivo por `auth.uid()` y
   conservar metadatos de equipo solo como trazabilidad;
6. migrar toda consulta, RPC, Storage y prueba para requerir una sesión Auth
   válida; mantener iguales los permisos comerciales entre usuarios;
7. probar lecturas y operaciones comerciales autenticadas, rechazo de `anon` y
   Auth anónimo, y rechazo de purga/producción por usuario no administrador;
8. afirmar con pgTAP que no quedan privilegios/grants de negocio efectivos para
   `anon` o `PUBLIC`;
9. impedir el cambio a modo `PRODUCTION` mientras esta puerta no esté cumplida.

Las migraciones de desarrollo que crean permisos provisionales deben incluir
pruebas exactas de alcance para evitar que los permisos se amplíen por accidente.
No revocar el rol SQL interno de Supabase; revocar sus permisos efectivos de
negocio después de migrar la app y las pruebas. La advertencia de RLS desactivado en
`identification_type_create_commands` debe resolverse con una migración y pgTAP;
la auditoría encontró ACL directas revocadas para `anon`, por lo que no debe
describirse como lectura/escritura directa confirmada.
