# 02 - Plan de deuda tecnica

## Proposito

Convertir la lista abierta de deuda tecnica en un plan ejecutable por fases,
con dependencias explicitas, criterios de verificacion y decisiones que
requieren al propietario del negocio antes de escribir codigo.

Este documento es una spec de refactorizacion. Cada fase que cambie
arquitectura tendra su propia spec concreta antes de implementarse.

## Principio de ordenamiento

Las fases siguen el orden **medir -> decidir -> contratar -> implementar ->
endurecer**.

- Razon: endurecer permisos o renombrar contratos sin una linea base verificable
  rompe pantallas sin que las pruebas lo detecten, y decidir despues de
  implementar obliga a reescribir.
- Consecuencia frente a la alternativa: la alternativa obvia, atacar primero la
  deuda mas visible, produce cambios que hay que revertir cuando aparece la
  dependencia oculta. Este orden tarda mas en mostrar resultados pero evita
  reescritura.

Regla transversal: ninguna fase de endurecimiento empieza sin que existan
pruebas negativas que fallen si el endurecimiento no se aplico.

## Estado verificado de cada deuda

### D-1. APIs publicas exponen entidades de dominio

Confirmado. `lib/modules/product/api/product_api.dart` hace
`export '../domain/entities/product.dart'` y `product_query.dart`.
`lib/modules/inventory/api/inventory_api.dart` re-exporta 7 entidades de
`../domain/entities/` ademas de `inventory_commands.dart`.

Efecto: cualquier cambio interno de una entidad es un cambio de contrato
publico. Los consumidores dependen de campos que no necesitan.

### D-2. `catalog_agents` con nombre historico

**La renombre de tabla ya ocurrio.** `20260929120000` renombro la tabla a
`sales_agents` y creo `catalog_agents` como vista de compatibilidad
`security_invoker`. Las escrituras sobre la vista ya fueron revocadas y
verificadas por `1b3_legacy_write_revocation_test.sql`.

Lo que queda es retirar la vista y corregir la documentacion que la llama tabla
(ver `01-document-consistency.md` D3). La ventana que el SDD describia como
«antes de que existan documentos de venta» ya se cerro parcialmente: las FK de
`sales_quotes` y `sales_orders` apuntan a `sales_agents`. El riesgo residual es
bajo.

### D-3. RLS provisional

Confirmado. Politicas `using (true)` y permisos amplios persisten en varias
tablas mientras `anon` y `authenticated` representan al mismo cliente local.
`.specs/archive/verification/block-1a-baseline.md` documenta la matriz y los bloques previstos (1B.3,
1C, 1D).

### D-4. Storage sin endurecer

Confirmado. `product-images` y `catalog-assets` permiten CRUD a `anon` y
`authenticated` por politica de bucket. Un cliente local puede operar objetos
ajenos; solo MIME y tamaño limitan la carga.

### D-5. Pruebas PostgreSQL de atomicidad e idempotencia no automatizadas

Parcialmente confirmado. Existen 7 archivos pgTAP en `supabase/tests/database/`
y 1 script de concurrencia en `supabase/tests/concurrency/`, pero **todos cubren
Configuracion y Ventas** (bloques 1B.2, 1B.3, 1B.4). No existe cobertura pgTAP
de Inventario: atomicidad de documento, idempotencia concurrente,
inmutabilidad de movimientos y reversión siguen validadas solo por una prueba
manual con `ROLLBACK`.

### D-6. Falta generar A4 y ticket de 80 mm de documentos de inventario

Confirmado y bloqueado por una ausencia mayor: **`lib/core/documents/` no
existe**. La capacidad compartida de renderizado A4, ticket y ESC/POS esta
inteiramente por crear, junto con el perfil Rongta RPP300 y los transportes.

### D-7. Preguntas abiertas de Clientes

**Resuelto el 2026-10-03.** Las 23 preguntas de
`.specs/modules/sales/customer-management/0.open-questions.md` quedaron cerradas
y el registro llega a **44 decisiones** (seccion B, decisiones 20 a 44):
fiscalidad, identificacion, geografia, credito y PIN, rankings, alertas del
perfil y envio.

El rediseño de Clientes ya puede implementarse. Antes hay que leer ese registro.

Quedan sueltas dos preguntas menores del PIN (longitud y modo de entrega) en
`.specs/modules/authorization/1.one-time-pin-approval.spec.md`, que no bloquean
el rediseño de Clientes.

### D-8. Ventas sin conversion cotizacion a pedido, sin liquidacion de
consignacion, sin integracion Pagos

Confirmado en `.specs/modules/sales/sdd-historical.md` seccion 7. Depende de D-7 y del contrato
publico Ventas <-> Pagos.

## Fases

### Fase 0 - Linea base

