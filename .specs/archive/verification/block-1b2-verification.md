# Verificación del Bloque 1B.2

## Alcance cerrado

El bloque introduce las bases PostgreSQL versionadas de Configuración y Ventas:

- comandos idempotentes para crear agentes y presentaciones;
- control de concurrencia optimista mediante versiones;
- auditoría consolidada por acción;
- DTO de retorno que excluyen campos administrativos;
- funciones internas sin permiso de ejecución para clientes;
- conservación temporal de las rutas heredadas necesarias para 1B.3.

Autenticación y autorización por usuario continúan fuera de este bloque. Hasta
el módulo final de Autenticación, `anon` y `authenticated` representan el mismo
cliente local de escritorio. Esta compatibilidad no debe llegar a producción.

## Matriz efectiva de permisos

Revisión ejecutada contra la base local reconstruida desde migraciones.

| Recurso | `anon` / `authenticated` | Decisión |
| --- | --- | --- |
| RPC públicas de Configuración y Ventas | `EXECUTE` | Permitido temporalmente para el cliente local |
| `audit_configuration_sales` | Sin `EXECUTE` | Interna |
| `clear_selected_catalog_agent_internal` | Sin `EXECUTE` | Interna |
| `register_catalog_logo_version` | Sin `EXECUTE` | Reservada para 1B.4 |
| Tablas de recibos idempotentes | Sin acceso directo | Internas |
| `audit_actions` | Sin acceso directo | Interna |
| `app_settings`, `sales_agents`, `catalog_agents`, `packaging_presentations` | Acceso heredado amplio | Puente obligatorio hasta migrar consumidores en 1B.3 |

El acceso heredado amplio no se considera el modelo final. Debe revocarse en
1B.3 inmediatamente después de que la interfaz use sólo las fachadas y RPC
públicas. Revocarlo en 1B.2 rompería las pantallas que todavía dependen de los
repositorios antiguos.

## Evidencia automatizada

- Cinco archivos pgTAP: 53 pruebas.
- Prueba con dos conexiones PostgreSQL simultáneas para agentes y
  presentaciones.
- Reintentos concurrentes producen una entidad y un recibo completado.
- `flutter analyze` sin incidencias.
- Suite Flutter: 34 pruebas aprobadas.
- Compilación macOS debug aprobada.

## Condición para iniciar 1B.3

1B.3 debe seguir la lista de
`.specs/refactors/04-block-1b-contract-cleanup.md`, migrar todos los consumidores y sólo
entonces revocar escritura directa sobre las tablas heredadas. El módulo de
Autenticación permanece planificado como el último módulo antes de producción.
