# 05 - Retiro del acceso anonimo de la aplicacion

## Clasificacion

- Estado: en progreso; la migracion de identidad bloquea produccion.
- Prioridad: P0 para cualquier entorno accesible fuera de un equipo local
  controlado.
- Etiquetas: `seguridad`, `autenticacion`, `autorizacion`, `anon`, `supabase`,
  `base-de-datos`, `e2e`, `puerta-produccion`, `fase-1-identidad`.
- Tipo: refactorizacion transversal. No ejecutar como una revocacion global
  aislada: la aplicacion y varias pruebas actuales dependen del rol `anon`.
- Auditoria documentada: 2026-10-06.

## Objetivo

Retirar el acceso de negocio de `anon` en toda la aplicacion sin abrir una
ventana de bloqueo ni dejar rutas de escritura sin autorizacion. Todas las
lecturas y operaciones comerciales deben ocurrir bajo una sesion de usuario
autenticada. En la fase inicial, las cuentas provisionadas comparten el mismo
alcance para operaciones comerciales; el superadministrador inicial conserva
solo las operaciones de instalacion necesarias y su identidad debe estar ligada
a Supabase Auth, nunca a un identificador declarado por el cliente.

Una sesion de inicio anonimo de Supabase no satisface este objetivo: aunque
obtenga el rol SQL `authenticated`, no demuestra la identidad de una persona.

## Decisiones aprobadas

Fecha: 2026-10-06. Aprobadas por el usuario.

- La aplicacion pasara a autenticar usuarios reales con Supabase Auth. El inicio
  anonimo de Auth no cuenta como identidad valida.
- No se permite registro abierto. El aprovisionamiento de usuarios se realiza
  fuera del cliente publico de la app mediante Supabase Auth; cualquier flujo
  administrativo interno para crear usuarios se definira despues.
- La primera cuenta de superadministrador se crea desde cero en Supabase Auth
  y se vincula una sola vez a la instalacion mediante `auth.uid()`. No se migra
  ni reutiliza la identidad de ningun dispositivo.
- Los usuarios provisionados comparten el mismo alcance para operaciones de
  negocio durante esta fase; no se implementan roles de ventas/inventario ni
  permisos por usuario. La designacion unica de superadministrador se reserva
  para bootstrap y operaciones de instalacion, no para limitar CRUD comercial.
- `DeviceIdentity` no autentica ni autoriza. Puede conservarse temporalmente
  solo como metadato de trazabilidad, sin influir en grants, decisiones de
  acceso, bootstrap ni auditoria de identidad; el actor de usuario sera
  `auth.uid()`.
- El rol SQL `anon` es parte interna de Supabase/PostgREST y no se elimina del
  servidor. El objetivo es retirar su acceso a datos/RPC de negocio y evitar
  que la app opere con ese rol. La publishable key sigue siendo necesaria como
  clave publica del cliente; no es una identidad ni un secreto.
- El cambio destructivo de modo y la purga permanecen bloqueados hasta que el
  bootstrap nuevo y las comprobaciones negativas/positivas esten implementados
  y probados.

Este alcance es una transicion intermedia: identidad de persona primero,
permisos de negocio iguales para las cuentas provisionadas y autorizacion
diferenciada para operaciones de instalacion; una matriz granular queda para
una fase posterior. Este modelo no proporciona aislamiento multiempresa.

## Hallazgos de linea base

Los hallazgos siguientes corresponden a la auditoria inicial, antes de aplicar
la migracion de bloqueo descrita en "Avance aplicado".

La auditoria de la base local conectada encontro:

1. 48 tablas/vistas del esquema `public` con privilegio efectivo de `SELECT`
   para `anon`.
2. 53 politicas RLS que mencionan `anon` o `public`. Una politica permisiva no
   concede por si sola privilegios SQL, pero permite acceso si el rol tambien
   tiene el `GRANT` correspondiente.
3. 84 funciones `SECURITY DEFINER` ejecutables por `anon`. La etiqueta
   `SECURITY DEFINER` no es por si misma una vulnerabilidad; el riesgo depende
   de la operacion, validacion de identidad, permisos, argumentos y grants.
