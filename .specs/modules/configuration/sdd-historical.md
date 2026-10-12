# SDD — Módulo de Configuración

## 1. Propósito

El módulo centraliza parámetros comerciales compartidos que no pertenecen a
Productos, Inventario ni Ventas. Expone una API pública para que los demás
módulos consulten la configuración sin depender de Supabase ni de su interfaz.

La conexión local a Supabase (`AppConfiguration`) y la preferencia visual del
equipo (`ThemeModeController`) son capacidades técnicas y permanecen en
`core/configuration`.

## 2. Alcance implementado

- moneda, decimales, impuesto, inclusión del impuesto y redondeo;
- nombre de empresa y texto de métodos de pago;
- logo corporativo usado por el catálogo;
- preferencias persistentes del catálogo: tarjetas por página, colores,
  ajuste de imagen y agente seleccionado;
- presentaciones dinámicas de producto, con creación, cambio de nombre y
  desactivación segura;
- modo de operación `TEST` o `PRODUCTION`;
- limpieza irreversible de datos de prueba, visible únicamente para el equipo
  registrado como superadministrador;
- ruta pública `/settings` y providers públicos de solo contrato.

## 3. Persistencia

- `app_settings` conserva una única configuración comercial compartida.
- `packaging_presentations` conserva las presentaciones disponibles. Las
  presentaciones se desactivan con `is_active = false`; no se eliminan
  físicamente para proteger productos históricos y documentos relacionados.
- el logo se almacena en el bucket `catalog-assets` y su URL en
  `app_settings.catalog_logo_url`.
- los cambios registran fecha, actor, nombre del equipo e identificador del
  equipo cuando la tabla lo permite.

## 4. Arquitectura

```text
lib/modules/configuration/
├── api/
├── domain/
│   ├── entities/
│   └── repositories/
├── data/repositories/
├── presentation/pages/
├── di/
└── configuration_module.dart
```

Otros módulos deben importar `configuration_module.dart`; no deben importar
archivos internos de `data`, `presentation` ni `di`. `main.dart` puede construir
la implementación Supabase porque es la raíz de composición de la aplicación.

## 5. Reglas vigentes

- La moneda de referencia de toda la aplicación se configura aquí con el
  nombre y símbolo de la moneda de la empresa. Las pantallas y documentos
  comerciales expresan sus importes en esa moneda; no capturan ni muestran
  tipos de cambio.
- Pagos es el único módulo que usa tipo de cambio: solo cuando recibe dinero en
  una moneda distinta a la moneda de referencia configurada. Debe conservar la
  moneda y el importe recibidos, registrar la tasa aplicada y calcular el
  equivalente en la moneda de referencia. No se usa para cotizaciones, pedidos,
  facturas, inventario, productos ni otros módulos.
- El modo oscuro es el valor local predeterminado; la preferencia se conserva
  por equipo y no se guarda en Supabase.
- Las presentaciones son dinámicas y obligatorias para todo producto.
- Una presentación activa puede desactivarse desde Configuración sólo si no hay
  productos activos asociados. Si está en uso, el usuario debe cambiar primero
  esos productos a otra presentación.
- Los formularios de configuración deben tener pruebas de presentación que
  cubran la operación real y validaciones. La cobertura actual comprueba que
  configuración comercial guarda por la API pública, que decimales no
  normalizados no se guardan, que una presentación vacía mantiene el diálogo
  abierto sin crear registros, que una presentación existente carga y actualiza
  por la API pública, y que una presentación existente puede desactivarse por
  la API pública.
- Logo y purga de datos de prueba no se marcan como formularios completos hasta
  contar con pruebas UI de selección/reemplazo de imagen y confirmación
  destructiva respectivamente.
- La transición a producción y eliminación de datos de prueba solo puede
  ejecutarse desde el equipo superadministrador.
- Productos consume preferencias y presentaciones a través de la API pública
  de Configuración.
- Ventas es propietario de los agentes; Configuración solo conserva el agente
  elegido para el catálogo.

## 6. Alcance futuro

- autenticación y autorización por usuario, reemplazando la identidad temporal
  del equipo;
- permisos administrativos por rol;
- configuración de múltiples empresas o sucursales, si el negocio lo requiere;
- historial de versiones y restauración controlada de parámetros comerciales.

## 7. Deuda técnica

- `app_settings` es una fila global identificada por un booleano histórico;
  puede migrarse a una clave explícita si aparecen múltiples empresas.
- la descarga del logo usa `HttpClient` desde el repositorio; puede extraerse a
  una fuente HTTP si se requiere reutilización o pruebas de integración finas.
- las políticas RLS siguen siendo provisionales hasta incorporar autenticación
  y roles reales.

## 8. Puerta obligatoria antes de producción

Durante el desarrollo local, el primer equipo puede reclamar temporalmente la
condición de superadministrador mediante una RPC limitada y los roles locales
pueden ejecutar los comandos públicos. Esta autorización fue aceptada sólo para
desarrollo y debe revertirse al implementar Autenticación.

La lista vinculante de revocaciones, migración de identidad y pruebas está en
`.specs/modules/authorization/production-gate.md`. La aplicación no se considerará lista
para producción mientras esa puerta permanezca abierta.
