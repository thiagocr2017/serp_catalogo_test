# 06 - Auditoria inicial de codigo sin uso y residuos

## Clasificacion

- Estado: auditoria inicial; limpieza pendiente de confirmacion por componente.
- Prioridad: P2 para el metodo muerto y los documentos contradictorios; P3
  para dependencias/metadatos candidatos.
- Etiquetas: `mantenimiento`, `dead-code`, `documentacion-obsoleta`,
  `dependencias`, `limpieza`, `backlog-futuro`.
- Fecha: 2026-10-06.
- Alcance inspeccionado: inventario de `lib/`, `test/`, `integration_test/`,
  `supabase/`, `.specs/` y `tool/` (478 archivos en total al auditar).

## Definicion operativa

Este proyecto llama candidato a codigo basura cuando se comprueba que no tiene
consumidores ni una funcion vigente, fue reemplazado sin retirarse, o es una
dependencia/residuo temporal que ya no sirve al producto. La antiguedad, un
`TODO`, un nombre `legacy`, o aparecer en un documento historico no son prueba
suficiente por si solos.

Esta auditoria no elimina codigo. Clasifica hallazgos con evidencia y deja los
cambios destructivos para una tarea de limpieza separada, con las pruebas del
componente y una revision de `git diff`.

## Cobertura y metodo

Inventario observado:

| Area | Archivos |
|---|---:|
| `lib/` | 192 |
| `test/` | 52 |
| `integration_test/` | 8 |
| `supabase/` | 94 |
| `.specs/` | 131 |
| `tool/` | 1 |
| **Total** | **478** |

Dentro de Supabase hay 68 migraciones y 22 archivos de pruebas pgTAP. La
revision combino inventario, busqueda de `TODO`/`FIXME`/marcadores de codigo
ignorado, referencias de simbolos candidatos, imports de paquetes directos,
comparacion de estados documentados con rutas y pruebas, `flutter analyze` y
`flutter test`. No se trato un marcador textual como evidencia automatica de
código muerto.

## Hallazgos

### Confirmado

| ID | Hallazgo | Evidencia | Estimacion | Accion sugerida |
|---|---|---|---:|---|
| C1 | Editor modal privado sin llamadas, conservado junto al editor de pantalla completa | `product_profile_page.dart:469-624` tiene `_edit` con `ignore: unused_element`; no hay invocaciones. `product_routes.dart` enruta `:productId/edit` a `ProductFormPage`; pruebas de formulario cubren cargar y actualizar | 154 lineas | Retirar el metodo y su ignore/TODO, luego correr pruebas de perfil/formulario y analisis |
| C2 | El estado de Ventas publicado en dos documentos quedo atrasado | `README.md:71-73` y `AGENTS.md:64` dicen que cotizaciones, pedidos, facturas, devoluciones y consignaciones tienen UI solo de lectura; existen formularios, rutas de edicion y pruebas/E2E de operaciones comerciales | 2 afirmaciones documentales | Corregir usando una matriz por flujo; no declarar completos los flujos que solo tienen parte de su ciclo implementado |

### Candidatos que requieren validar antes de retirar

| ID | Candidato | Evidencia | Riesgo/validacion |
|---|---|---|---|
| C3 | `cupertino_icons` | Declarada en `pubspec.yaml`; no se encontro `CupertinoIcons` ni import del paquete en fuentes Dart | Parece dependencia de plantilla. Confirmar que no se usa via configuracion/build antes de quitarla |
| C4 | `connectivity_plus` | Declarada en `pubspec.yaml`; no se encontro uso de API Dart. Aparece en registradores nativos generados. La cola offline existe y se instancia en `main.dart` | Puede ser resto sin integrar o dependencia prevista para sincronizacion. Decidir el contrato offline antes de retirar; no borrar los archivos offline por el hecho de que el paquete no se use |
| C5 | Metadatos de plantilla Flutter | `pubspec.yaml:2` conserva `description: "A new Flutter project."` y comentarios genericos de plantilla | Limpieza cosmetica, sin impacto runtime conocido; corregir en mantenimiento de metadatos |

## Falsos positivos que se preservan

- Las specs historicas `sdd-historical.md` son referencia mantenida por la
  convencion del proyecto; no son codigo ejecutable ni se eliminan por ser
  antiguas.
- Las rutas, vistas o RPC `legacy` no se retiran por nombre: pueden existir
  consumidores de compatibilidad o pruebas de migracion. Buscar consumidores y
  mantener pruebas de ausencia/revocacion antes de retirarlas.
- Los `TODO`/`pendiente` ligados a una capacidad aprobada son deuda explicita,
  no basura. Por ejemplo, el borrador de autorizacion, pagos o capacidades
  diferidas de inventario deben compararse con su status spec.
- `test/widget_test.dart` es un smoke test minimo del shell. Su sencillez no lo
  hace redundante con pruebas de modulo.
- La cola offline esta cableada desde `main.dart`; no se considera muerta solo
  porque sus consumidores funcionales sean limitados. La auditoria separada de
  alcance offline debe decidir si se completa o se retira.

## Limites de esta conclusion

1. `flutter analyze` limpia imports no usados y varios casos locales, pero no
   prueba que cada API publica, DTO, ruta o archivo tenga consumidores de
   producto.
2. `flutter test` valida 199 pruebas en la corrida del 2026-10-06; no demuestra
   que no exista codigo muerto ni cubre pgTAP/E2E contra servicios activos.
3. El inventario y las busquedas dieron cobertura automatizada a todos los
   archivos de las areas listadas, pero no equivalen a lectura humana linea por
   linea de 478 archivos. Los resultados de C1-C5 son hallazgos dirigidos y
   reproducibles, no una afirmacion de que el resto sea perfecto.
4. No se calculo porcentaje de basura: mezclar lineas muertas, documentos
   desactualizados y dependencias no usadas en un unico porcentaje seria
   enganoso. Por ahora la cantidad comprobada en codigo fuente es 154 lineas
   candidatas en un solo metodo; los demas hallazgos se reportan por categoria.

## Siguientes tareas

- [ ] Cerrar C1 en cambio pequeno, despues de confirmar con Producto que el
  editor de pagina completa es el unico flujo de edicion esperado.
- [ ] Corregir C2 con una matriz de estado por documento comercial, contrastada
  con pruebas y contratos DB; no copiar un unico estado general a todos.
- [ ] Resolver C3-C4 contra el alcance aprobado y revisar el lockfile despues
  de cualquier retiro de dependencia.
- [ ] Para ampliar la auditoria, ejecutar un analisis de referencias por
  modulo/API y rastrear cada ruta, provider, DTO y RPC hasta consumidor, pruebas
  y documentacion.
- [ ] Revisar una categoria por cambio y ejecutar sus pruebas; evitar una
  limpieza masiva que dificulte identificar regresiones.

## Criterio de cierre

- Todo codigo retirado tenia evidencia de ausencia de consumidor o reemplazo.
- Los consumidores, specs y pruebas existentes se actualizaron en el mismo
  cambio.
- `flutter analyze`, las pruebas focales y la suite completa pasan.
- Dependencias retiradas no quedan en `pubspec.lock` ni registradores nativos
  manuales; los registradores generados se regeneran con Flutter.
- Los hallazgos no resueltos conservan estado, evidencia y siguiente accion en
  este registro.

