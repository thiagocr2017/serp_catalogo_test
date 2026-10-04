# 01 - Consistencia documental

## Proposito

Eliminar las contradicciones entre la documentacion de referencia y el estado
real del codigo y de la base de datos. La documentacion de este proyecto se
usa como contrato de trabajo: si describe algo que no existe, o niega algo que
si existe, cada agente y cada persona que toque el repositorio repite el error.

Este documento es una spec de refactorizacion. No cambia comportamiento de la
aplicacion. Sus unicas modificaciones de codigo son las correcciones de
contrato señaladas en la seccion 4.

## Metodo de verificacion

Toda afirmacion de la seccion 3 fue verificada contra el repositorio antes de
escribir esta spec:

- estructura real de `lib/` y `test/`;
- migraciones de `supabase/migrations/`;
- resultados de `supabase/tests/database/`;
- contenido real de los indices `<module>_module.dart`;
- superficie real de `lib/modules/*/api/`.

Ninguna correccion debe aplicarse solo porque un documento lo diga. Antes de
editar, comprobar el hecho en el codigo y dejar la evidencia en la tarea.

## Estado verificado

Hechos que sirven de fuente de verdad para las correcciones:

1. `catalog_agents` **no es una tabla**. La migracion
   `20260929120000_add_configuration_sales_versioned_rpc_foundations.sql`
   ejecuta `alter table public.catalog_agents rename to sales_agents` y crea
   `public.catalog_agents` como **vista** `security_invoker=true` sobre
   `sales_agents`. Sus escrituras fueron revocadas en
   `20260929121000` y verificadas por
   `supabase/tests/database/1b3_legacy_write_revocation_test.sql`.
2. `lib/modules/payments/` contiene 1122 lineas con `PaymentApi` de 12
   metodos (`getPayments`, `createPayment`, `confirmPayment`, `cancelPayment`,
   `getPaymentMethods`, `createPaymentMethod`, `getMoneyAccounts`,
   `createMoneyAccount`, `createExpense`, `transferBetweenAccounts`,
   `createRefund`), data source, repositorios, entidades y pagina.
   Esta **cableado en `lib/main.dart`** (lineas 48-52, 102-107, 141-142).
3. `lib/modules/sales/` contiene CRUD completo de clientes con 7 data sources
   y 7 repositorios, ademas de `customers`, `customer_contacts` y
   `product_buyers` en la base.
4. El indice `sales_module.dart` exporta solo `sales_api.dart`,
   `customer_api.dart` y `sales_routes.dart`. `main.dart` importa
   `modules/sales/api/sales_invoice_api.dart` y
   `modules/sales/api/quote_api.dart` **directamente**, sin pasar por el indice.
5. `inventory_module.dart` exporta `di/inventory_providers.dart`.
6. El arbol de `.specs/architecture/module-structure.md` no contiene `core/device`,
   `core/identity`, `core/navigation`, `core/offline`, `shared/navigation` ni
   `lib/modules/payments`.
7. `lib/core/documents/` **no existe**. La capacidad compartida de documentos
   no esta implementada.

## Inconsistencias y correccion exacta

