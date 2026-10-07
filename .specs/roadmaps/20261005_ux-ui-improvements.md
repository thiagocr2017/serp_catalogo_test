# Hoja de ruta UX/UI: listas, operaciones y consistencia

Fecha: 2026-10-05
Estado: en ejecucion; fases 0 y 1 parcialmente implementadas
Alcance: experiencia de listas, configuracion, perfil de cliente, documentos de
venta, auditoria y tema visual. No autoriza cambios de base de datos ni reglas
de negocio por si sola.

## Diagnostico y vocabulario

La clasificacion propuesta de tres listas es correcta. Se normalizan los
nombres como **lista indice/principal**, **lista contextual/informativa** y
**lista de composicion**. Un selector de registros es un control, no un cuarto
tipo. Los criterios completos viven en `architecture/list-patterns.md`.

La app ya centraliza `ThemeData` en `lib/shared/theme/app_theme.dart`, asi que
no necesita instalar Bootstrap ni crear un modulo de negocio para botones. Se
debe completar el gobierno del sistema visual en `architecture/theme-governance.md`
y reutilizar el tema/componentes compartidos.

Hallazgos de codigo al registrar el plan (estado actualizado por las fases de
ejecucion debajo):

- Cotizaciones: **resuelto en esta fase**. La lista busca numero, cliente,
  estado, moneda, notas, SKU, producto y presentacion; filtra por estado y
  muestra moneda persistida con la accion secundaria separada de la fila.
- Devoluciones: **detalle de solo lectura agregado**; la lista abre el documento
  y desde ahi se puede volver al indice o saltar al cliente con retorno.
- Consignaciones: **detalle de solo lectura agregado**; el ciclo de liquidacion
  no esta implementado y continua en discovery.
- Perfil de cliente: la alerta de documentos pendientes agrega conteos pero no
  desglosa tipos ni navega a la lista filtrada.
- Auditoria: **mejora parcial**. El titulo agrega la etiqueta legible del
  recurso y el subtitulo presenta autor, dispositivo y fecha/hora local.
- Tema: **estructura inicial agregada** en `shared/theme/`, con tokens,
  intenciones de boton y guia en la skill UX/UI.

## Estado de ejecucion

- Fase 0: contratos de listas y tema registrados; estructura de tokens,
  colores semanticos, botones por intencion y ruta de consulta agregados a la
  skill.
- Fase 1: busqueda/filtro de cotizaciones, moneda persistida y apertura de
  detalle en devoluciones/consignaciones implementados con retorno probado.
- Fase 2: alerta contextual de documentos pendientes y organizacion de
  Configuracion aun pendientes.
- Auditoria: titulos y metadatos legibles implementados parcialmente.
- Devoluciones financieras y ciclo de consignacion siguen pendientes de
  decisiones de negocio; no se hicieron cambios de DB/RPC.

## Orden de trabajo

### Fase 0: contratos compartidos

**Registrado en este cambio:** taxonomia/contratos de listas y gobierno visual.

**Criterios de salida:** nuevas pantallas identifican su tipo de lista; las
listas indice tienen entrada/ruta, busqueda/filtros cuando el volumen lo pide,
apertura visible, acciones accesibles y alcance de exportacion declarado; toda
UI consume tokens/componentes compartidos.

### Fase 1: cotizaciones y navegacion de documentos

Crear/actualizar specs propias de lista y detalle antes de cambiar UI. Anadir
busqueda sobre numero, cliente, estado y productos cuando los DTO disponibles
permitan hacerlo; filtros combinables y reinicio claro. Reorganizar monto,
estado, apertura y menu para anchos estrechos. Definir exportacion despues de
acordar formato y alcance. Agregar rutas/detalles para devoluciones y
consignaciones para que las listas permitan abrir el registro.

**Criterios de salida:** busqueda/filtros probados; cada fila abre su documento;
acciones validas son accesibles sin overflow; retorno desde el detalle vuelve a
la lista o al contexto de origen; monto usa la moneda persistida, no un simbolo
fijo.

### Fase 2: perfil y configuracion

El card de documentos pendientes debe desglosar cotizaciones, pedidos,
devoluciones y consignaciones pendientes, con el estado/criterio que los hace
pendientes y accesos a listas con filtro del cliente. Reorganizar Configuracion
por grupos nombrados; evaluar pestanas solo si el numero y densidad de grupos
lo hacen mas rapido que una pagina larga. Mantener configuracion visual local
separada de configuracion comercial.

