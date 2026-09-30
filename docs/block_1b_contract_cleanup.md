# Eliminaciones verificables para 1B.3

Estos puentes existen únicamente mientras se migran los consumidores a las
fachadas y RPC públicas. Deben eliminarse en 1B.3 y comprobarse con una
búsqueda de referencias antes de revocar las rutas heredadas.

- Exports de entidades internas desde `configuration_api.dart`.
- `typedef SalesAgent = SalesAgentDto` en `sales_api.dart`.
- `createLegacyAgent`.
- `updateLegacyAgent`.
- `deactivateLegacyAgent`.
- Imports directos de `configuration/di` desde Productos.

La eliminación se realizará después de que Productos y las pantallas de
Configuración usen exclusivamente las fachadas públicas. No se ejecuta en
este ajuste contractual.