4. No se observaron privilegios directos `INSERT`, `UPDATE` o `DELETE` de
   `anon` en las tablas publicas auditadas. Esto no elimina la capacidad de
   escritura indirecta que ofrecen RPCs `SECURITY DEFINER`.
5. `app_settings` permite `SELECT` a `anon`; la informacion incluye el
   identificador configurado para reclamar el superadministrador local.
6. `claim_local_superadmin(text)` puede ejecutarse como `anon` y reclama la
   instalacion si aun no hay identificador, comparando un valor que provee el
   cliente. No autentica que ese valor pertenezca al dispositivo.
7. `purge_test_data_and_go_production(text,text)` puede ejecutarse como
   `anon`. Es una operacion destructiva que borra datos de prueba y cambia el
   modo de la instalacion; su control actual depende del modo y del identificador
   del dispositivo que el propio modelo expone a la app.
8. RPCs comerciales, incluida la creacion de clientes, tambien son ejecutables
   por `anon`. La RPC atomica de devolucion revisada requiere `authenticated`,
   lo que explica el rechazo de la E2E cuando la app no establece una sesion.
9. `public.identification_type_create_commands` tiene RLS desactivado. Sin
   embargo, la auditoria de ACL no encontro privilegios directos de lectura o
   escritura para `anon`; sus RPCs de administracion si son ejecutables por
   `anon`. Por tanto, el aviso de RLS debe corregirse, pero no se debe describir
   como una tabla directamente legible/escribible por `anon` sin demostrar un
   `GRANT` efectivo.

## Avance aplicado

En la base local de prueba se aplico `20261006180000_block_legacy_device_bootstrap.sql`:

- La configuracion de la app ya no reclama automaticamente el superadministrador
  ni deriva `isSuperAdmin` del identificador del equipo.
- La RPC legacy `claim_local_superadmin(text)` permanece definida para poder
  retirarla aditivamente, pero `PUBLIC`, `anon` y `authenticated` ya no tienen
  `EXECUTE`.
- `purge_test_data_and_go_production(text,text)` tambien quedo revocada para
  esos roles. La UI no ofrece el boton y el repositorio rechaza localmente la
  operacion; no se purgaron datos ni se cambio el modo.
- pgTAP completo: 449 aserciones en 22 archivos, todas aprobadas. Las pruebas
  Flutter del modulo Configuracion (18) y `flutter analyze` tambien pasaron.
- El aprovisionamiento Auth todavia no esta implementado y
  `supabase/config.toml` aun permite signup en el entorno local. No afirmar que
  el registro abierto ya esta desactivado; cerrarlo despues de migrar fixtures
  y E2E a aprovisionamiento controlado.

La migracion fue aplicada fuera de orden con `--include-all` porque una
migracion con fecha posterior ya estaba registrada en la base local. El mismo
detalle debe considerarse al desplegar la migracion en otros entornos.

Los conteos anteriores describen la base local auditada en esa fecha; no son
un inventario universal ni garantizan que un proyecto remoto tenga el mismo
estado. Deben repetirse contra cada entorno antes de desplegar una migracion.
El modo local observado fue `TEST`; el equipo local ya habia sido reclamado por
la funcion prevista. No se guardan aqui identificadores del equipo ni secretos.

## Evidencia que debe conservarse

- Grants y politicas iniciales: `supabase/migrations/20260927161937_add_settings_and_product_images.sql`.
- Reclamacion y permisos de `claim_local_superadmin`:
  `supabase/migrations/20260929122000_secure_catalog_logo_and_settings.sql`.
- Borrado de datos y transicion de modo:
  `supabase/migrations/20260928062000_add_app_mode_catalog_order_and_image_scale.sql`
  y sus reemplazos posteriores.
- Tabla de comandos sin RLS y grants de RPC:
  `supabase/migrations/20261004140000_identification_types_admin.sql`.
- Contrato de pruebas existente:
  `supabase/tests/database/identification_types_admin_test.sql`.
- Puerta previa de produccion:
  `supabase/migrations/20261003110000_harden_audit_trail.sql` y
  `.specs/modules/authorization/production-gate.md`.

Antes de implementar, volver a consultar `information_schema`,
`pg_catalog`, `pg_policies` y ACL efectivos. Distinguir siempre:

