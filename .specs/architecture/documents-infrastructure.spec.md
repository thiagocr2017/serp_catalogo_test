# Spec de arquitectura: infraestructura compartida de documentos

**Estado:** Aprobado / Implementado
**Fecha:** 2026-10-04
**Propietario:** `core/documents` de la aplicación
**Normas relacionadas:**
- `.specs/architecture/document-standards.md`
- `.specs/00-project-context.md`
- `.specs/architecture/module-structure.md`
- `.specs/architecture/module-security-contract.md`

## 1. Propósito y alcance

Esta capacidad proporciona una infraestructura neutral y desacoplada para representar,
renderizar, guardar e imprimir documentos operativos de SERP. Permite que
Productos, Inventario, Ventas, Pagos y Configuración generen salidas consistentes
sin compartir reglas internas ni acceder entre sí a sus capas de datos o repositorios.

Incluye:
- Un modelo de documento agnóstico (`DocumentModel`) que captura de manera inmutable
  los datos históricos de cualquier documento de negocio (emisor, receptor, líneas, totales, metadatos).
- Tres motores de renderizado independientes:
  1. **A4 PDF (`A4PdfRenderer`):** Documento formal multipágina usando el paquete `pdf`.
  2. **Ticket térmico de 80 mm (`Ticket80mmPdfRenderer`):** Salida PDF en rollo continuo de 80 mm (72 mm imprimible, 4 mm margen) optimizado para impresión térmica.
  3. **Comandos ESC/POS directos (`EscPosRenderer`):** Secuencia binaria determinista de bytes enviada directamente al cabezal térmico sin PDF intermedio.
- Perfil térmico de impresora:
  - Clase base extensible `PrinterProfile`.
  - Perfil inicial `RongtaRpp300Profile` (80 mm ancho de papel, 72 mm imprimible, 203 DPI, 576 dots/línea, 48 caracteres/línea en Fuente A, 64 en Fuente B).
- Contrato de transportes de impresión (`PrintTransport`):
  - Interfaces y abstracciones para Bluetooth y USB, con implementación de simulación / pruebas (`MockPrintTransport`).
- Nomenclatura normalizada de archivos PDF locales:
  - `<TIPO>_<NUMERO>_<FECHA>_A4.pdf`
  - `<TIPO>_<NUMERO>_<FECHA>_TICKET80.pdf`

No incluye:
- Lógica o reglas de negocio específicas de un módulo (precios, stock, validaciones fiscales).
- Consultas a Supabase, base de datos local o repositorios desde los renderizadores.
- El catálogo comercial de productos (que se mantiene exclusivamente como PDF A4).

---

## 2. Modelo de documento agnóstico (`DocumentModel`)

El modelo reside en `lib/core/documents/models/` y está compuesto por estructuras inmutables:

### 2.1 `DocumentModel`
- `metadata`: `DocumentMetadata` (tipo de documento, número oficial, fecha de emisión, fecha de vencimiento/entrega opcional, estado).
- `issuer`: `DocumentParty` (emisor / empresa: nombre, nombre fiscal, ID fiscal / NIT / RFC, dirección, teléfono, correo, logo en bytes opcional).
- `recipient`: `DocumentParty?` (receptor / cliente / proveedor / bodega destino: nombre, identificación, dirección, etc.).
- `responsible`: `DocumentParty?` (agente comercial, despachador, cajero o usuario responsable).
- `lines`: `List<DocumentLine>` (lista inmutable y ordenada de renglones).
- `totals`: `DocumentTotals` (moneda, subtotal, descuentos, impuestos desglosados, cargos, redondeo, total final).
- `notes`: `String?` (observaciones o condiciones comerciales).
- `termsAndConditions`: `String?` (términos legales o políticas de devolución al pie).
- `qrData`: `String?` (contenido a codificar en código QR para validación o URL).
- `extraAttributes`: `Map<String, String>` (atributos adicionales como bodega origen, transporte preferido, orden de compra externa, etc.).

### 2.2 `DocumentMetadata`
- `documentType`: Tipo de documento (ej. `INVOICE`, `QUOTE`, `ORDER`, `RECEIPT`, `ADJUSTMENT`, `TRANSFER`).
- `documentNumber`: Número correlativo formateado (ej. `FAC-000124`, `TRA-00000152`).
- `issueDate`: Fecha y hora de emisión.
- `status`: `DocumentStatus` (`draft`, `confirmed`, `voided`, `provisional`).
- `externalReference`: Referencia a documento origen o número externo.