**Estado: completada.** Resultado registrado el 2026-10-03 contra el arbol con
trabajo en curso sin commitear (Flutter 3.47.0, Supabase CLI 2.118.0):

| Verificacion | Resultado |
|---|---|
| `flutter analyze` | `No issues found!` |
| `flutter test` | 83/83 `All tests passed!` |
| `flutter build macos --debug` | `✓ Built build/macos/Build/Products/Debug/serp.app` |
| `supabase test db` | 7 archivos, 71 tests, `Result: PASS` |
| `supabase/tests/concurrency/1b2_idempotency_concurrency.sh` | `PASS: concurrent retries returned one agent and one presentation with completed receipts` |

Defecto hallado y corregido durante la linea base: `1b2_configuration_sales_transitions_test.sql`
no era hermetico. Afirmaba `catalog_preferences_version = 1` como valor absoluto,
pero `select_catalog_agent`, `save_catalog_preferences` y
`clear_selected_catalog_agent_internal` incrementan esa columna en uso normal de
la aplicacion. Contra cualquier base ya usada el archivo fallaba en el test 10 y
abortaba los 3 restantes (`Bad plan. You planned 13 tests but ran 10`). Se
corrigio comparando deltas capturados dentro de la transaccion que se revierte,
sin cambiar el contrato verificado. El mismo patron debe aplicarse a toda prueba
pgTAP nueva: **no afirmar valores absolutos de columnas que la aplicacion muta**.

Matriz real de permisos: 43 objetos con privilegio para `anon`/`authenticated`.
La mayoria son de solo `SELECT`. Excepciones comprobadas ejecutando el intento
dentro de `rollback` con `set local role authenticated`:

| Objeto | Privilegio concedido | RLS | Resultado real | Veredicto |
|---|---|---|---|---|
| `inventory_transactions` | INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER | solo `SELECT` + `INSERT` (`with_check true`) | **`INSERT 0 1`**: se puede insertar un movimiento directo | **Hueco**: permite esquivar el flujo documental |
| `audit_logs` | INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER | solo `SELECT` | `new row violates row-level security policy` | Bloqueado por RLS, pero el `GRANT` esta por demas |
| `audit_actions` | ninguno | politica `ALL` | `permission denied for table audit_actions` | Protegido por `GRANT` |
| `inventory_balances` | TRUNCATE, REFERENCES, TRIGGER | solo `SELECT` | sin escritura directa | `TRUNCATE` sobrante |
| `product_catalog` | INSERT, UPDATE, DELETE, TRUNCATE | — | es una **vista**, no una tabla | Documentada como tabla |
| Resto (37 objetos) | `SELECT` | `SELECT` | solo lectura | Conforme |

El hueco de `inventory_transactions` ya estaba previsto en
`.specs/archive/verification/block-1a-baseline.md` como bloque 1D («Retirar camino directo»), pero
`.specs/database/schema-current.md` afirma que «las tablas de negocio estan endurecidas
para escritura directa», lo cual hoy no es cierto para esa tabla. Ver D11 en
`01-document-consistency.md`.

Tareas ejecutadas:

- [x] Ejecutar `flutter analyze`, `flutter test` y `flutter build macos --debug`.
- [x] Ejecutar la suite pgTAP actual y registrar el conteo (71 tests).
- [x] Ejecutar la prueba de concurrencia de idempotencia.
- [x] Registrar la matriz real de permisos por tabla, comparada con
      `.specs/archive/verification/block-1a-baseline.md`.

### Fase 1 - Consistencia documental

**Estado: completada.** Ver `01-document-consistency.md` (D1-D12 resueltas) y
`03-public-dto-migration.md` para el resto. No bloquea nada pero destraba a
todos los agentes que lean la documentacion.

### Fase 2 - Decisiones de negocio

**Estado: completada.** Cerradas el 2026-10-03 / 2026-10-04.

Objetivo: cerrar lo que no se puede resolver tecnicamente.

- [x] Resolver las 23 preguntas de
      `.specs/modules/sales/customer-management/0.open-questions.md`.
      **Cerradas el 2026-10-03**; el registro llega a 44 decisiones y el
      rediseño de Clientes queda desbloqueado.
- [x] Definir el contrato publico Ventas <-> Pagos antes de crear facturas
      persistentes con aplicaciones de pago.
      **Resuelto el 2026-10-03**: redactado como spec en
      `.specs/04-sales-payments-contract.md`.
- [x] Definir el alcance real de `payments` frente al SDD: que partes del
      diseno estan implementadas y cuales no.
      **Resuelto el 2026-10-03**: alineado el SDD al codigo en
      `.specs/modules/payments/sdd-historical.md` (§1 y §15) y
      `.specs/modules/payments/1.status.spec.md`.
