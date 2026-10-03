# 🎯 Iconografía

> **Los iconos comunican sin palabras. La consistencia es clave.**

---

## 🎨 Estilo de Iconos

### Especificaciones
| Propiedad | Valor |
|-----------|-------|
| Estilo | **Material Symbols** (outlined) |
| Grid | 24x24px (base) |
| Stroke | 2px (outlined) / fill (filled) |
| Corner radius | 2px (sharp) / 4px (rounded) |
| Optical size | 20px (sm), 24px (md), 28px (lg), 36px (xl) |

### Variantes Disponibles
| Variante | Uso |
|----------|-----|
| **Outlined** | Default, UI general |
| **Filled** | Estados activos, énfasis |
| **Rounded** | UI amigable, móvil |
| **Sharp** | Técnico, denso |

---

## 📏 Tamaños Estándar

| Tamaño | Px | Rem | Uso |
|--------|-----|-----|-----|
| xs | 16px | 1rem | Dense UI, chips |
| sm | 20px | 1.25rem | Compact, dense lists |
| **md** | **24px** | **1.5rem** | **Default** |
| lg | 28px | 1.75rem | Prominent, FAB |
| xl | 32px | 2rem | Hero, empty states |
| xxl | 48px | 3rem | Hero, empty states grandes |

### CSS Tokens
```css
:root {
  --icon-xs: 16px;
  --icon-sm: 20px;
  --icon-md: 24px;   /* DEFAULT */
  --icon-lg: 28px;
  --icon-xl: 32px;
  --icon-xxl: 48px;
}
```

---

## 🎨 Estilo Visual

### Outlined (Default)
```tsx
<Icon name="home" sx={{ fontSize: 24, color: 'onSurface' }} />
```
- Stroke: 2px
- Fill: none
- Esquinas: 2px

### Filled (Estados Activos)
```tsx
<Icon name="favorite" filled sx={{ color: 'error' }} />
```
- Fill: color
- Stroke: none

---

## ♿ Accesibilidad

### Iconos Decorativos
```tsx
// ❌ MAL - Screen reader lee "home"
<Icon name="home" />

// ✅ BIEN - Decorativo, ignorado por SR
<Icon name="home" aria-hidden="true" />
```

### Iconos Funcionales (Botones Solo Icono)
```tsx
// ❌ MAL - Sin label
<IconButton><Icon name="delete" /></IconButton>

// ✅ BIEN - aria-label descriptivo
<IconButton aria-label="Eliminar producto">
  <Icon name="delete" aria-hidden="true" />
</IconButton>
```

### Con Texto (Icon + Label)
```tsx
// El icono es decorativo, el texto es el label
<Button startIcon={<Icon name="add" aria-hidden="true" />}>
  Agregar
</Button>
```

---

## 🎨 Categorías y Uso

### Navegación
| Icono | Uso |
|-------|-----|
| `arrow_back` | Back, volver |
| `arrow_forward` | Forward, siguiente |
| `menu` | Menú hamburguesa |
| `close` | Cerrar modal/drawer |
| `menu_open` | Expandir |
| `chevron_left/right` | Navegación lateral |
| `expand_more/less` | Expandir/colapsar |

### Acciones CRUD
| Icono | Acción |
|-------|--------|
| `add` | Crear/Nuevo |
| `edit` | Editar |
| `delete` / `delete_outline` | Eliminar |
| `visibility` / `visibility_off` | Ver/Ocultar |
| `content_copy` | Copiar |
| `content_cut` | Cortar |
| `content_paste` | Pegar |
| `duplicate` | Duplicar |

### Estados y Feedback
| Icono | Estado |
|-------|--------|
| `check_circle` | Éxito, completado |
| `error` / `error_outline` | Error |
| `warning` / `warning_amber` | Advertencia |
| `info` / `info_outline` | Info |
| `help_outline` | Ayuda |
| `check_circle` | Completado, éxito |

### Navegación y UI
| Icono | Uso |
|-------|-----|
| `search` | Buscar |
| `filter_list` / `filter_alt` | Filtros |
| `sort` / `sort_by_alpha` | Ordenar |
| `view_list` / `view_module` / `grid_view` | Cambiar vista |
| `refresh` | Actualizar |
| `download` / `cloud_download` | Descargar |
| `upload` / `cloud_upload` | Subir |
| `print` | Imprimir |
| `share` | Compartir |
| `bookmark` / `bookmark_outline` | Favoritos/Guardar |
| `flag` | Marcar/Reportar |

