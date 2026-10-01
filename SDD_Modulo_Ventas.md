# SDD - Módulo 3: Ventas

## 1. Descripción general

El módulo de Ventas administrará agentes, clientes y documentos comerciales y
coordinará su impacto en Inventario. Actualmente se encuentra en fase inicial:
solo está implementada la administración de agentes utilizada por el catálogo
PDF. El resto de este documento distingue el comportamiento actual del alcance
futuro.

## 2. Funcionalidad implementada

- Pantalla propia accesible desde `Ventas > Agentes`.
- Creación de agentes.
- Edición de nombre y teléfono.
- Desactivación lógica.
- Selección de un agente para el catálogo PDF.
- Uso de nombre y teléfono en la portada y el QR de contacto.

## 3. Modelo actual de agente

La tabla provisional `catalog_agents` contiene:

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | UUID | Identificador. |
| `name` | Text | Nombre visible. |
| `phone` | Text | Número utilizado para contacto. |
| `is_active` | Boolean | Disponibilidad para selección. |
| `created_at` | Timestamp | Fecha de creación. |
| `updated_at` | Timestamp, nullable | Fecha de modificación. |
| Metadatos de actor y dispositivo | Varios | Trazabilidad provisional. |

Si se desactiva el agente seleccionado en Configuración, se limpia también la
selección utilizada por el catálogo.

## 4. Arquitectura objetivo

Ventas debe adoptar la estructura modular completa:

```text
sales/
├── api/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── use_cases/
├── data/
│   ├── data_sources/
│   ├── models/
│   ├── mappers/
│   └── repositories/
├── presentation/
│   ├── controllers/
│   ├── pages/
│   └── widgets/
├── services/
├── di/
└── sales_module.dart
```

Productos y Catálogo deberán consumir agentes mediante `sales/api/`, sin
acceder al repositorio o a los providers internos de Ventas.

## 5. Alcance futuro

Las siguientes capacidades están previstas, pero no implementadas:

- clientes y datos de contacto;
- cotizaciones, pedidos, documentos de devoluciones(enteras o parciales), documentos de consignación y documentos de venta;
- líneas de documento con producto, cantidad y precio histórico;
- asignación de agente o vendedor;
- estados y numeración de documentos;
- promociones y descuentos aplicados;
- moneda, impuestos y redondeo conservados históricamente;
- métodos y condiciones de pago;
- salida de inventario al confirmar la operación;
- reserva de inventario para pedidos;
- cancelaciones mediante movimientos compensatorios;
- búsqueda, filtros, reportes y auditoría de documentos.

## 6. Integración prevista

- **Productos:** consulta datos comerciales y precios mediante su API pública.
- **Inventario:** registra salidas o reversiones sin modificar stock directamente.
- **Configuración:** obtiene moneda, impuestos, redondeo, empresa y documentos.
- **Autenticación:** sustituirá la identificación provisional del equipo por el
  usuario y sus permisos.

Las operaciones que confirmen una venta y descuenten inventario serán atómicas
en PostgreSQL. Una confirmación guardará conjuntamente el documento, sus líneas,
la liberación de reservas, el movimiento `SALE`, el stock por bodega y la
auditoría. Si falla cualquiera de esas acciones, ninguna se confirma.

## 7. Reglas iniciales

- Un agente inactivo no puede seleccionarse para nuevos catálogos o documentos.
- Desactivar un agente no elimina documentos históricos.
- Los documentos deben conservar el nombre, moneda, impuestos y precios que
  tenían al emitirse, aunque la configuración cambie posteriormente.
- Una venta confirmada no se corrige borrando movimientos de inventario.
- Un pedido reserva inventario sin disminuir el stock físico.
- Anular un pedido libera su reserva.
- Confirmar una venta libera la reserva y crea la salida física en una única
  transacción.
- Una venta sincronizada desde operación offline debe utilizar un identificador
  idempotente para impedir duplicados.

## 8. Estado arquitectónico y deuda técnica

- Ventas dispone de API pública, contrato de repositorio, fuente Supabase,
  modelo de datos, repositorio, DI, presentación, rutas e índice público.
- Productos obtiene los agentes mediante `SalesApi`, sin depender de internals.
- La tabla se llama provisionalmente `catalog_agents`; deberá decidirse si se
  renombra a `sales_agents` antes de que existan documentos dependientes.
- Faltan pruebas específicas para el repositorio y la pantalla de agentes.
- Los casos de uso crecerán cuando se incorporen documentos comerciales; el CRUD
  inicial utiliza directamente el contrato del repositorio desde su API.