### 2.3 `DocumentParty`
- `name`: Nombre comercial o personal.
- `legalName`: Razón social fiscal (si difiere).
- `taxId`: Cédula jurídica o identificación fiscal.
- `address`: Dirección física.
- `phone`: Teléfono de contacto.
- `email`: Correo electrónico.
- `logoBytes`: `Uint8List?` (logotipo en bytes PNG/JPEG para impresión A4/Ticket).

### 2.4 `DocumentLine`
- `itemCode`: Código o SKU del producto.
- `description`: Descripción o nombre del ítem.
- `quantity`: Cantidad (soporta decimales para peso/volumen).
- `unit`: Unidad de medida (ej. `UND`, `KG`, `MTR`).
- `unitPrice`: Precio unitario base.
- `discountAmount`: Monto total de descuento en la línea.
- `taxAmount`: Monto total de impuestos en la línea.
- `taxRate`: Porcentaje de impuesto (ej. 13% -> 0.13).
- `total`: Importe total de la línea (`quantity * unitPrice - discountAmount + taxAmount` o importe neto acordado).
- `notes`: Nota o detalle adicional de la línea (lote, serie, etc.).

### 2.5 `DocumentTotals`
- `currencyCode`: Código de moneda ISO (ej. `CRC`, `USD`).
- `currencySymbol`: Símbolo visual (ej. `₡`, `$`).
- `subtotal`: Subtotal antes de descuentos e impuestos.
- `discountTotal`: Suma de descuentos.
- `taxTotal`: Suma de impuestos.
- `taxBreakdown`: `List<DocumentTaxItem>` desglose opcional de impuestos por tasa.
- `rounding`: Ajuste por redondeo monetario.
- `grandTotal`: Total neto final a pagar o registrar.
- `exchangeRate`: Tipo de cambio histórico utilizado (si aplica).

---

## 3. Motores de salida

### 3.1 Renderizador A4 PDF (`A4PdfRenderer`)
- Utiliza `package:pdf/pdf.dart` y `package:pdf/widgets.dart`.
- Formato de página `PdfPageFormat.a4`.
- Márgenes de 20 mm para impresión convencional en oficina.
- Encabezado institucional con logotipo, datos de la empresa y tarjeta resumen del documento.
- Datos del receptor y condiciones en bloques limpios de dos columnas.
- Tabla de líneas con cabecera repetida en saltos de página (`MultiPage`).
- Resumen de totales alineado a la derecha, con desglose de impuestos y notas.
- Indicador de pie de página `"Página X de Y"` y marca de agua / banner para estados especiales:
  - `draft`: Banner o marca `BORRADOR`.
  - `voided`: Banner o marca `ANULADO`.
  - `provisional`: Banner o marca `PROVISIONAL`.
- Genera `PdfOutput` con bytes y nombre de archivo sugerido: `<TIPO>_<NUMERO>_<FECHA>_A4.pdf`.

### 3.2 Renderizador Ticket 80mm PDF (`Ticket80mmPdfRenderer`)
- Formato de página personalizado: Ancho fijo de 80 mm (`80 * PdfPageFormat.mm`), con contenido útil de 72 mm y márgenes laterales de 4 mm.
- Altura continua calculada automáticamente o multi-sección sin espacios en blanco innecesarios.
- Tipografía limpia, tamaño de texto proporcional y alto contraste (sin fondos oscuros sólidos que consuman calor del cabezal térmico).
- Información compacta pero legible:
  - Encabezado con datos del emisor y documento.
  - Separadores punteados o continuos de bajo consumo térmico.
  - Líneas con cantidad, descripción con salto de línea si es largo, precio y total alineado a la derecha.
  - Bloque de totales claro y destacado.
  - Código QR opcional centrado al final si `qrData` está presente.
  - Mensaje de estado destacado si no es confirmado.
- Genera `PdfOutput` con nombre de archivo sugerido: `<TIPO>_<NUMERO>_<FECHA>_TICKET80.pdf`.