- privilegios directos de tabla/secuencia;
- politicas RLS y roles a los que aplican;
- `EXECUTE` de funciones, incluyendo grants heredados a `PUBLIC`;
- privilegios del propietario y el comportamiento de `SECURITY DEFINER`;
- politicas de Storage y acceso a objetos;
- datos realmente devueltos por cada RPC o consulta.

## Plan futuro

### Fase 0 - Inventario y linea base

- [ ] Exportar un inventario reproducible de tablas, vistas, secuencias,
  politicas RLS, funciones, grants a `PUBLIC`/`anon`/`authenticated` y politicas
  de Storage.
- [ ] Clasificar cada operacion por lectura, escritura indirecta, sensibilidad,
  dueño del permiso y modulo consumidor.
- [ ] Repetir el inventario local y en cada entorno remoto sin ejecutar
  operaciones destructivas.
- [ ] Guardar pruebas de regresion de la linea base y confirmar que los datos
  y respaldos de cada entorno estan identificados.

### Fase 1 - Identidad y provision

- [ ] Deshabilitar auto-registro y sign-in anonimo en la configuracion Auth.
- [ ] Definir provisionamiento de cuentas desde Supabase Auth y recuperacion de
  acceso sin endpoints publicos de registro en el cliente.
- [ ] Implementar el proveedor de sesion y estados de carga, cierre y expiracion
  en la app.
- [ ] Añadir inicio/cierre de sesion y guardas de rutas; no cargar datos de
  negocio sin una sesion Auth no anonima.
- [ ] Implementar bootstrap atomico de la primera cuenta superadministradora,
  permitido solo a usuario autenticado y ligado a `auth.uid()`.
- [ ] Cubrir bootstrap simultaneo, segundo reclamo, usuario no autenticado y
  usuario Auth anonimo con pgTAP/concurrencia.
- [ ] Mantener bloqueados en UI y RPC la purga y el cambio a `PRODUCTION` hasta
  pasar el bootstrap y su verificacion end-to-end.

### Fase 2 - Autorizacion de base de datos

- [ ] Sustituir la reclamacion basada en argumento de dispositivo por un flujo
  autenticado, de provision controlada y con prueba de primer reclamo concurrente.
- [ ] Restringir `purge_test_data_and_go_production` a una identidad autorizada;
  mantener guardas de modo, auditoria y confirmacion explicita de operacion
  destructiva.
- [ ] Para cada RPC, documentar su invocador esperado y conceder `EXECUTE`
  explicitamente. Revocar `PUBLIC` y `anon` donde no sean necesarios.
- [ ] Para cada lectura, definir RLS de minimo privilegio y verificar que una
  sesion no pueda leer datos fuera de su alcance.
- [ ] Habilitar RLS en `identification_type_create_commands`; mantener sin
  politicas de acceso directo si solo la RPC propietaria debe usarla, salvo que
  un contrato justifique una politica distinta.
- [ ] Mantener `SECURITY DEFINER` solo cuando sea necesario, con propietario,
  `search_path` seguro, validacion de argumentos y grants revisados.
- [ ] Registrar actor con `auth.uid()`; conservar datos del dispositivo solo
  como metadatos de trazabilidad no autenticadores.

### Fase 3 - Migracion de consumidores y pruebas

- [ ] Migrar consultas y comandos de Flutter para requerir sesion valida y
  presentar un estado recuperable cuando expire.
- [ ] Migrar E2E a cuentas Auth provisionadas por fixtures locales; prohibir
  auto-registro y sign-in anonimo en setup y pruebas.
- [ ] PgTAP: afirmar que `anon` no tiene `SELECT`/DML ni `EXECUTE` no autorizado;
  afirmar que el usuario permitido puede operar y el usuario sin permiso no.
- [ ] Cubrir intento de leer datos ajenos, reclamacion concurrente, ejecucion
  repetida, expiracion de sesion y llamada a operacion destructiva desde una
  identidad no autorizada.
- [ ] Buscar `to anon`, `to public`, `grant execute`, `SECURITY DEFINER`,
  invocaciones RPC y politicas de Storage en todas las migraciones, fixtures,
  tests y codigo cliente; cada coincidencia debe quedar permitida con razon o
  eliminada.

