# List Patterns and Optimization

## Optimización de Búsquedas y Filtros
El filtrado en servidor debe ser implementado para `ProductDataSource` y `CustomerDataSource`, reemplazando el filtrado en memoria de Dart. Para ello:
1. Migración PostgreSQL de índices `pg_trgm` para `products` y `customers`.
2. Trasladar filtros de texto, categoría y estado al query de Supabase usando operadores `ilike` o `textSearch`.