- [x] Decidir el alcance de `InventoryApi` (D-7 de consistencia).
      **Resuelto el 2026-10-03**: cerrado en
      `.specs/refactors/01-document-consistency.md` (T8 / D7) y
      `.specs/refactors/03-public-dto-migration.md` retirando el export de
      `di/inventory_providers.dart` y acotando la frontera pública a `api/`.

Razon: son bloqueos de producto, no de codigo. Resolverlos evita construir
sobre supuestos falsos.
Consecuencia: si se implementa antes, hay que reescribir formularios,
migraciones y contratos cuando cambien las respuestas.

### Fase 3 - Contratos y arquitectura

Objetivo: que un cambio interno deje de ser un cambio de contrato publico.
Plan detallado y orden de migracion en `03-public-dto-migration.md`.

- [ ] Spec concreta: DTO publicos para `ProductApi`.
- [ ] Spec concreta: DTO publicos para `InventoryApi`.
- [ ] Mappers de entidad a DTO y retirada de los
      `export '../domain/entities/...'` de `api/`.
- [ ] Retirar la vista `catalog_agents` tras verificar que no quedan
      consumidores, con prueba pgTAP de ausencia.
- [ ] Completar o justificar el indice `sales_module.dart`.
- [ ] Revisar `main.dart` como raiz de composicion y documentar cada override.

Orden sugerido: `product` primero, `inventory` despues.
- Razon: `product` tiene menos entidades expuestas y sirve para validar el
  patron de DTO sin arriesgar el modulo mas complejo.
- Consecuencia: `inventory` queda mas tiempo con entidades expuestas, pero el
  patron ya estara probado cuando se le aplique.

### Fase 4 - Pruebas PostgreSQL

Objetivo: tener pruebas que fallen si el endurecimiento no se aplica.

**Avance 2026-10-03:** Fase 4 **completada**.

- [x] pgTAP: inmutabilidad de `inventory_transactions` (`UPDATE` y `DELETE`
      bloqueados) y ausencia de privilegios de escritura sobre el libro y sobre
      `inventory_balances`. Incluye `TRUNCATE`, que es un vector que la prueba
      original no contemplaba: RLS no lo cubre y los triggers `BEFORE DELETE`
      tampoco. Ver `inventory_ledger_hardening_test.sql`.
- [x] pgTAP: atomicidad de `create_and_confirm_inventory_document` ante fallo
      intermedio. Ver `inventory_document_integrity_test.sql` A1-A4.
- [x] pgTAP: idempotencia ante reintentos con la misma `command_id`.
      Ver B1-B4.
- [x] pgTAP: reversión y su limite de una reversión directa por movimiento.
      Ver C1-C6.
- [x] pgTAP: atomicidad de la factura de venta contra su documento de
      inventario. Ver D1-D3.

17 aserciones de caracterizacion en `inventory_document_integrity_test.sql`.
Comprobado que no son vacias: dos lineas validas si crean documento (2 lineas
persistidas), asi que el rechazo del caso A1 se debe al producto inexistente y
no a un fallo del fixture.

Nota de metodo: los fixtures de esas pruebas exigen `begin;`/`rollback;`
explicitos. Un `psql -c` sin `begin` envuelve todo en una transaccion implicita
y el `rollback` final la deshace, lo que hace parecer que nada persiste y
convierte un sondeo en algo enganoso.

Razon: es el prerequisito de Fase 5. Sin estas pruebas, revocar permisos puede
romper flujos sin que la suite lo detecte.
Consecuencia: retrasa el endurecimiento visible, pero evita regresiones
silenciosas en inventario, que es el libro inmutable del negocio.

### Fase 5 - Endurecimiento

Objetivo: cerrar los permisos amplios.

- [x] **Cerrado 2026-10-03**: revocar la escritura directa sobre
      `inventory_transactions` e `inventory_balances`, retirar la politica
      `inventory_local_insert` y blindar el `TRUNCATE` con triggers
      `BEFORE TRUNCATE`. Migracion
      `20261003100000_harden_inventory_ledger.sql`, pruebas en
      `inventory_ledger_hardening_test.sql`. Verificado que las RPC
      `SECURITY DEFINER` siguen escribiendo.
- [x] **Cerrado 2026-10-03**: endurecer `audit_logs` (append-only de verdad),
      `audit_actions` y `catalog_logo_operations`. Migracion
      `20261003110000_harden_audit_trail.sql`, pruebas en
      `audit_trail_immutability_test.sql` (25, 12 fallaban antes).
- [x] **Completado antes de lo previsto (2026-10-03)**: revocar la escritura
      directa restante segun `.specs/refactors/04-block-1b-contract-cleanup.md`
      (1B.3). Verificado con dos metodos independientes sobre **todas** las
      tablas de `public`: `has_table_privilege` de `anon` y `authenticated` para
      `INSERT`/`UPDATE`/`DELETE`/`TRUNCATE` devuelve **cero tablas**, y los
      intentos reales de escritura sobre `app_settings`,
      `packaging_presentations` y `sales_agents` dan `permission denied`.
      Ademas los cuatro puentes heredados (`createLegacyAgent`,
      `updateLegacyAgent`, `deactivateLegacyAgent`, `typedef SalesAgent`) ya no
      existen, `configuration_api.dart` no exporta entidades internas y
      Productos no importa `configuration/di`.