### 3.3 Generador de Comandos ESC/POS directos (`EscPosRenderer`)
- Convierte el `DocumentModel` en una secuencia binaria (`Uint8List`) de comandos ESC/POS estándar.
- No utiliza PDFs intermedios.
- Aplica las restricciones y capacidades del `PrinterProfile` inyectado:
  - Inicialización: `ESC @` (`0x1B, 0x40`).
  - Alineación: `ESC a n` (`0x1B, 0x61, n`).
  - Énfasis / Negrita: `ESC E n` (`0x1B, 0x45, n`).
  - Tamaño de texto (Doble ancho / Doble alto): `GS ! n` (`0x1D, 0x21, n`).
  - Tabulación / Distribución de columnas de texto de ancho fijo según los caracteres por línea del perfil (48 caracteres en Fuente A).
  - Códigos QR nativos ESC/POS (Modelo 2) con degradación segura si la impresora no lo soporta.
  - Avance de papel (`ESC d n` o múltiples `LF`).
  - Corte de papel (`GS V n`) con soporte de corte total o parcial según capacidades.
- Manejo seguro de caracteres especiales en español (`á`, `é`, `í`, `ó`, `ú`, `ñ`, `Ñ`, etc.) mediante codificación adecuada (CP850 / CP437 / UTF-8 con fallback).

---

## 4. Perfil de impresora térmica Rongta RPP300

Ubicado en `lib/core/documents/profiles/rongta_rpp300_profile.dart`:

| Parámetro | Valor |
|---|---|
| Nombre del perfil | `Rongta RPP300` |
| Tipo de impresión | Térmica directa |
| Ancho de papel | 80 mm |
| Ancho imprimible | 72 mm |
| Resolución | 203 DPI |
| Puntos por línea | 576 dots |
| Caracteres por línea (Font A) | 48 caracteres |
| Caracteres por línea (Font B) | 64 caracteres |
| Soporte de corte automático | No (corte manual / desgarro asistido) |
| Avance recomendado al final | 4 líneas |
| Soporte de código QR nativo | Sí (comandos GS ( k) |
| Soporte de imágenes raster | Sí (GS v 0) |
| Conectividad física | Bluetooth 4.0 / USB 2.0 |

---

## 5. Transportes de impresión (`PrintTransport`)

Ubicado en `lib/core/documents/transports/`:
- `PrintTransport`: Interfaz que define:
  - `Future<void> connect()`
  - `Future<void> send(List<int> bytes)`
  - `Future<void> disconnect()`
  - `bool get isConnected`
  - `PrintTransportType get type` (`usb`, `bluetooth`, `mock`)
- `MockPrintTransport`: Implementación en memoria que registra los bytes enviados para pruebas de integración y unitarias sin requerir hardware físico conectado.

---

## 6. Organización de archivos en `lib/core/documents/`

```text
lib/core/documents/
├── documents.dart                     # Barril público de exportación
├── models/
│   ├── document_model.dart            # DocumentModel, DocumentStatus, etc.
│   ├── document_metadata.dart         # Metadatos del documento
│   ├── document_party.dart            # Emisor, receptor, responsable
│   ├── document_line.dart             # Línea / renglón de documento
│   ├── document_totals.dart           # Totales e impuestos
│   └── pdf_output.dart                # DTO con bytes y nombre de archivo
├── profiles/
│   ├── printer_profile.dart           # Interfaz base de perfiles
│   └── rongta_rpp300_profile.dart     # Perfil Rongta RPP300
├── renderers/
│   ├── a4/
│   │   └── a4_pdf_renderer.dart       # Motor de renderizado A4 PDF
│   ├── ticket/
│   │   └── ticket_80mm_pdf_renderer.dart # Motor de renderizado Ticket 80mm PDF
│   └── esc_pos/
│       ├── esc_pos_commands.dart      # Constantes y builders de comandos ESC/POS
│       └── esc_pos_renderer.dart      # Generador de bytes ESC/POS
├── transports/
│   ├── print_transport.dart           # Contrato de transporte
│   └── mock_print_transport.dart      # Transporte simulado para pruebas
└── services/
    └── document_service.dart          # Orquestador unificado de salidas
```

---

## 7. Criterios de verificación y calidad

1. **Sin dependencias de módulos de negocio:** `lib/core/documents/` no importa nada de `lib/modules/*`.
2. **Consistencia:** Las tres salidas reflejan con exactitud matemática y semántica el mismo `DocumentModel`.
3. **Robustez ante datos vacíos o extensos:**
   - Manejo de documentos sin receptor, sin notas y sin QR.
   - Manejo de documentos con decenas de líneas sin overflow visual en A4 o ticket.
   - Manejo de descripciones largas con ajuste de línea.
4. **Validación estática y pruebas:**
   - 0 advertencias en `flutter analyze`.
   - 100% de pruebas pasando en `test/core/documents/`.
   - Compilación exitosa en `flutter build macos --debug`.
