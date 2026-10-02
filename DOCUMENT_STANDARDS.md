# Estándar transversal de documentos

## 1. Propósito

Este estándar aplica a todos los documentos operativos creados por SERP, sin
importar el módulo propietario: facturas, pedidos, cotizaciones,
consignaciones, recibos, pagos, gastos, reembolsos, notas de crédito, compras,
devoluciones, ajustes, traslados, conteos, aperturas, cierres, reportes y
comprobantes numerados.

El catálogo comercial de Productos es una pieza de presentación y venta, no un
documento operativo confirmado. Por decisión funcional, el catálogo se entrega
únicamente como PDF y no está obligado a generar ticket térmico de 80 mm ni
salida ESC/POS directa.

Cada SDD define el contenido y reglas de su documento. Este archivo define las
salidas visuales, el comportamiento común y las responsabilidades técnicas.

## 2. Salidas obligatorias

Todo documento confirmado debe ofrecer tres salidas:

1. **A4:** archivo formal, correo e impresión convencional.
2. **Ticket térmico de 80 mm:** entrega e impresión rápida.
3. **Impresión ESC/POS directa:** envío a una impresora térmica configurada por
   Bluetooth o USB, sin generar ni abrir primero un PDF.

La interfaz mostrará una acción coherente:

```text
Guardar PDF
├── Documento A4
└── Ticket térmico 80 mm

Imprimir ticket
└── Impresora ESC/POS configurada
```

Un documento pendiente puede generar una vista previa marcada `BORRADOR`. Un
documento anulado conserva su número y muestra `ANULADO`. Un comprobante offline
sin sincronizar muestra `PROVISIONAL` y no simula ser definitivo.

## 3. Perfil térmico inicial

El primer perfil soportado corresponde a la impresora portátil Rongta RPP300:

| Propiedad | Valor |
|---|---|
| Tecnología | Térmica directa |
| Papel | 80 mm |
| Ancho imprimible | 72 mm |
| Resolución | 203 dpi |
| Velocidad nominal | 90 mm/s |
| Emulación | ESC/POS |
| Conectividad | Bluetooth y USB |

El PDF térmico utilizará una página de 80 mm, contenido limitado a 72 mm y
márgenes laterales de 4 mm. La altura se adaptará al contenido para aprovechar
el rollo continuo y evitar páginas vacías.

## 4. PDF e impresión directa

### PDF ticket

- genera un archivo portable;
- puede compartirse, archivarse o abrirse con el sistema operativo;
- utiliza el diálogo normal de impresión;
- constituye la primera integración obligatoria.

### ESC/POS directo

- envía comandos a la impresora sin PDF intermedio;
- es una salida obligatoria para todo tipo de documento confirmado;
- admite perfiles de conexión Bluetooth y USB;
- utiliza la impresora predeterminada configurada o permite elegir otra;
- valida conexión, permisos, ancho y capacidades antes de enviar;
- informa claramente los estados conectando, imprimiendo, completado y error;
- permite reintentar sin volver a confirmar ni duplicar el documento;
- reutiliza el mismo modelo documental histórico usado por A4 y ticket PDF;
- no consulta repositorios ni vuelve a calcular importes durante la impresión.

La ausencia o desconexión de la impresora no impide confirmar un documento. El
documento queda guardado y puede imprimirse posteriormente. Una reimpresión se
identifica como tal cuando la política del documento lo requiera.

### Transporte y comandos ESC/POS

- El renderizador produce una secuencia ESC/POS independiente del transporte.
- Los adaptadores Bluetooth y USB solo descubren, conectan y transmiten bytes;
  no contienen reglas de negocio ni diseño documental.
- Bluetooth utiliza dispositivos previamente emparejados por el sistema
  operativo cuando la plataforma lo exija.
- USB conserva identificadores estables de fabricante, producto y, cuando
  exista, número de serie; nunca depende únicamente del nombre visible.
- Los comandos respetan las capacidades declaradas por el perfil: ancho, juego
  de caracteres, corte, QR, imagen y apertura de gaveta.
