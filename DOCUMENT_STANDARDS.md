# Estándar transversal de documentos

## 1. Propósito

Este estándar aplica a todos los documentos creados por SERP, sin importar el
módulo propietario: facturas, pedidos, cotizaciones, consignaciones, recibos,
pagos, gastos, reembolsos, notas de crédito, compras, devoluciones, ajustes,
traslados, conteos, aperturas, cierres, reportes y comprobantes numerados.

Cada SDD define el contenido y reglas de su documento. Este archivo define las
salidas visuales, el comportamiento común y las responsabilidades técnicas.

## 2. Salidas obligatorias

Todo documento confirmado debe poder guardarse localmente en dos estilos PDF:

1. **A4:** archivo formal, correo e impresión convencional.
2. **Ticket térmico de 80 mm:** entrega e impresión rápida.

La interfaz mostrará una acción coherente:

```text
Guardar PDF
├── Documento A4
└── Ticket térmico 80 mm
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

## 4. PDF frente a impresión directa

### PDF ticket

- genera un archivo portable;
- puede compartirse, archivarse o abrirse con el sistema operativo;
- utiliza el diálogo normal de impresión;
- constituye la primera integración obligatoria.

### ESC/POS directo

- envía comandos a la impresora sin PDF intermedio;
- requiere configurar Bluetooth o USB;
- depende de controladores, permisos y compatibilidad del sistema operativo;
- será posterior y reutilizará el mismo modelo documental.

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
- Una capacidad compartida administra papel, tipografía, encabezados, pies, QR
  y guardado local.
- La capacidad compartida no contiene reglas de negocio de los módulos.
- Las plantillas no consultan repositorios ni Supabase directamente.
- A4 y ticket se generan desde el mismo modelo para impedir contradicciones.

La ubicación prevista es `lib/core/documents/`; los adaptadores específicos
permanecen dentro de cada módulo.

## 10. Configuración

Configuración permitirá definir identidad, colores A4, campos opcionales,
perfil térmico, ancho de papel e impresión, logo, firma, QR y directorio sugerido
cuando el sistema operativo lo permita.

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

## 12. Alcance futuro

- impresión ESC/POS directa por USB o Bluetooth;
- perfiles adicionales de 58 mm y otros anchos;
- envío por correo, WhatsApp u otros canales;
- firmas criptográficas o validación remota por QR;
- almacenamiento remoto opcional de copias inmutables.
