# 03 - Migracion de DTOs publicos

## Proposito

Que un cambio interno deje de ser un cambio de contrato publico. Hoy las API
publicas de `product`, `inventory` y `sales` re-exportan entidades de dominio
y, en el caso de `sales`, interfaces de repositorio. Cualquier campo que se
anada o renombre en una entidad rompe a sus consumidores sin que el compilador
lo senale como cambio de contrato.

Esta spec es de refactorizacion. No cambia comportamiento observable de la
aplicacion.

## Estado verificado

Comprobado el 2026-10-03 sobre `lib/modules/*/api/`:

| Archivo | Re-exporta | Problema |
|---|---|---|
| `product/api/product_api.dart` | `../domain/entities/product.dart`, `../domain/entities/product_query.dart` | entidad expuesta como DTO |
| `inventory/api/inventory_api.dart` | `../domain/entities/audit_entry.dart`, `inventory_transaction.dart`, `inventory_balance.dart`, `inventory_document.dart`, `inventory_reservation.dart`, `inventory_count.dart`, `warehouse.dart` | 7 entidades expuestas |
| `sales/api/customer_api.dart` | `../domain/entities/customer.dart`, `customer_commercial.dart`, **`../domain/repositories/customer_repository.dart`** | entidad + repositorio |
| `sales/api/sales_invoice_api.dart` | `../domain/entities/sales_invoice.dart`, **`../domain/repositories/sales_invoice_repository.dart`** | entidad + repositorio |
| `sales/api/quote_api.dart` | `../domain/entities/sales_quote.dart`, **`../domain/repositories/quote_repository.dart`** | entidad + repositorio |
| `sales/api/order_api.dart` | `../domain/entities/sales_order.dart`, **`../domain/repositories/order_repository.dart`** | entidad + repositorio |
| `sales/api/return_api.dart` | `../domain/entities/sales_return.dart`, **`../domain/repositories/return_repository.dart`** | entidad + repositorio |
| `sales/api/consignment_api.dart` | `../domain/entities/sales_consignment.dart`, **`../domain/repositories/consignment_repository.dart`** | entidad + repositorio |

`.specs/architecture/module-security-contract.md` §3 prohibe expresamente «repositorios o fuentes
de datos concretas» y «entidades internas con campos que el consumidor no
necesita». Los seis exports de repositorios de `sales` violan la primera.

Lo que ya esta bien y no debe tocarse:

- `sales/api/sales_dtos.dart`, `sales/api/sales_commands.dart`,
  `configuration/api/configuration_dtos.dart`,
  `configuration/api/configuration_commands.dart`,
  `payments/api/payment_dtos.dart`, `payments/api/payment_commands.dart` son
  DTO y comandos propios.
- `inventory/api/inventory_commands.dart` y
  `inventory/api/transaction_descriptions.dart` son contrato propio.
- Los providers de la fachada (`inventoryApiProvider`, `productApiProvider`,
  etc.) viven en `api/` y se consideran parte del registro publico de la
  fachada, no de `di/`.

## Forma objetivo

Cada modulo crea `api/<modulo>_dtos.dart` con clases inmutables y estables, y
`data/mappers/` con la conversion entidad -> DTO. El indice `<module>_module.dart`
exporta `api/` y nada mas.

```text
api/
├── product_api.dart        # firma usa ProductSummaryDto / ProductDetailDto
├── product_dtos.dart       # DTO inmutables, versionados
└── product_routes.dart
data/
└── mappers/
    └── product_mapper.dart # entidad de dominio -> DTO publico
```

Reglas del DTO publico:

- inmutable y con igualdad por valor;
- solo los campos que el consumidor necesita;
- sin tipos de Supabase, sin `DateTime` mutable expuesto como referencia
  compartida, sin listas que crezcan sin control;
- quitar o reinterpretar un campo exige migrar consumidores y registrar el
  cambio (`.specs/architecture/module-security-contract.md` §3).

## Orden de migracion y su razon

1. `product` primero.
   - Razon: expone 2 entidades y `ProductApi` tiene 2 metodos. Sirve para
     fijar el patron de DTO y mapper con el menor alcance posible.
   - Consecuencia: `inventory` sigue con entidades expuestas durante un rato,
     pero el patron ya estara probado cuando se le aplique.
2. `inventory` despues.
   - Razon: 7 entidades y la superficie de API mas grande; hacerlo sin patron
     probado multiplica el riesgo sobre el libro inmutable.
   - Consecuencia: es el cambio mas largo de la fase.
3. `sales` al final, empezando por retirar los exports de repositorio.
   - Razon: retirar primero lo que el contrato prohíbe expresamente tiene el
     mayor valor de cumplimiento por el menor esfuerzo.
   - Consecuencia: los DTO de `sales` llegan despues, pero la violacion
     explicita desaparece pronto.