- Una capacidad no soportada se degrada de manera explícita y legible, sin
  perder líneas, cantidades, totales, número o estado del documento.

## 5. Contenido común

Todo documento debe conservar una representación histórica de:

- empresa y logo;
- tipo, número, fecha y estado;
- usuario, agente o responsable;
- tercero relacionado, cuando exista;
- referencia externa y documento relacionado;
- líneas, cantidades, precios o importes pertinentes;
- moneda, impuestos, redondeo y tipo de cambio histórico cuando apliquen;
- origen y destino logístico o monetario cuando apliquen;
- observaciones, firma visual y QR cuando correspondan.

Los datos históricos no cambian porque después se edite el producto, cliente,
empresa, agente o configuración.

## 6. Plantilla A4

- tamaño ISO A4;
- encabezado con identidad de empresa y datos documentales;
- encabezados de tabla repetidos al cambiar de página;
- numeración `Página X de Y` cuando haya varias páginas;
- totales y firmas correctamente agrupados;
- márgenes para impresión convencional;
- colores con contraste en color y escala de grises;
- líneas sin cortes evitables entre páginas.

## 7. Plantilla térmica de 80 mm

- diseño principalmente monocromático;
- tipografía legible a 203 dpi;
- logo simplificado o monocromático;
- información secundaria compacta;
- SKU, descripción y cantidad o importe claramente separados;
- nombres largos en varias líneas sin reducir excesivamente la fuente;
- separadores simples compatibles con impresión térmica;
- QR legible dentro del ancho imprimible;
- altura continua determinada por el contenido;
- sin fondos sólidos ni elementos que consuman o recalienten el cabezal.

## 8. Nombres y almacenamiento

```text
<TIPO>_<NUMERO>_<FECHA>_A4.pdf
<TIPO>_<NUMERO>_<FECHA>_TICKET80.pdf
```

Ejemplos:

```text
TRASLADO_TRA-00000152_2026-09-29_A4.pdf
RECIBO_TL-RC-000125_2026-09-29_TICKET80.pdf
```

Los archivos se generan localmente y no se suben automáticamente a Supabase.
El usuario elige el destino con el selector estándar del sistema.

## 9. Arquitectura compartida

- Cada módulo es propietario de sus documentos, reglas y datos históricos.
- Cada módulo transforma su documento en un modelo de impresión estable.
- Una capacidad compartida administra papel, tipografía, encabezados, pies, QR,
  guardado local, generación ESC/POS y selección de transporte.
- La capacidad compartida no contiene reglas de negocio de los módulos.
- Las plantillas no consultan repositorios ni Supabase directamente.
- A4 y ticket se generan desde el mismo modelo para impedir contradicciones.

La ubicación prevista es `lib/core/documents/`; los adaptadores específicos
permanecen dentro de cada módulo.

La separación interna prevista es:

```text
lib/core/documents/
├── models/              # Modelo documental neutral
├── pdf/                 # Renderizadores A4 y ticket 80 mm
└── esc_pos/
    ├── renderer/        # Modelo documental -> bytes ESC/POS
    ├── profiles/        # Capacidades de Rongta y futuras impresoras
    └── transports/      # Bluetooth y USB
```

## 10. Configuración

Configuración permitirá definir identidad, colores A4, campos opcionales,
perfil térmico, ancho de papel e impresión, conexión Bluetooth o USB, impresora
predeterminada, logo, firma, QR y directorio sugerido cuando el sistema
operativo lo permita.

El perfil inicial será `Rongta RPP300 - 80 mm / imprimible 72 mm`.

## 11. Validación obligatoria

Cada nuevo documento debe probar:

- PDF A4 con cero, una y muchas líneas;
- ticket de 80 mm con nombres cortos y largos;
- caracteres españoles y símbolos monetarios;
- múltiples páginas A4 sin desbordamiento;
- altura térmica suficiente sin cortes;
- estados borrador, confirmado, anulado y provisional cuando apliquen;
- apertura del PDF en macOS;
- impresión física en la Rongta RPP300 antes de dar por terminada la plantilla.
- impresión directa por Bluetooth y USB en la Rongta RPP300;
- impresora apagada, desconectada, sin papel y sin permisos;
- reconexión y reimpresión sin duplicar ni modificar el documento;
- equivalencia de datos entre A4, ticket PDF y ESC/POS directo.

