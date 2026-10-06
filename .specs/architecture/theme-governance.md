# Gobierno del tema y sistema visual

## Proposito

`shared/theme/` es la fuente unica de tokens visuales y defaults de Material.
Las pantallas consumen `Theme.of(context)` y `ColorScheme`; no definen paletas,
intenciones de boton ni estilos globales por su cuenta.

## Estructura

```text
lib/shared/theme/
├── app_theme.dart       # ThemeData claro/oscuro y estilos Material
├── app_tokens.dart      # Espaciado y radios reutilizables
├── semantic_colors.dart # Pares de color para exito/aviso/informacion
└── intent_button.dart   # Boton compartido por intencion semantica
```

La estructura es deliberadamente pequena: agregar subcarpetas solo cuando el
numero de archivos lo justifique. El contrato y el inventario de extensiones
permanecen en esta spec.

## Responsabilidades

- El tema instalable de Flutter es `ThemeData` (incluyendo `ColorScheme` y los
  temas de componentes Material). No se requiere agregar un framework externo
  equivalente a Bootstrap para estandarizar la UI.
- `shared/theme/` define colores semanticos, tipografia, espaciado/radios y
  defaults para botones, entradas, tablas/listas, tarjetas, dialogs y estados.
- `AppTokens` centraliza medidas repetidas; `AppActionIntent` y `IntentButton`
  proveen las intenciones primarias, secundarias, de exito, advertencia y
  destructivas. Las pantallas nuevas deben preferirlos cuando aplique.
- `AppSemanticColors` aporta pares con contraste para exito, aviso e
  informacion; `StatusChip` e `IntentButton` consumen esos mismos roles.
- Un componente compartido se agrega solo cuando expresa un patron repetido
  con la misma semantica. Las pantallas no deben copiar su implementacion.
- La intencion semantica se escoge por significado: accion primaria,
  secundaria, destructiva, advertencia o confirmacion. No se colorean botones
  por preferencia estetica ni se usa color como unica senal.
- Estados (exito, advertencia, error, informativo, neutral) reutilizan tokens y
  componentes compartidos como `StatusChip` cuando corresponda.
- La preferencia del usuario (claro/oscuro/sistema) es local a la app. La
  configuracion comercial, moneda incluida, no define el tema visual.
- Antes de introducir o cambiar un patron exitoso, revisar este contrato,
  `app_theme.dart` y las pruebas visuales/widget existentes. Una pantalla no
  debe divergir salvo necesidad documentada o solicitud explicita de cambio
  global.

## Contrato para contribuciones

1. Usar `ColorScheme` y temas de componente existentes.
2. Para una nueva intencion o variante, documentar el caso y agregarla al tema
   compartido antes de usarla en una pantalla.
3. Probar estados normal, hover/focus, disabled, error y dark/light cuando
   apliquen.
4. Verificar desbordamiento en anchos estrechos de escritorio y labels/tooltips
   para acciones solo-icono.
5. No crear una paleta por modulo ni poner preferencias visuales de aplicacion
   en configuracion de negocio.

## Ubicacion

Este sistema pertenece a `shared/theme/`, no a un modulo de negocio. Un futuro
gestor de temas solo se justifica si se desea que usuarios administren marcas,
contraste o personalizacion dinamica; no es requisito para la estandarizacion
actual.