| ID | Afirmacion documental | Realidad | Correccion |
|---|---|---|---|
| D1 | `README.md` L57 y `.specs/architecture/module-structure.md` L227: Ventas es «estructura modular inicial» / «Inicial: gestion de agentes» | CRUD de clientes implementado y probado; tablas y RPC de documentos comerciales existen | Cambiar el estado a «Parcial: agentes y clientes funcionales; documentos comerciales con modelo y RPC sin UI de creacion» |
| D2 | `.specs/modules/payments/sdd-historical.md` L1-7: «El modulo todavia no esta implementado» | Implementacion funcional base de 1122 lineas cableada en `main.dart` | Reescribir el estado a «Implementacion funcional base; alcance parcial frente al diseno». Detallar que falta en `.specs/modules/payments/1.status.spec.md` |
| D3 | `.specs/database/schema-current.md` lista `catalog_agents` dentro de «Tablas actuales» | Es una vista de compatibilidad | Separar «Tablas» de «Vistas de compatibilidad» y anotar el destino de retirada |
| D4 | `.specs/architecture/module-structure.md` L18-42: arbol de `lib/` incompleto | Faltan `core/device`, `core/identity`, `core/navigation`, `core/offline`, `shared/navigation`, `modules/payments` | Actualizar el arbol y la tabla de modulos |
| D5 | `AGENTS.md` no menciona `.specs/` ni `authorization` | `.specs/` es la fuente viva de especificaciones; existe spec de autorizacion | Agregar `.specs/` a la documentacion clave, listar `authorization` y corregir el estado de `payments` |
| D6 | `.specs/architecture/module-structure.md` y `.specs/01-module-contracts.md` duplican las mismas reglas | Dos fuentes normativas para la misma regla | Declarar `.specs/01-module-contracts.md` normativo y `.specs/architecture/module-security-contract.md` referencia detallada. Dejar la nota de resolucion en ambos |
| D7 | `.specs/architecture/module-security-contract.md` §3 prohibe exponer «providers internos de Riverpod» | `inventory_module.dart` exporta `di/inventory_providers.dart` | Decidir: mover el contrato necesario a `api/` o retirar la exportacion. Ver seccion 4 |
| D8 | `.specs/architecture/module-structure.md` §5: el indice es «la unica interfaz publica» | `main.dart` importa archivos de `api/` de sales por separado, saltandose el indice | Completar `sales_module.dart` o justificar por escrito cada export omitido |
| D9 | `.opencode/skills/ux-ui-screen-design/scripts/ux-audit.sh` se documenta como auditoria UX generica | Audita React (`import React`, `useRef`, `useEffect`, `*.test.tsx`); con `.dart` reportaba 2 fallos falsos por pantalla y proponia crear archivos `.test.dart` fuera de `test/` | Anadir rama `.dart` con checks de Flutter y conservar los de React por extension |
| D10 | `AGENTS.md` y `.specs/README.md`: «Las specs se versionan junto al codigo» | `.specs/`, `.opencode/` y `.specs/database/schema-current.md` no estan en `.gitignore` pero **nunca se hicieron `git add`**: la fuente viva de especificaciones no esta en control de versiones | Anadir `.specs/`, `.opencode/` y `docs/` a git. Sin esto, el workflow SDD entero puede perderse y ningun agente futuro leera estas reglas |
| D11 | `.specs/database/schema-current.md`: «Las tablas de negocio estan endurecidas para escritura directa... los roles `anon` y `authenticated` no deben hacer `insert`, `update` o `delete` directo sobre las tablas protegidas» | Verificado con `set local role authenticated` dentro de `rollback`: `inventory_transactions` acepta `INSERT 0 1` directo. Su RLS `inventory_local_insert` tiene `with_check true` y hay `GRANT INSERT`. Un cliente puede insertar movimientos sin documento, y el trigger `apply_inventory_transaction()` aplica el stock | Corregir la afirmacion del documento y anotar la excepcion, con el hueco ya asignado al bloque 1D en `.specs/archive/verification/block-1a-baseline.md` |
| D12 | `.specs/database/schema-current.md` lista `product_catalog` en «Tablas actuales» | Es una **vista** (`relkind = v`), igual que `catalog_agents` | Moverla a la seccion de vistas |

## Tareas

Todas completadas salvo T13.

- [x] T1. Registrar esta spec en `.specs/README.md`.
- [x] T2. Corregir D1 en `README.md` y `.specs/architecture/module-structure.md`.
- [x] T3. Corregir D2 en `.specs/modules/payments/sdd-historical.md` y crear
      `.specs/modules/payments/1.status.spec.md`.