- [x] **Revisado 2026-10-03**: `product-images` y `catalog-assets` estan mas
      endurecidos de lo que decia `block-1a-baseline.md` — las politicas ya
      acotan bucket, patron de nombre y MIME, y `catalog-assets` no permite
      borrado. El `TRUNCATE` sobre `storage.objects` **no se puede revocar
      desde `postgres`** (los otorga `supabase_storage_admin` y `postgres` no es
      superuser) y **no es explotable** porque PostgREST no expone el schema
      `storage`. Se documenta en vez de aplicar un `REVOKE` ineficaz. Ver
      `database/schema-current.md` y `storage_hardening_test.sql`.
- [ ] Sustituir identidad de dispositivo por `auth.uid()` cuando exista
      Autenticacion.
- [ ] Sustituir identidad de dispositivo por `auth.uid()` cuando exista
      Autenticacion.
- [ ] Cumplir `.specs/modules/authorization/production-gate.md` antes de permitir
      `PRODUCTION`.

Depende de Fase 4. No iniciar antes.

### Fase 6 - Documentos

Objetivo: cumplir `.specs/architecture/document-standards.md` con las tres salidas.

- [ ] Spec de arquitectura para `lib/core/documents/` (models, pdf, esc_pos con
      renderer, profiles y transports).
- [ ] Perfil Rongta RPP300.
- [ ] Renderizado A4 y ticket 80 mm desde el mismo modelo documental.
- [ ] ESC/POS directo con adaptadores Bluetooth y USB.
- [ ] Aplicar al documento de inventario y validar con la lista de
      `.specs/architecture/document-standards.md` seccion 11.

Razon: la capacidad compartida antes que las plantillas por modulo.
Consecuencia: frente a implementar el A4 de inventario directamente, tarda mas
en ver el primer PDF, pero evita duplicar renderizado en cada modulo y permite
cumplir las tres salidas sin reescribir.

### Fase 7 - Funcionalidad de Ventas

Depende de Fase 2 y del contrato Ventas <-> Pagos.

- [ ] Conversion de cotizacion a pedido (estado `CONVERTED`).
- [ ] Liquidacion de consignacion (estado `SETTLED`).
- [ ] Integracion con Pagos para marcar facturas como `PAID`.
- [ ] UI de creacion y edicion de documentos comerciales con pruebas de
      operacion y validacion.

## Decisiones requeridas

| # | Decision | Por que bloquea | Alternativas |
|---|---|---|---|
| R1 | Respuestas a las 23 preguntas de Clientes | Sin ellas no se puede diseñar el formulario ni las migraciones | **Resuelto 2026-10-03: resolver todas.** Registro completo en `modules/sales/customer-management/0.open-questions.md` (44 decisiones) |
| R2 | Alcance real de `payments` frente al SDD | Determina que es deuda y que es funcionalidad nueva | **Resuelto 2026-10-03: alinear el SDD al codigo.** `.specs/modules/payments/sdd-historical.md` §1 declara el alcance vigente y §15 el futuro |
| R3 | Contrato publico Ventas <-> Pagos | Condiciona facturas persistentes y `PAID` | **Resuelto 2026-10-03: definirlo ahora como spec.** Ver `.specs/04-sales-payments-contract.md` |
| R4 | Retirar o documentar el export de `di/inventory_providers.dart` | Afecta la frontera publica de Inventario | **Resuelto 2026-10-03: retirado el export.** Ver `01-document-consistency.md` T8 y `03-public-dto-migration.md` |
| R5 | Nombres y campos de los DTO publicos de `product` | Fija el contrato que consumiran Inventario y el catalogo | Definirlos en `03-public-dto-migration.md` T1 antes de codificar |

R4 quedo resuelta sin necesitar decision: se retiro el export y se verifico que
ningun consumidor lo necesitaba. Ver `01-document-consistency.md` T8.

## Fuera de alcance

- Nueva funcionalidad comercial.
- Cambios de interfaz visual.
- Migracion a otro almacenamiento o framework.

## Criterio de listo

1. Cada fase tiene su propia spec concreta antes de implementarse.
2. Ninguna fase de endurecimiento se ejecuta sin sus pruebas negativas.
3. Cada deuda queda cerrada, o rechazada con motivo registrado aqui.
4. `.specs/testing/form-coverage.md`, los SDD y `.specs/` reflejan el estado final.
5. `flutter analyze`, `flutter test` y la suite pgTAP pasan.
