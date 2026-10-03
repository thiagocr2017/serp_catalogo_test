# Convenciones de Estructura Modular del Proyecto

## 1. Principios generales

- La aplicación será una aplicación de escritorio construida con Flutter y Dart.
- Cada módulo funcional vive bajo `lib/modules/<module_name>/`.
- Los nombres de los módulos se escriben en `snake_case` y en singular (por ejemplo, `product` e `inventory`).
- Todos los módulos siguen la misma arquitectura base. Una carpeta puede omitirse únicamente cuando el módulo no tenga esa responsabilidad.
- Cada módulo expone una única interfaz pública mediante `api/` y su archivo índice `<module_name>_module.dart`.
- Los demás módulos no deben importar implementaciones internas desde `data/`, `presentation/` o `di/`.
- Toda comunicación y exposición entre módulos debe cumplir
  `MODULE_SECURITY_CONTRACT.md`.
- Las tablas, columnas, variables y nombres técnicos se escriben en inglés. La interfaz y la documentación funcional se mantienen en español.
- Cualquier excepción debe documentarse y justificarse en la sección «Notas de cambio».

## 2. Estructura general de la aplicación

```text
lib/
├── core/                         # Capacidades técnicas compartidas
│   ├── audit/
│   ├── configuration/
│   ├── database/
│   ├── device/
│   ├── errors/
│   ├── identity/
│   ├── navigation/
│   ├── offline/
│   └── utilities/
├── shared/                       # Tema y componentes visuales compartidos
│   ├── navigation/
│   ├── theme/
│   └── widgets/
└── modules/
    ├── configuration/
    ├── inventory/
    ├── payments/
    ├── product/
    └── sales/

test/
├── core/
├── shared/
└── modules/
    ├── configuration/
    ├── inventory/
    ├── product/
    └── sales/
```

`core` y `shared` no son módulos de negocio. Solo deben contener elementos genuinamente reutilizables por varios módulos.

El tema visual vive en `shared/theme`. La preferencia claro/oscuro es una
configuración local del equipo administrada desde `core/configuration`; no forma
parte de los datos comerciales ni requiere conexión con Supabase. El modo
predeterminado es oscuro y todo componente debe utilizar `ColorScheme` salvo
colores semánticos con contraste explícito.

## 3. Estructura estándar de cada módulo

```text
<module_name>/
├── api/                          # Contratos y objetos públicos del módulo
├── domain/                       # Reglas de negocio puras
│   ├── entities/
│   ├── repositories/            # Interfaces de repositorio
│   └── use_cases/
├── data/                         # Acceso y traducción de datos
│   ├── data_sources/
│   ├── models/                  # DTO y representaciones externas
│   ├── mappers/                 # Conversión entre DTO y entidades
│   └── repositories/            # Implementaciones de repositorios
├── presentation/                 # Interfaz y gestión del estado de UI
│   ├── controllers/
│   ├── pages/
│   └── widgets/
├── services/                     # Integraciones propias del módulo, si aplican
├── di/                           # Registro interno de dependencias
└── <module_name>_module.dart     # Índice público del módulo
```

No se crearán carpetas `model/`, `repository/` o `widgets/` adicionales en la raíz del módulo. Sus responsabilidades ya están ubicadas en `data/models`, `domain/repositories`, `data/repositories` y `presentation/widgets`.

## 4. Responsabilidad de las capas

### `api/`

Contiene únicamente aquello que otros módulos pueden utilizar: fachadas, comandos, consultas, eventos y modelos públicos estables.

### `domain/`

Contiene las entidades, reglas de negocio, casos de uso e interfaces de repositorio. No debe depender de Flutter, Supabase ni detalles de almacenamiento.

### `data/`

Implementa los repositorios y se comunica con PostgreSQL, Supabase Storage o almacenamiento local. Sus modelos representan datos externos y los mappers los convierten en entidades del dominio.

### `presentation/`

Contiene páginas, componentes visuales y controladores de estado. Debe utilizar casos de uso o la API pública, no acceder directamente a la base de datos.

### `di/`

Conecta interfaces con implementaciones mediante Riverpod. Los providers de
infraestructura deben vivir en `di/`; los controladores de estado propios de
la interfaz deben vivir en `presentation/controllers/`. La capa `domain` no
debe importar Riverpod.

