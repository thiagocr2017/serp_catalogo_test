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
6. El arbol de `MODULE_STRUCTURE.md` no contiene `core/device`,
   `core/identity`, `core/navigation`, `core/offline`, `shared/navigation` ni
   `lib/modules/payments`.
7. `lib/core/documents/` **no existe**. La capacidad compartida de documentos
   no esta implementada.

## Inconsistencias y correccion exacta

| ID | Afirmacion documental | Realidad | Correccion |
|---|---|---|---|
| D1 | `README.md` L57 y `MODULE_STRUCTURE.md` L227: Ventas es «estructura modular inicial» / «Inicial: gestion de agentes» | CRUD de clientes implementado y probado; tablas y RPC de documentos comerciales existen | Cambiar el estado a «Parcial: agentes y clientes funcionales; documentos comerciales con modelo y RPC sin UI de creacion» |
| D2 | `SDD_Modulo_Pagos.md` L1-7: «El modulo todavia no esta implementado» | Implementacion funcional base de 1122 lineas cableada en `main.dart` | Reescribir el estado a «Implementacion funcional base; alcance parcial frente al diseno». Detallar que falta en `.specs/modules/payments/1.status.spec.md` |
| D3 | `docs/database_schema.md` lista `catalog_agents` dentro de «Tablas actuales» | Es una vista de compatibilidad | Separar «Tablas» de «Vistas de compatibilidad» y anotar el destino de retirada |
| D4 | `MODULE_STRUCTURE.md` L18-42: arbol de `lib/` incompleto | Faltan `core/device`, `core/identity`, `core/navigation`, `core/offline`, `shared/navigation`, `modules/payments` | Actualizar el arbol y la tabla de modulos |
| D5 | `AGENTS.md` no menciona `.specs/` ni `authorization` | `.specs/` es la fuente viva de especificaciones; existe spec de autorizacion | Agregar `.specs/` a la documentacion clave, listar `authorization` y corregir el estado de `payments` |
| D6 | `MODULE_STRUCTURE.md` y `.specs/01-module-contracts.md` duplican las mismas reglas | Dos fuentes normativas para la misma regla | Declarar `.specs/01-module-contracts.md` normativo y `MODULE_SECURITY_CONTRACT.md` referencia detallada. Dejar la nota de resolucion en ambos |
| D7 | `MODULE_SECURITY_CONTRACT.md` §3 prohibe exponer «providers internos de Riverpod» | `inventory_module.dart` exporta `di/inventory_providers.dart` | Decidir: mover el contrato necesario a `api/` o retirar la exportacion. Ver seccion 4 |
| D8 | `MODULE_STRUCTURE.md` §5: el indice es «la unica interfaz publica» | `main.dart` importa archivos de `api/` de sales por separado, saltandose el indice | Completar `sales_module.dart` o justificar por escrito cada export omitido |
| D9 | `.opencode/skills/ux-ui-screen-design/scripts/ux-audit.sh` se documenta como auditoria UX generica | Audita React (`import React`, `useRef`, `useEffect`, `*.test.tsx`); con `.dart` reportaba 2 fallos falsos por pantalla y proponia crear archivos `.test.dart` fuera de `test/` | Anadir rama `.dart` con checks de Flutter y conservar los de React por extension |
| D10 | `AGENTS.md` y `.specs/README.md`: «Las specs se versionan junto al codigo» | `.specs/`, `.opencode/` y `docs/database_schema.md` no estan en `.gitignore` pero **nunca se hicieron `git add`**: la fuente viva de especificaciones no esta en control de versiones | Anadir `.specs/`, `.opencode/` y `docs/` a git. Sin esto, el workflow SDD entero puede perderse y ningun agente futuro leera estas reglas |

## Tareas

- [ ] T1. Registrar esta spec en `.specs/README.md`.
- [ ] T2. Corregir D1 en `README.md` y `MODULE_STRUCTURE.md`.
- [ ] T3. Corregir D2 en `SDD_Modulo_Pagos.md` y crear
      `.specs/modules/payments/1.status.spec.md` con el alcance real frente al
      diseno del SDD.
- [ ] T4. Corregir D3 en `docs/database_schema.md`.
- [ ] T5. Corregir D4 y D8 en `MODULE_STRUCTURE.md`.
- [ ] T6. Corregir D5 en `AGENTS.md`.
- [ ] T7. Resolver D6 dejando una sola fuente normativa por regla.
- [ ] T8. Resolver D7 tras decidir el alcance de `InventoryApi`.
- [ ] T9. Ejecutar `flutter analyze` y `flutter test` si alguna correccion
      toca codigo Dart.
- [ ] T10. Volver a leer los documentos corregidos y confirmar que ninguna
      afirmacion contradice otra.
- [x] T11. **Resuelto**: anadida rama `.dart` a
      `ux-audit.sh` con checks de Flutter; los checks de React quedaron
      intactos por extension. Verificado contra `customers_page.dart`,
      `agent_page.dart`, `product_form_page.dart` y `warehouses_page.dart`
      (la busqueda de tests ahora encuentra
      `*_form_validation_test.dart`) y contra un `.tsx` de control.
- [ ] T12. **Requiere decision del propietario**: versionar `.specs/`,
      `.opencode/` y `docs/` en git (D10). No ejecutar junto con el trabajo
      en curso ajeno sin revisarlo primero.

## Decisiones requeridas

### D7 - export de `di/inventory_providers.dart`

Opcion A: retirar la exportacion y exponer solo contratos de `api/`.
- Razon: es lo que exige `MODULE_SECURITY_CONTRACT.md` §3 y evita que un
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
4. `docs/form_test_coverage.md` no quedo desactualizado por los cambios.