### Fase 4 - Retiro gradual y gate de produccion

- [ ] Aplicar primero en una base desechable/restaurable; ejecutar pgTAP,
  pruebas Flutter y todos los flujos E2E afectados.
- [ ] Desplegar en un entorno de prueba con cuentas verificadas y comprobar
  lecturas, comandos, auditoria y operacion offline/sin sesion.
- [ ] Revocar el acceso `anon` en migraciones aditivas y solo cuando todos los
  consumidores de la operacion ya usen el nuevo contrato.
- [ ] Repetir el inventario y comparar con la linea base; cualquier permiso
  residual debe tener excepcion documentada y responsable.
- [ ] Mantener bloqueado el modo `PRODUCTION` hasta satisfacer todos los
  criterios binarios de `.specs/modules/authorization/production-gate.md`.

## Guia de relevo y ejecucion segura

Esta seccion es el punto de entrada para el siguiente agente. Leer primero los
documentos listados aqui; no inferir que los permisos o el estado del esquema
siguen iguales a la ultima corrida.

### Estado inicial verificado

- Commit de E2E de devolucion autenticada: `d2a83fd`.
- Commit que bloquea el bootstrap por dispositivo y la purga: `94cdf44`.
- La migracion `20261006180000_block_legacy_device_bootstrap.sql` ya se aplico
  a Supabase local mediante `--include-all`; no se aplico a un proyecto remoto.
- Ultima regresion registrada: 449 pruebas pgTAP en 22 archivos, 18 pruebas del
  modulo Configuracion, `flutter analyze` limpio.
- `supabase/config.toml` aun tiene signup de Auth habilitado en `[auth]` y
  `[auth.email]`. No apagarlo hasta reemplazar la cuenta creada por `signUp` en
  `integration_test/sales_return_authorized_lifecycle_flow_test.dart` por una
  fixture aprovisionada de forma controlada.
- No existe pantalla/proveedor de sesion Auth en `lib/`; `app_router.dart`
  inicia directamente en `/products`. `main.dart` crea `DeviceIdentity` y la
  inyecta en varios modulos. Las funciones de negocio y los grants de `anon`
  siguen pendientes de migracion.
- La base local contiene historial E2E y usuarios Auth sinteticos. No usar
  `supabase db reset`, purga, ni limpieza manual para “dejarla limpia”.
- El commit actual solo tiene `Signed-off-by`; no es criptograficamente firmado.
  Revisar la politica de `AGENTS.md` y no afirmar firma GPG/SSH sin
  `git verify-commit` exitoso.
- En esta maquina no hay `gpg` ni `user.signingkey` configurados; no cambiar la
  configuracion global ni reutilizar una clave SSH sin autorizacion del usuario.

### Fuentes de informacion por tema

| Tema | Revisar primero |
|---|---|
| Decisiones y secuencia | Este archivo, especialmente `Decisiones aprobadas`, `Avance aplicado` y esta guia |
| Gate de produccion | `.specs/modules/authorization/production-gate.md` |
| Auth existente/placeholder | `.specs/modules/authorization/1.one-time-pin-approval.spec.md`; es borrador PIN, no implementacion de login |
| Composicion y rutas | `lib/main.dart`, `lib/core/navigation/app_router.dart`, `lib/modules/*/*_module.dart` |
| Configuracion Auth local | `supabase/config.toml`, secciones `[auth]` y `[auth.email]` |
| Identidad por dispositivo | `lib/core/device/device_identity.dart`, `lib/core/identity/identity_context.dart`, busqueda `DeviceIdentity` y `device_identifier` |
| Autor/auditoria SQL | Migraciones con `p_actor_name`, `p_device_identifier`, `actor_name`, `created_by`, `updated_by`; `core/audit/` |
| Modelo de seguridad | Todas las migraciones en `supabase/migrations/`; `pg_policies`, ACL y funciones `SECURITY DEFINER` |
| Contratos DB y concurrencia | `supabase/tests/database/`, `supabase/tests/concurrency/` y tests nuevos en `supabase/tests/` |
| Recorridos E2E | `.specs/testing/e2e.md` y `integration_test/`; considerar prerequisitos/efectos persistentes de cada flujo |
| Patrones Flutter | `.specs/01-module-contracts.md`, `.specs/architecture/module-security-contract.md`, DI y API publica de cada modulo |

