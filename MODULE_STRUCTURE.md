# Convenciones de Estructura Modular del Proyecto

## 1. Principios generales

- La aplicación será una aplicación de escritorio construida con Flutter y Dart.
- Cada módulo funcional vive bajo `lib/modules/<module_name>/`.
- Los nombres de los módulos se escriben en `snake_case` y en singular (por ejemplo, `product` e `inventory`).
- Todos los módulos siguen la misma arquitectura base. Una carpeta puede omitirse únicamente cuando el módulo no tenga esa responsabilidad.
- Cada módulo expone una única interfaz pública mediante `api/` y su archivo índice `<module_name>_module.dart`.
- Los demás módulos no deben importar implementaciones internas desde `data/`, `presentation/` o `di/`.
- Las tablas, columnas, variables y nombres técnicos se escriben en inglés. La interfaz y la documentación funcional se mantienen en español.
- Cualquier excepción debe documentarse y justificarse en la sección «Notas de cambio».

## 2. Estructura general de la aplicación

```text
lib/
├── core/                         # Capacidades técnicas compartidas
│   ├── audit/
│   ├── configuration/
│   ├── database/
│   ├── errors/
│   └── utilities/
├── shared/                       # Tema y componentes visuales compartidos
│   ├── theme/
│   └── widgets/
└── modules/
    ├── product/
    └── inventory/

test/
├── core/
└── modules/
    ├── product/
    └── inventory/
```

`core` y `shared` no son módulos de negocio. Solo deben contener elementos genuinamente reutilizables por varios módulos.

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

## 10. Notas de cambio

- Se corrigió el título anterior «Módulo de Convección» por «Convenciones de Estructura Modular».
- Se eliminó la duplicación entre `model`, `repository`, `data` y `widgets`.
- Se trasladaron las pruebas al directorio estándar `test/`, conservando la separación por módulo.
- Se restringió la interfaz pública para impedir dependencias entre módulos sobre implementaciones internas.
