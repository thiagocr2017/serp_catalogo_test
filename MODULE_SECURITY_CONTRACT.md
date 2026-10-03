# Contrato de comunicación y seguridad entre módulos

## 1. Propósito y obligatoriedad

Este documento define la frontera técnica y de seguridad de todos los módulos
de SERP. Complementa `MODULE_STRUCTURE.md` y es obligatorio para módulos
actuales y futuros. Los SDD describen reglas funcionales; este contrato define
cómo pueden colaborar sin exponer su implementación ni saltarse controles.

> **Fuente única.** Este archivo es la única redacción normativa del contrato
> de seguridad. `.specs/01-module-contracts.md` lo enlaza y no lo repite. Ante
> un conflicto, se aplica este documento. Cuando su contenido se migre a
> `.specs/`, este archivo quedará como puntero y la migración se registrará
> aquí.

## 2. Propiedad y frontera

- Cada dato, operación y documento tiene un único módulo propietario.
- Solo el propietario escribe sus tablas y Storage desde código de aplicación.
- Otro módulo no importa `data/`, `domain/`, `di/`, `presentation/` ni
  `services/` internos del propietario.
- La única dependencia permitida es el índice `<module>_module.dart` y los
  contratos que este exporte desde `api/`.
- `main.dart` puede conocer implementaciones únicamente como raíz de composición.
- `core` ofrece capacidades técnicas y no puede convertirse en un atajo para
  compartir reglas de negocio o repositorios.

## 3. Qué puede exponer una API modular

Una API pública puede exponer solamente:

- comandos que expresan una intención de negocio;
- consultas de lectura con el mínimo dato necesario;
- DTO públicos inmutables y estables;
- identificadores opacos y tipos de valor compartidos;
- eventos de dominio ya ocurridos;
- rutas públicas que el router global necesite registrar.

No debe exponer:

- clientes de Supabase, consultas SQL ni nombres de tablas como contrato;
- repositorios o fuentes de datos concretas;
- providers internos de Riverpod;
- widgets, controladores o estado mutable de otra pantalla;
- entidades internas con campos que el consumidor no necesita;
- credenciales, tokens, MAC, secretos o datos personales innecesarios;
- métodos genéricos que permitan escribir cualquier tabla o evitar reglas.

Los DTO públicos se versionan de manera compatible. Quitar o reinterpretar un
campo exige migrar consumidores y registrar el cambio.

## 4. Formas permitidas de comunicación

### Consulta síncrona

El consumidor llama una consulta pública del propietario. La respuesta es un
DTO mínimo y no concede capacidad de escritura.

### Comando síncrono

El consumidor solicita una intención completa, por ejemplo reservar stock o
aplicar un pago. El propietario valida permisos, estado e invariantes y devuelve
un resultado tipado. El consumidor nunca reproduce esas escrituras por su cuenta.

### Evento asíncrono

El propietario publica un hecho confirmado e inmutable. Los suscriptores deben
ser idempotentes y no asumir orden global salvo que el contrato lo garantice.
Un evento no reemplaza la transacción que protege la operación original.

## 5. Operaciones que afectan varios módulos

- Debe existir un único caso de uso orquestador claramente propietario.
- Las escrituras que deban ocurrir juntas se ejecutan en una función PostgreSQL
  transaccional o mecanismo equivalente: todas se confirman o todas revierten.
- Cada comando recibe una clave de idempotencia para impedir duplicados por
  reintentos, doble clic, sincronización offline o dos equipos concurrentes.
- Se bloquean o validan las filas necesarias para impedir ventas, cobros,
  reservas o saldos incompatibles por concurrencia.
- No se mantiene una transacción de base de datos abierta mientras se espera al
  usuario, impresora, red o servicio externo.
- Los efectos externos se registran y reintentan después de confirmar el estado
  de negocio; imprimir dos veces no crea dos documentos.

## 6. Autorización y base de datos

- La autorización se verifica en la API/caso de uso y nuevamente en PostgreSQL
  mediante privilegios, RLS o funciones seguras. Ocultar un botón no autoriza.
- Se aplica mínimo privilegio por rol y operación.
- El cliente de escritorio nunca contiene `service_role`, contraseñas de base
  de datos ni secretos administrativos.
- Las funciones usan `SECURITY INVOKER` por defecto.
- Una función `SECURITY DEFINER` requiere justificación, `search_path` fijo,
  nombres calificados, validación explícita del actor y permisos de ejecución
  restringidos; no puede transformarse en una escritura genérica.
- Las tablas internas no se habilitan para escritura directa solo para evitar
  crear un comando público correcto.
- Identidad de equipo y MAC sirven para trazabilidad local, no sustituyen la
  identidad autenticada ni prueban por sí solas quién realizó una operación.

## 7. Validación, errores y datos sensibles

- Toda entrada externa se valida por tipo, longitud, rango, moneda, precisión,
  estado y pertenencia antes de persistirla.
- SQL siempre se parametriza; nombres de columna, tabla u orden no provienen
  directamente de texto del usuario.
- Los errores públicos son tipados y comprensibles, pero no revelan SQL,
  credenciales, rutas internas ni trazas sensibles.
- Logs y auditoría no guardan tokens, secretos, datos completos de tarjetas ni
  archivos privados. Los valores sensibles se omiten o enmascaran.
- Archivos importados validan extensión, contenido, tamaño y cantidad; su nombre
  nunca decide por sí solo una ruta de escritura.

## 8. Auditoría e inmutabilidad

- Crear, confirmar, anular, revertir, reembolsar y cambiar permisos genera una
  acción de auditoría consolidada con actor, equipo, fecha, entidad y resultado.
- Documentos confirmados y movimientos contables o de inventario no se editan ni
  eliminan físicamente; se corrigen con documentos de reversión relacionados.
- La auditoría es append-only para roles ordinarios y conserva identificadores
  que permitan navegar al elemento afectado.
- Los datos históricos necesarios se guardan como snapshot y no cambian al
  editar después productos, terceros, agentes o configuración.

## 9. Operación offline y sincronización

- Cada operación local pendiente conserva UUID, dispositivo, instante local,
  estado de sincronización y carga validable.
- El servidor asigna numeración definitiva y vuelve a ejecutar autorización e
  invariantes al sincronizar.
- Un conflicto nunca se resuelve sobrescribiendo silenciosamente. Se aplica una
  regla documentada o queda pendiente de intervención.
- Un reintento con la misma clave devuelve el resultado previo y no repite los
  efectos de negocio.

## 10. Pruebas mínimas de una API pública

- un módulo consumidor compila importando únicamente el índice público;
- acceso autorizado, denegado y con rol insuficiente;
- validación de entradas inválidas y límites;
- idempotencia y doble envío concurrente;
- reversión completa ante un fallo intermedio;
- RLS y privilegios probados con el rol real de la aplicación;
- serialización compatible de DTO y eventos;
- errores sin filtración de datos sensibles;
- auditoría correcta de éxito, rechazo y reversión cuando corresponda.

## 11. Revisión obligatoria

Antes de publicar o ampliar una API modular se debe responder:

1. ¿Quién es propietario del dato y de la regla?
2. ¿El consumidor necesita realmente cada campo expuesto?
3. ¿Puede completar la operación sin importar detalles internos?
4. ¿Dónde se valida autorización e idempotencia?
5. ¿Qué ocurre con dos equipos, reintentos, offline y fallo parcial?
6. ¿Qué se audita y qué información debe ocultarse?
7. ¿Las pruebas usan el mismo rol y políticas que la aplicación?

Si alguna respuesta no está definida, la frontera no está lista para considerarse
estable.