## 5. Interfaz pública del módulo

El archivo índice solo exportará contratos estables:

```dart
// product_module.dart
export 'api/product_api.dart';
export 'api/product_summary.dart';
export 'api/product_routes.dart';
```

No debe exportar implementaciones internas como:

```dart
// No permitido como API pública
export 'data/repositories/product_repository_impl.dart';
export 'data/data_sources/supabase_product_data_source.dart';
export 'di/product_module_di.dart';
```

Esto permite cambiar el almacenamiento o la gestión de estado de un módulo sin obligar a modificar los demás.

## 6. Flujo habitual

1. `presentation` solicita una operación a un caso de uso de `domain`.
2. El caso de uso depende de una interfaz ubicada en `domain/repositories`.
3. `data/repositories` implementa esa interfaz y coordina sus fuentes de datos.
4. `data/mappers` transforma los modelos externos en entidades del dominio.
5. `di` conecta las interfaces con sus implementaciones.
6. Las interacciones entre módulos se realizan exclusivamente mediante `api/`.

### Composición de la aplicación

`main.dart` es la raíz de composición y puede construir las implementaciones de
repositorios e inyectarlas en Riverpod. El router global puede registrar rutas
públicas ofrecidas por cada módulo. Estas excepciones no autorizan que un módulo
importe el `data/`, `di/` o `presentation/` interno de otro módulo.

Cada módulo debe exponer los contratos, modelos públicos y rutas que necesiten
otros módulos desde `api/`. Un cambio interno no debe obligar a modificar a sus
consumidores.

### Contrato obligatorio entre módulos

`MODULE_SECURITY_CONTRACT.md` define de forma normativa qué puede importar,
consultar, ordenar y publicar un módulo; cómo se protegen las escrituras, las
transacciones cruzadas, las credenciales, RLS, auditoría e información sensible.
Las reglas de ese contrato tienen la misma obligatoriedad que esta estructura.

Un SDD puede restringir aún más su API, pero no puede debilitar ese contrato.
Una excepción temporal debe registrarse como deuda técnica con responsable,
riesgo y condición de retiro; no se convierte en precedente arquitectónico.

## 7. Pruebas

Las pruebas viven en el directorio estándar `test/` y reflejan la estructura de `lib/`:

```text
test/modules/product/
├── domain/
├── data/
└── presentation/

test/modules/inventory/
├── domain/
├── data/
└── presentation/
```

Esto mantiene separados los módulos y permite ejecutar todas las pruebas con `flutter test` o un módulo específico con `flutter test test/modules/product`.

## 8. Convenciones de nomenclatura

| Tipo | Convención | Ejemplo |
|---|---|---|
| Archivos | `snake_case.dart` | `product_page.dart` |
| Clases | `PascalCase` | `ProductPage` |
| Métodos y variables | `camelCase` | `loadProducts` |
| Constantes | `SCREAMING_SNAKE_CASE` | `MAX_ITEMS` |
| Widgets reutilizables | Sufijo `Widget` | `ProductCardWidget` |

## 9. Excepciones

- Un módulo exclusivamente visual puede omitir `domain` y `data` si no contiene reglas de negocio ni acceso a datos.
- Una integración utilizada solo por un módulo debe permanecer dentro de ese módulo.
- Una integración compartida por varios módulos puede vivir en `core`, siempre que no contenga reglas específicas de negocio.

## 10. Documentación por módulo

Cada módulo funcional debe contar con un documento de diseño en la raíz del
proyecto, usando la convención `SDD_Modulo_<Nombre>.md`. El documento debe
distinguir expresamente:

- comportamiento implementado;
- decisiones vigentes;
- alcance futuro;
- deuda técnica o decisiones pendientes.

Una función futura no debe describirse como implementada. Cuando el código se
aparte temporalmente de estas convenciones, la diferencia se registra como
deuda técnica y no como una nueva regla arquitectónica.