Buscar referencias con `rg -n "anon|to public|grant execute|SECURITY DEFINER|signUp\\(|signInAnonymously|claim_local_superadmin|superadmin_device_identifier|DeviceIdentity|device_identifier" lib supabase integration_test test .specs`.
Cada coincidencia debe clasificarse: identidad, trazabilidad, permiso directo,
politica RLS, RPC indirecta, fixture o referencia historica. No borrar una
coincidencia solo por nombre.

### Orden obligatorio del trabajo

1. **Rebaselinar.** Ejecutar `git status --short`, anotar `git rev-parse HEAD`
   y revisar diffs ajenos antes de editar. Confirmar entorno con
   `SUPABASE_TELEMETRY_DISABLED=1 supabase status` y
   `SUPABASE_TELEMETRY_DISABLED=1 supabase migration list --local`. No mostrar ni
   guardar las claves que pueda imprimir `supabase status`.
2. **Especificar el modulo Auth.** Crear/actualizar contrato funcional y
   tecnico para inicio/cierre de sesion, restauracion/expiracion, aprovisionar
   cuentas fuera del cliente, navegacion protegida y estados offline. Respetar
   el unico punto de composicion (`main.dart`) y la API publica del modulo.
   No reutilizar el borrador PIN como identidad.
3. **Definir aprovisionamiento y primer admin.** El cliente Flutter nunca recibe
   `service_role` ni implementa registro. El primer usuario se crea con Auth
   desde una herramienta operativa confiable. El bootstrap debe identificar
   exactamente a ese `auth.uid()` preseleccionado por el operador; no usar
   “primer usuario que llegue” ni una RPC reclamable por cualquier sesion.
   Implementar la asignacion de forma atomica, de una sola vez y con prueba de
   carrera. Mantener iguales los permisos comerciales de usuarios normales;
   el superadmin solo se distingue para operaciones de instalacion aprobadas.
4. **Provisionar fixtures antes de cerrar signup.** Cambiar E2E y pruebas para
   consumir una cuenta local preaprovisionada o un fixture admin aislado. La
   clave `service_role` solo puede usarse en tooling de pruebas que falle si no
   esta en loopback y nunca en la app, bundles, logs o CI compartida. Probar que
   signup y Auth anonimo estan rechazados; entonces apagar signup en ambos
   `enable_signup` de `supabase/config.toml` (`[auth]`, `[auth.email]`).
5. **Integrar la sesion en Flutter.** Agregar proveedor de estado Auth,
   formulario solo de inicio, cierre, expiracion y guarda de rutas. Redirigir
   rutas de negocio a login sin sesion, y no cargar providers/repositorios antes
   de autenticar. Probar restauracion de sesion, expiracion, logout y regreso a
   la ruta solicitada sin bucles GoRouter.
6. **Migrar identidad/auditoria gradualmente.** Para cada modulo, dejar de
   aceptar actor como identidad declarada por el cliente y establecer actor
   desde `auth.uid()` en SQL. Conservar nombre/id de equipo solo como metadata
   explicita de trazabilidad, no como prueba de identidad o autorizacion.
   Considerar la cola offline: comandos creados por una sesion no deben
   sincronizarse bajo otra cuenta sin una politica especifica.
7. **Migrar permisos por modulo.** Inventariar el invocador real de cada lectura
   y RPC; agregar grants/RLS para `authenticated`, retirar `anon`/`PUBLIC` solo
   para ese contrato y en la misma unidad de trabajo actualizar pgTAP, pruebas
   de repositorio y E2E. Nunca hacer un `REVOKE` global antes de que todos los
   consumers hayan cambiado.
8. **Retirar legado y abrir gates al final.** Eliminar `claim_local_superadmin`,
   columnas y parametros basados en dispositivo solo despues de `rg` sin
   consumers y pruebas de esquema migrado. Reabrir purga/produccion solo con
   identidad superadmin Auth probada, gate SQL, audit trail y confirmacion UI.
   Un usuario Auth normal debe recibir rechazo en esas operaciones.