- [x] T4. Corregir D3, D11 y D12 en `.specs/database/schema-current.md`.
- [x] T5. Corregir D4 y D8 en `.specs/architecture/module-structure.md`.
- [x] T6. Corregir D5 en `AGENTS.md`.
- [x] T7. Resolver D6: `.specs/architecture/module-security-contract.md` queda como fuente única y
      `.specs/01-module-contracts.md` pasa a enlazarlo sin repetir reglas.
- [x] T8. Resolver D7 con la Opcion A: retirado
      `export 'di/inventory_providers.dart'` de `inventory_module.dart`;
      `main.dart` lo importa como raiz de composicion y
      `inventory_documents_page.dart` importa las capas de su propio modulo.
      Verificado que `product` no usaba ningun read-model de `di/`.
- [x] T9. `flutter analyze` sin incidencias y `flutter test` 83/83 tras el
      cambio de codigo Dart.
- [x] T10. Volver a leer los documentos corregidos y confirmar que ninguna
      afirmacion contradice otra.
- [x] T14. **Correccion de un error propio**: una version intermedia de estos
      cambios afirmo que las escrituras de Pagos no persistian porque su capa
      de datos no usaba RPC. Falso. El diagnostico salio de un
      `grep 'rpc('` que no casa con la invocacion real
      `_client.rpc<Map<String, dynamic>>(`. Verificadas las 8 llamadas RPC y
      ejecutadas contra la base (`create_payment_method` y
      `create_money_account` crean filas). Corregidos `README.md`,
      `AGENTS.md`, `.specs/architecture/module-structure.md`, `.specs/modules/payments/sdd-historical.md`,
      `.specs/database/schema-current.md` y
      `.specs/modules/payments/1.status.spec.md`. Leccion registrada en esa
      spec: una ausencia en un `grep` no prueba una ausencia en el codigo.
- [x] T11. Anadida rama `.dart` a `ux-audit.sh` con checks de Flutter; los
      checks de React quedaron intactos por extension. Verificado contra
      `customers_page.dart`, `agent_page.dart`, `product_form_page.dart` y
      `warehouses_page.dart`, y contra un `.tsx` de control.
- [x] T12. Versionar `.specs/`, `.opencode/` y `docs/` en git (D10), en un
      commit separado del trabajo en curso ajeno.
- [ ] T13. Retirar la vista `catalog_agents` cuando se compruebe que no quedan
      consumidores, con prueba pgTAP de ausencia. Depende de Fase 3 en
      `02-tech-debt-plan.md`.

## Decisiones requeridas

### D7 - export de `di/inventory_providers.dart`

Opcion A: retirar la exportacion y exponer solo contratos de `api/`.
- Razon: es lo que exige `.specs/architecture/module-security-contract.md` §3 y evita que un
  consumidor acople su composicion a los providers internos de Inventario.
- Consecuencia: hay que revisar quien consume ese export y darle un contrato
  equivalente en `api/`.

Opcion B: documentar la excepcion como deuda con responsable y condicion de
retiro.
- Razon: si hoy `main.dart` la necesita para los overrides, retirarla rompe la
  composicion.
- Consecuencia: la excepcion queda viva y puede imitarce en otros modulos.

Recomendada: Opcion A. La unica razon para no hacerla es si la revision de
consumidores demuestra que no hay sustituto disponible en `api/`.

## Fuera de alcance

- Cambiar comportamiento de la aplicacion.
- Cambiar permisos, RLS o migraciones.
- Implementar funcionalidad faltante de Ventas o Pagos.

## Criterio de listo

1. Cada correccion de la tabla se aplico o quedo explicitamente rechazada con
   motivo registrado aqui.
2. Ningun documento de referencia afirma un estado que contradiga a otro.
3. `flutter analyze` y `flutter test` pasan si se toco codigo Dart.
4. `.specs/testing/form-coverage.md` no quedo desactualizado por los cambios.
