# Image Pipeline and Thumbnails

## Diagnóstico Técnico Actual
En `ProductListPage` y componentes afines, las imágenes se renderizan directamente con `Image.network(product.imageUrl!)` descargando la imagen de tamaño completo (hasta 1600 px) en cada render.
Al hacer scroll, Flutter destruye los widgets fuera de pantalla; al regresar, vuelven a solicitarse por HTTP a Supabase Storage, provocando parpadeo, lentitud y consumo innecesario de ancho de banda.
No existe generación de miniaturas (thumbnails) ni almacenamiento persistente en disco local (`ApplicationSupportDirectory`).

## Requerimientos y Comportamiento Esperado

### Pipeline de dos tamaños:
1. **Original / Full**: Para ficha técnica y catálogo PDF.
2. **Miniatura (Thumbnail)**: Cuadrada de 256x256 px a 80% calidad JPG para tablas, grillas y selectores.

### Estrategia Local-First (Caché en disco):
- Las imágenes cargadas o sincronizadas se almacenan localmente en `<appDataDir>/cache/products/{sku}_thumb.jpg`.
- La UI consulta primero el archivo local; si no existe, lo descarga en segundo plano desde el storage y lo cachea inmediatamente.

### Ciclo de Invalidez y Reemplazo:
- Al editar la imagen de un producto, se sobreescribe la miniatura local y se actualiza el cache de Flutter (`imageCache.evict`).
- Al eliminar un producto o quitar su imagen, se purga el archivo local correspondiente.

### Razón y Tradeoff:
- **Razón**: Elimina el tiempo de espera por red en listas y previene el parpadeo en scroll.
- **Tradeoff**: Requiere gestionar almacenamiento local en disco y sincronización en caso de cambios externos.