9. **Cerrar el release gate.** Repetir el inventario de grants/politicas por
   entorno, comparar con la linea base, correr todas las suites, E2E verticales
   y build desktop. Actualizar el gate con evidencia; no marcar produccion lista
   solo porque compila o porque los tests mock pasan.

### Comandos y limites operativos

Validacion Flutter, sin tocar Supabase:

```bash
flutter analyze
flutter test
flutter test test/modules/authorization
flutter test integration_test/<flujo_auth>.dart -d macos
flutter build macos --debug
```

Validacion DB local (requiere Docker/Supabase local; deshabilitar telemetria si
el CLI no puede escribir fuera del workspace):

```bash
SUPABASE_TELEMETRY_DISABLED=1 supabase status
SUPABASE_TELEMETRY_DISABLED=1 supabase migration list --local
SUPABASE_TELEMETRY_DISABLED=1 supabase test db supabase/tests/database
SUPABASE_TELEMETRY_DISABLED=1 supabase test db supabase/tests/concurrency
```

Aplicar migraciones solo tras inspeccionar `migration list`, confirmar que la
URL sea loopback y leer el SQL. Preferir `supabase migration up --local`; si la
CLI exige `--include-all` por migraciones ya aplicadas fuera de orden, revisar
cuales incluye y explicar el efecto antes de usarlo. No ejecutar `supabase db
reset` en el entorno local compartido de este proyecto: elimina los registros
E2E y datos de trabajo. No ejecutar comandos ligados a proyectos remotos salvo
autorizacion expresa y plan de restauracion probado.

### Rollback y checkpoint de cada fase

- Cada fase/flujo completado se guarda en un commit selectivo que incluya
  implementacion, spec y tests. Revisar staged diff antes de confirmar; nunca
  incluir las modificaciones previas de otro agente por conveniencia.
- Aplicacion: revertir con un commit compensatorio o volver al commit estable
  mediante el procedimiento de release del equipo; no reescribir commits
  compartidos ni usar `reset --hard`.
- Base de datos: priorizar migraciones aditivas forward-fix. Para grants, una
  reversa solo puede restaurar el permiso minimo a `authenticated`; nunca
  reabrir `anon`/`PUBLIC` en bloque. El gate de purga/produccion no se revierte
  junto con fallos de login.
- Datos E2E son persistentes e inmutables; guardar ids/documentos sinteticos en
  el reporte de la corrida y no borrarlos para simular rollback.
- Antes del commit: pruebas relevantes y `git diff --cached --check`. Despues:
  verificar commit, trailers/firma criptografica disponible y estado del arbol.
  Si se interrumpe una fase incompleta, crear checkpoint de alcance limitado
  con estado `wip` y dejar pasos de continuacion; no abandonar cambios sin
  explicar como recuperarlos.

## Criterios de aceptacion

1. Ninguna operacion de negocio protegida puede ejecutarse con rol `anon` ni
   por una sesion anonima de Auth.
2. Cada RPC expuesta tiene invocador esperado, grant explicito y pruebas
   positivas/negativas de permisos.
3. Ninguna tabla con RLS desactivado queda expuesta a roles de cliente; las
   tablas internas de idempotencia solo son accesibles por su contrato servidor.
4. Las lecturas de clientes, ventas, pagos, inventario, auditoria y configuracion
   no exceden el alcance autorizado.
5. Reclamar superadministrador y purgar datos requieren identidad/permiso
   autenticado; la auditoria identifica `auth.uid()`.
6. PgTAP, pruebas Flutter, E2E autenticadas, chequeos de seguridad Supabase y
   compilacion pasan en un entorno limpio y repetible.
7. La revocacion no se aplica antes de migrar app, pruebas y fixtures; el rollback
   documenta como restaurar servicio sin reabrir acceso mas amplio del necesario.

## Fuera de alcance de esta documentacion

- No completa el modulo de autenticacion ni revoca grants comerciales generales.
- No invoca la purga ni modifica datos remotos.
- No afirma que una base alojada haya sido auditada; los conteos son de la base
  local observada.