### Usuario y Cuenta
| Icono | Uso |
|-------|-----|
| `person` / `account_circle` | Perfil |
| `group` / `groups` | Equipos, equipos |
| `login` / `logout` | Login/Logout |
| `settings` / `manage_accounts` | Configuración |
| `lock` / `lock_open` | Bloqueo/Seguridad |
| `key` | API Key, contraseña |

### Acciones de Contenido
| Icono | Acción |
|-------|--------|
| `file_download` | Descargar |
| `file_upload` | Subir |
| `folder` / `folder_open` | Carpetas |
| `description` / `article` | Documentos |
| `picture_as_pdf` | PDF |
| `image` / `photo` | Imágenes |
| `video_library` | Videos |
| `music_note` | Audio |

### Comercio/Inventario
| Icono | Uso |
|-------|-----|
| `shopping_cart` / `shopping_basket` | Carrito |
| `inventory` / `inventory_2` | Inventario |
| `local_shipping` / `local_shipping_outlined` | Envío |
| `receipt` / `receipt_long` | Recibos/Facturas |
| `point_of_sale` | POS |
| `attach_money` / `payments` | Pagos |
| `receipt_long` | Facturas |
| `inventory_2` | Stock |

### Comunicación
| Icono | Uso |
|-------|-----|
| `mail` / `mail_outline` | Email |
| `chat` / `chat_bubble_outline` | Chat |
| `forum` | Foros |
| `announcement` | Anuncios |
| `notifications` / `notifications_none` | Notificaciones |
| `contact_mail` / `contact_phone` | Contacto |

### Sistema y Configuración
| Icono | Uso |
|-------|-----|
| `build` / `settings` | Configuración |
| `tune` / `sliders` | Ajustes finos |
| `bug_report` | Reportar bug |
| `terminal` | CLI/Dev |
| `storage` | Almacenamiento |
| `cloud` / `cloud_queue` | Cloud/Sync |
| `wifi` / `wifi_off` | Conexión |
| `bluetooth` / `bluetooth_disabled` | Bluetooth |

### Tiempo y Fechas
| Icono | Uso |
|-------|-----|
| `schedule` / `access_time` | Tiempo, reloj |
| `event` / `event_note` | Calendario, eventos |
| `date_range` | Rango fechas |
| `history` | Historial |
| `timer` / `timer_off` | Temporizador |
| `alarm` / `alarm_off` | Alarmas |

### Ubicación y Mapas
| Icono | Uso |
|-------|-----|
| `location_on` / `place` | Ubicación |
| `my_location` | Mi ubicación |
| `map` / `map_outline` | Mapa |
| `navigation` / `directions` | Navegación |
| `near_me` | Cerca de mí |

---

## ♿ Checklist Accesibilidad Iconos

- [ ] Iconos decorativos: `aria-hidden="true"`
- [ ] Iconos funcionales: `aria-label` descriptivo
- [ ] Tamaño mínimo 24px (touch target 48x48px)
- [ ] Contraste ≥ 3:1 (iconos UI)
- [ ] Focus visible en iconos interactivos
- [ ] No solo color para estado (icon + texto/patrón)
- [ ] `aria-hidden="true"` en iconos decorativos
- [ ] `aria-label` en botones solo-icono
- [ ] `aria-hidden="true"` en iconos decorativos dentro de botones con texto

---

## 🚫 Anti-Patrones Iconografía

| ❌ No Hacer | ✅ Hacer |
|-------------|----------|
| Icono sin label en botón | `aria-label` descriptivo |
| Icono solo color para estado | Icon + texto/patrón |
| Tamaño < 24px touch target | Mínimo 24px (48x48 touch) |
| Iconos inconsistentes (outline/filled mix) | Sistema consistente |
| Iconos decorativos sin `aria-hidden` | `aria-hidden="true"` |
| Iconos como único label en form | Label visible + icon opcional |
| Iconos muy detallados a 16px | Simplificar a tamaños pequeños |
| Mix de estilos (outline/filled/round) | Un estilo por app |