**Criterios de salida:** cada cifra de alerta se explica; cada acceso abre una
lista pertinente y conserva retorno al cliente; los grupos de configuracion
tienen navegacion clara y no esconden acciones irreversibles.

### Fase 3: auditoria legible

Traducir eventos y campos a titulos concretos, incluyendo identificador
humano (p. ej. SKU/nombre/categoria), accion, autor/dispositivo y fecha/hora
local. Mantener detalle expandible con valores anteriores/nuevos y excluir
campos tecnicos. Los eventos de borrado deben distinguir eliminacion logica,
desactivacion y eliminacion real.

**Criterios de salida:** ejemplos de alta, edicion, baja y reactivacion se
entienden sin conocer nombres de tablas; los detalles tecnicos permanecen
consultables sin saturar la lista.

### Fase 4: decisiones y flujos de negocio pendientes

- **Cotizacion expirada:** recomendacion: preservar el documento expirado como
  evidencia historica y ofrecer "Duplicar como borrador" con nuevo numero y
  referencia al original. Reactivar el mismo documento solo si se acuerda una
  transicion formal, nueva vigencia y auditabilidad. No cambiar estados hasta
  acordarlo.
- **Devoluciones:** acordar flujo y contabilidad antes de implementarlo. La
  propuesta esta al final de esta hoja de ruta.
- **Consignaciones:** realizar discovery especifico de ciclo, titularidad,
  liquidacion y escalabilidad antes de redisenar pantalla o API.

## Devoluciones: contrato registrado

La especificacion funcional recibida el 2026-10-05 cierra las decisiones antes
abiertas. La regla de negocio vive en
`modules/sales/returns/1.return-business.spec.md`; el contrato DB, ownership,
transaccion y matriz pgTAP en `modules/sales/returns/2.database-contract.spec.md`.
Las obligaciones por propietario estan en `modules/inventory/returns/` y
`modules/payments/returns/`; el contrato de pantalla vive en
`screens/sales-return-form/`.

- Se inicia desde factura confirmada, con snapshot, pagos y devoluciones
  anteriores; cantidades se revalidan bajo bloqueo en el servidor.
- Condicion por linea: `Buen estado` por defecto va a ubicacion vendible;
  `Dañado` va a cuarentena. Un rol persistido excluye cuarentena de todo stock
  disponible; el nombre de bodega no basta.
- Una sola resolucion por documento: reembolso o credito. Primero se reduce la
  deuda; solo el excedente pagado puede usar la opcion elegida. Debe cubrirse
  completo o no se confirma.
- La confirmacion integra Sales, Inventory y Payments en una transaccion, con
  command_id idempotente, auditoria y pgTAP/concurrency.
- No habilitar confirmacion UI antes de implementar y pasar esos contratos.
  La implementacion de negocio/DB se mantiene separada del cambio de UX.

## Discovery de consignaciones

El rediseño debe responder antes de implementar: quien conserva la titularidad
del stock; cuando se reconoce venta/ingreso; envios parciales y multiples
visitas; ubicaciones y reservas; reporte del cliente de unidades vendidas;
liquidaciones parciales; devoluciones y mermas; diferencias/robos; precios y
comisiones; vencimiento y renovacion; conciliacion por cliente y periodo;
transferencia entre ubicaciones; permisos y aprobaciones; idempotencia y
concurrencia; lotes grandes y exportacion. Proponer estados y matriz de
transiciones para operacion pequeña y alto volumen. No asumir que "liquidada"
significa pagada: debe definirse separadamente.

## Validacion transversal

- Cada fase actualiza los cuatro archivos de spec de pantalla y pruebas antes
  de considerarse lista.
- Revisar estados de carga/error/vacio, anchos pequenos, overflow, teclado,
  acciones con tooltip, permisos, navegacion de ida y vuelta.
- Para exportacion, verificar dataset completo/filtrado y paginacion; para
  cambios de reglas/RPC/DB, agregar pruebas de integracion y pgTAP.
- Preservar patrones exitosos existentes salvo peticion explicita de
  estandarizacion global; toda excepcion se documenta junto al patron.

## Rediseño de Promociones a pantalla completa
- Reemplazar modal `AlertDialog` comprimido por pantalla completa.
- Registro: `.specs/screens/promotion-form/` (1 a 4).

## Homologación del Icono de la Aplicación
- Configurar `flutter_launcher_icons` en `pubspec.yaml` usando `assets/icon/SERP_logo_v2.png`.
- Ejecutar regeneración de iconos nativos para macOS.
- Registro: `.specs/architecture/theme-governance.md`