Todo formulario nuevo o modificado debe incluir pruebas de presentación en
`test/` antes de considerarse completo. Si el formulario permite CRUD, las
pruebas cubren crear, leer/cargar valores existentes, actualizar y eliminar o
desactivar según corresponda. Si sólo permite CRU, sólo se prueban esas tres
operaciones. Si el formulario no es CRUD ni CRU, las pruebas cubren la
operación para la que fue creado. En todos los casos deben comprobar que los
datos inválidos no ejecutan comandos, que el formulario permanece abierto o
visible, que los errores aparecen junto al campo afectado cuando aplique y que
cada campo acepta sólo el tipo de dato esperado.

Todos los documentos operativos generados por cualquier módulo deben cumplir
`DOCUMENT_STANDARDS.md`, incluyendo las salidas PDF A4 y ticket térmico de
80 mm y la impresión ESC/POS directa por Bluetooth o USB. Los módulos conservan
sus reglas; el renderizado común no contiene lógica de negocio. El catálogo
comercial de Productos queda explícitamente fuera de esa obligación y se
representa sólo como PDF.

## 11. Estado modular actual

| Módulo o área | Estado funcional | Documento | Conformidad estructural |
|---|---|---|---|
| Productos | Funcional | `SDD_Modulo_Productos.md` | Aislado mediante API pública |
| Inventario | Funcional | `SDD_Modulo_Inventario.md` | Aislado mediante API pública |
| Ventas | Parcial: agentes y clientes funcionales; documentos comerciales con modelo y RPC sin UI de creación | `SDD_Modulo_Ventas.md` | Aislado mediante API pública |
| Configuración | Funcional | `SDD_Modulo_Configuracion.md` | Aislado mediante API pública |
| Pagos y Recibos | Funcional en su alcance actual: pagos, métodos, cuentas, gastos, traslados y reembolsos | `SDD_Modulo_Pagos.md` | Aislado mediante API pública |
| Autorización | No implementado; solo borrador de spec | `.specs/modules/authorization/` | Módulo futuro |

Los directorios `lib/core/device`, `lib/core/identity`, `lib/core/navigation`,
`lib/core/offline`, `lib/shared/navigation` y `lib/modules/payments` existen en
el código y forman parte del árbol real.

### Deuda técnica reconocida

- Las API públicas de Productos e Inventario exponen temporalmente algunas
  entidades de dominio como modelos estables; podrán sustituirse por DTO
  públicos si ambos dominios divergen. Ver `02-tech-debt-plan.md` fase 3.
- `main.dart`, como raíz de composición autorizada, todavía construye las
  implementaciones Supabase y registra sus overrides de Riverpod.
- El nombre histórico `catalog_agents` quedó resuelto: la tabla se renombró a
  `sales_agents` y `catalog_agents` sobrevive solo como vista de
  compatibilidad sin escritura. Falta retirar esa vista.
- `sales_module.dart` no exporta todo lo que `api/` contiene, y `main.dart`
  importa `api/sales_invoice_api.dart` y `api/quote_api.dart` directamente.
- `inventory_module.dart` exporta `di/inventory_providers.dart`, contra la
  prohibición de exponer providers internos de Riverpod.
- La preferencia de tema y la configuración técnica de conexión permanecen en
  `core/configuration`; no son datos comerciales del módulo Configuración.
- `inventory_transactions` todavía acepta `INSERT` directo de `anon` y
  `authenticated`; esquivar el flujo documental es posible hasta el bloque 1D.

Estas diferencias se corregirán de manera incremental, conservando pruebas y
puntos de restauración en Git antes de cada cambio estructural.

## 12. Notas de cambio

- Se corrigió el título anterior «Módulo de Convección» por «Convenciones de Estructura Modular».
- Se eliminó la duplicación entre `model`, `repository`, `data` y `widgets`.
- Se trasladaron las pruebas al directorio estándar `test/`, conservando la separación por módulo.
- Se restringió la interfaz pública para impedir dependencias entre módulos sobre implementaciones internas.
- Se incorporaron Inventario y Ventas al mapa modular y se documentó el estado
  transitorio previo a su aislamiento completo.
- Se estableció un SDD obligatorio por módulo funcional.
- Se aislaron Productos, Inventario y Ventas mediante API y rutas públicas; los
  agentes fueron trasladados desde Configuración al módulo de Ventas.
- Se extrajeron empresa, catálogo, logo y presentaciones al módulo Configuración;
  `core/configuration` quedó reservado para preferencias técnicas locales.
