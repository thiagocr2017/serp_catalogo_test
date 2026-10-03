# 00 - Contexto del Proyecto

## Proposito

SERP es una aplicacion Flutter desktop para macOS orientada a gestion de
productos, inventario, ventas, pagos, configuracion, auditoria y generacion local
de documentos.

## Pila tecnologica

- Flutter desktop para macOS.
- Riverpod 3 para estado e inyeccion.
- GoRouter para navegacion.
- Supabase local con PostgreSQL como fuente de verdad.
- `flutter_lints` como base de analisis estatico.

## Restricciones globales

- La interfaz y la documentacion funcional se escriben en espanol.
- Los identificadores tecnicos se escriben en ingles.
- El modo oscuro es el valor predeterminado.
- La preferencia de tema es local y no se persiste en Supabase.
- `main.dart` es la raiz de composicion de implementaciones y overrides.
- No se debe introducir un ORM sin una spec de arquitectura aprobada.

## Arquitectura base

Cada modulo de negocio vive en `lib/modules/<name>/` y mantiene separacion por
capas:

```text
api/
domain/
data/
presentation/
di/
<name>_module.dart
```

La unica superficie publica consumible desde otros modulos es
`<name>_module.dart` y los contratos exportados por `api/`.

## Regla de specs

Antes de implementar una nueva funcionalidad, pantalla o refactorizacion
compleja, debe existir una spec con comportamiento verificable. La spec no debe
usar frases ambiguas como "manejar adecuadamente"; debe indicar entradas,
salidas, errores, estados y criterios de prueba observables.

No se debe cambiar arquitectura global dentro de una spec de feature. Si el
cambio funcional exige refactorizacion previa, se crea una spec independiente.

## Referencias historicas

- `MODULE_STRUCTURE.md`
- `MODULE_SECURITY_CONTRACT.md`
- `DOCUMENT_STANDARDS.md`
- `SDD_Modulo_*.md`
- `docs/form_test_coverage.md`
