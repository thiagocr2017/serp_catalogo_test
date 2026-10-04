# 01 - Contratos entre Modulos

## Regla obligatoria

Los modulos de negocio no pueden importar carpetas internas de otros modulos.
Estan prohibidos imports cruzados a `data/`, `domain/`, `di/`,
`presentation/` o `services/` de otro modulo.

## Comunicacion permitida

- Facades y DTOs publicados por `api/`.
- Exports declarados en `<module>_module.dart`.
- Comandos de aplicacion registrados en la raiz de composicion.
- Eventos asincronos solo cuando exista contrato documentado.

## Operaciones multi-modulo

Una operacion que afecte varios modulos debe tener un unico caso de uso o
comando orquestador. El orquestador no puede saltarse las APIs publicas de los
modulos involucrados.

## Auditoria y trazabilidad

Las operaciones con impacto de negocio deben registrar actor, dispositivo,
fecha, entidad afectada y resultado. Los libros inmutables, como movimientos de
inventario, no se editan directamente; cualquier correccion se registra con una
transaccion compensatoria.

## Pruebas minimas de una API publica

Cada API publica debe cubrir:

- Entrada valida.
- Entrada invalida.
- Error de persistencia o dependencia.
- Integracion esperada con auditoria cuando aplique.
- Compatibilidad hacia atras si la API ya existe.

## Referencia

Este archivo **no** vuelve a enunciar las reglas: solo las enlaza. La unica
fuente normativa del contrato de seguridad es
[`architecture/module-security-contract.md`](architecture/module-security-contract.md).

Regla de resolucion: ante cualquier duda o conflicto se aplica
`architecture/module-security-contract.md`. **No** se duplica una regla en este archivo; se
enlaza. Enunciar la misma regla en dos sitios es lo que produjo la deriva
documental corregida en `.specs/refactors/01-document-consistency.md`.

El contenido normativo fue migrado a `architecture/module-security-contract.md`.
Este archivo mantiene el resumen operativo para evitar duplicacion.