Alternativa considerada: migrar todo de una vez.
- Razon a favor: un solo cambio de contrato y una sola revision.
- Consecuencia: ~15 archivos de contrato a la vez y una prueba de regresion
  dificil de aislar si algo falla. Se descarta por eso.

## Tareas

- [x] T1. Spec de producto: **definido aqui abajo** (seccion «Contrato de
      producto resultante»).
- [ ] T2. `data/mappers/product_dto_mapper.dart` con conversion entidad -> DTO.
- [ ] T3. Cambiar `ProductApi` para devolver DTO y retirar los
      `export '../domain/entities/...'`.
- [ ] T4. Migrar consumidores de `product` y actualizar sus pruebas.

## Contrato de producto resultante

Definido en T1 antes de codificar, segun R5. Se verifico primero el alcance
real: `ProductApi` tiene **un solo consumidor externo**,
`lib/modules/inventory/presentation/pages/inventory_document_form_page.dart`,
que usa `id`, `sku`, `name`, `description` y `currentStock`, y llama con
`ProductQuery(isActive: true)`. Todo lo demas consume el caso de uso
`GetProducts` del propio modulo y sigue usando la entidad de dominio.

```text
// api/product_dtos.dart

ProductSummaryDto {
  id              // opaco para el consumidor
  sku
  name
  description
  currentStock
}

ProductListQuery {
  searchTerm      // opcional
  categoryId      // opcional
  isActive        // opcional
}
```

Notas de la decision:

- Se crea `ProductListQuery` en vez de reutilizar `ProductQuery` de dominio,
  aunque hoy tengan los mismos tipos. `ProductQuery` ademas filtra por
  `onlyLowStock`, `minimumPriceInCents` y `maximumPriceInCents`, que el
  consumidor no necesita. Expuesto `ProductQuery`, cualquier cambio interno de
  esos filtros romperia el contrato. La consecuencia es un mapping de 3 campos;
  el beneficio es que el contrato publico no se mueve con el filtro interno.
- Se renombran los metodos publicos a `listProducts` y `getProductSummary`.
  Motivo: `SupabaseProductRepository` implementa a la vez `ProductRepository`
  y `ProductApi`, y Dart no admite dos `getProducts` con distinto tipo de
  retorno en la misma clase. La consecuencia es un cambio de nombre en el
  contrato publico, que hoy tiene un unico consumidor y por tanto cero coste de
  migracion real.
- No se crea `ProductDetailDto`: `ProductApi.getProductById` no tiene ningun
  consumidor externo, asi que no se expone. Si en el futuro otro modulo
  necesita la ficha, se define ese DTO entonces, con los campos que necesite.
- `ProductSummaryDto` lleva igualdad por valor, como exige la regla del DTO
  publico.
- [x] T5. Repetir T1-T4 para las 7 entidades de `inventory`.
      Resuelto en `442916e`: `InventoryApi` devuelve DTO públicos desde
      `inventory_dtos.dart`; `SupabaseInventoryApi` envuelve
      `SupabaseInventoryRepository` y traduce entidades de dominio a DTO con
      `data/mappers/inventory_dto_mapper.dart`. Los enums se re-exportan con
      `show` como tipos de valor compartidos; ninguna entidad de dominio se
      exporta desde `inventory/api/`.
- [ ] T6. Retirar los 6 `export '../domain/repositories/...'` de `sales` y
      sustituirlos por contratos de `api/`.
- [ ] T7. Crear DTO de `sales` para las 6 entidades restantes.
- [ ] T8. Verificar con la prueba de frontera que ningun modulo importa capas
      internas de otro.
- [ ] T9. Retirar la vista `catalog_agents` (T13 de
      `01-document-consistency.md`) con prueba pgTAP de ausencia, actualizando
      `1b2_configuration_sales_behavior_test.sql`,
      `1b2_configuration_sales_state_test.sql` y
      `1b2_configuration_sales_lifecycle_test.sql`, que hoy la consultan.

## Contrato de pruebas

Cada modulo migrado debe mantener en verde, sin cambiar su alcance:

- `flutter analyze` sin incidencias;
- `flutter test` completo;
- las pruebas de formulario del modulo afectado;
- `supabase test db` si se toca una migracion o una RPC;
- prueba de frontera: ningun modulo importa `data/`, `domain/`, `di/`,
  `presentation/` ni `services/` de otro.

Adicionar por DTO nuevo:

- serializacion estable del DTO;
- mapeo entidad -> DTO con todos los campos que declara el contrato;
- un consumidor de ejemplo compila importando solo `<module>_module.dart`.

## Criterio de listo

1. Ningun archivo de `api/` contiene `export '../domain/...'`.
2. Ningun archivo de `api/` exporta una interfaz de repositorio.
3. La prueba de frontera pasa.
4. `.specs/architecture/module-structure.md` seccion «Deuda tecnica reconocida» deja de mencionar
   la exposicion de entidades.