## 12. Definición de formulario listo para uso

Esta sección es **normativa y obligatoria** para todos los módulos actuales y
futuros. Un formulario **NO** se considera listo para uso ni se registra como
tarea completada hasta que cumple **todas** las condiciones siguientes.

### 12.1 Pruebas de operaciones obligatorias

Todo formulario debe tener pruebas que verifiquen las operaciones que realmente
permite. La cobertura se define por capacidad, no por una exigencia artificial
de CRUD completo.

| Operación | Descripción |
|---|---|
| **Create** | Crear un registro con datos válidos y verificar que se persiste correctamente. |
| **Read** | Cargar un registro existente y verificar que todos los campos se muestran con los valores correctos. |
| **Update** | Modificar un registro existente y verificar que los cambios se persisten correctamente. |
| **Delete** | Eliminar o desactivar un registro y verificar que el estado es correcto. |

Si el formulario sólo permite **CRU**, se prueban únicamente Create, Read y
Update. Si sólo permite **Create**, **Update**, **Delete/desactivar** o una
acción específica, se prueba esa operación y no se exige CRUD completo. Si el
formulario fue creado para generar, importar, exportar, confirmar, seleccionar,
ordenar, calcular o configurar, la prueba debe cubrir esa operación real.

### 12.2 Pruebas de validación de campos y tipos de datos

Todo formulario debe tener pruebas que verifiquen:

| Tipo de validación | Descripción |
|---|---|
| **Campos obligatorios** | Verificar que el formulario no se envía si faltan campos requeridos. |
| **Tipos de datos** | Verificar que cada campo acepta solo el tipo de dato correcto (texto, número, fecha, etc.). |
| **Longitudes** | Verificar límites mínimos y máximos de caracteres. |
| **Rangos numéricos** | Verificar valores mínimos y máximos para campos numéricos. |
| **Formato** | Verificar formatos específicos (email, teléfono, SKU, etc.). |
| **Valores únicos** | Verificar que campos únicos (SKU, email, etc.) no aceptan duplicados. |
| **Listas de selección** | Verificar que los dropdowns solo aceptan valores de la lista. |

### 12.3 Comportamiento del formulario

Las pruebas deben verificar que:

- El formulario **no se cierra** cuando hay errores de validación;
- Los errores se muestran **dentro del formulario**, junto al campo afectado;
- El formulario **no ejecuta comandos de guardado** cuando hay errores;
- El formulario **limpia los errores** cuando el usuario corrige el campo;
- El formulario **previene envíos duplicados** durante el proceso de guardado.

### 12.4 Criterio de completitud

Un formulario se registra como **tarea completada** únicamente cuando:

1. Todas las pruebas de sus operaciones reales pasan;
2. Todas las pruebas de validación pasan;
3. Las pruebas de comportamiento pasan;
4. Las pruebas están incluidas en el directorio `test/` del módulo correspondiente.

Si un formulario no tiene estas pruebas, **NO** se considera terminado y se
deben crear las pruebas **una por una** antes de marcar la tarea como completada.

### 12.5 Aplicación a módulos actuales y futuros

Esta regla aplica a:

- Productos: formulario de producto, categorías, promociones, catálogo PDF;
- Inventario: documentos de inventario, bodegas, ubicaciones;
- Ventas: agentes, clientes, cotizaciones, pedidos, facturas, devoluciones, consignaciones;
- Configuración: ajustes, presentaciones, preferencias de catálogo;
- Pagos: pagos, recibos, gastos, reembolsos, traslados (cuando se implementen);
- Cualquier módulo futuro que se agregue al proyecto.

## 13. Alcance futuro

- perfiles adicionales de 58 mm y otros anchos;
- envío por correo, WhatsApp u otros canales;
- firmas criptográficas o validación remota por QR;
- almacenamiento remoto opcional de copias inmutables.
