# 🧩 Patrones de UI Canónicos (Listos para Usar)

> **Patrones probados = menos fricción = mejores resultados. No reinventes la rueda.**

---

## 📝 Formularios

### Estructura Estándar
```
Label (requerido *)
┌─────────────────────────┐
│ Input con hint          │  ← Helper text abajo
│ ▼ Error inline (rojo)   │  ← Solo si error
└─────────────────────────┘
[Cancelar]  [Guardar]     ← Primary a la derecha
```

### Reglas Inquebrantables
- ✅ Label siempre visible (no placeholder-only)
- ✅ Validación inline al perder foco (blur)
- ✅ Submit deshabilitado hasta válido
- ✅ Autocomplete attributes correctos
- ✅ Enter = submit, Escape = cancel
- ✅ Autofocus en primer campo

### Layouts por Contexto
| Contexto | Layout | Columnas |
|----------|--------|----------|
| Simple (≤3 campos) | Stack vertical | 1 |
| Medio (4-8 campos) | Grid 2 cols | 2 |
| Complejo (>8) | Secciones + accordion | 1-2 |
| Mobile | Siempre 1 columna | 1 |

### Validación
| Momento | Tipo | UX |
|---------|------|-----|
| On blur | Inline | Inmediato |
| On submit | Completa | Bloqueante |
| On change | Opcional | Solo si crítico |

---

## 📋 Listas y Tablas

### Lista Simple (Mobile First)
```
┌─────────────────────────────────┐
│ 📄 Item 1              [▶]      │
├─────────────────────────────────┤
│ 📄 Item 2              [▶]      │
├─────────────────────────────────┤
│ 📄 Item 3              [▶]      │
└─────────────────────────────────┘
```

### Tabla Desktop (Dense)
| Columna | Alineación | Truncamiento |
|---------|------------|--------------|
| ID | Left | Ellipsis |
| Nombre | Left | Ellipsis + tooltip |
| Estado | Center | Badge |
| Acciones | Right | Icon buttons |

### Acciones por Contexto
| Contexto | Desktop | Mobile |
|----------|---------|--------|
| 1-2 acciones | Inline | Inline |
| 3-4 acciones | Dropdown | Bottom sheet |
| 5+ | Toolbar + overflow | Bottom sheet |
| Bulk | Checkbox + toolbar | Bottom sheet + fab |

---

## 🃏 Cards

### Estructura Estándar
```
┌─────────────────────────────────┐
│ 🖼️  Thumbnail (opcional)        │
├─────────────────────────────────┤
│ Título Principal                │
│ Subtítulo / metadata            │
├─────────────────────────────────┤
│ [Acción 1] [Acción 2] [▼]       │
└─────────────────────────────────┘
```

### Variantes
| Tipo | Uso | Imagen |
|------|-----|--------|
| Media | Contenido rico | 16:9 |
| Product | E-commerce | 1:1 |
| Compact | Listas densas | 4:3 |
| Profile | Perfiles | 1:1 circular |

---

## 🪟 Modales y Drawers

### Cuándo Usar Cada Uno
| Tipo | Caso de Uso | Ancho |
|--------|-------------|-------|
| Modal | Confirmación, form corto, alerta crítica | 400-560px |
| Drawer | Formulario complejo, filtros, detalles | 320-720px |
| Bottom Sheet | Acciones móviles, share, pickers | 50-90%vh |
| Toast | Feedback no crítico, auto-dismiss | 300px max |

### Estructura Modal
```
┌─────────────────────────────────────┐
│ ✕  Título                    [×]    │
├─────────────────────────────────────┤
│                                     │
│   Contenido / Formulario            │
│                                     │
├─────────────────────────────────────┤
│  [Cancelar]          [Acción Prim.] │
└─────────────────────────────────────┘
```

**Reglas:**
- ✅ Escape = cerrar
- ✅ Click overlay = cerrar (salvo form dirty)
- ✅ Focus trap dentro
- ✅ Restore focus al cerrar
- ❌ No modales anidados

---

## 🔘 Botones y Acciones

### Jerarquía Visual
| Tipo | Estilo | Uso |
|------|--------|-----|
| Primary | Filled, brand color | 1 por pantalla |
| Secondary | Outlined, border | Secundarias |
| Tertiary | Text only, color | Menos énfasis |
| Ghost | Text only, sin bg | Subtle |
| Destructive | Red filled/outlined | Eliminar, danger |

### Estados
| Estado | Visual |
|--------|--------|
| Default | Color base |
| Hover | +10% brightness / shadow |
| Pressed | -10% brightness / scale 0.98 |
| Disabled | 38% opacity, no pointer |
| Loading | Spinner 16px, disabled |

### Tamaños
| Tamaño | Padding | Font | Uso |
|--------|---------|------|-----|
| Small | 8px 16px | 13px | Dense UI |
| Medium | 10px 24px | 14px | Default |
| Large | 12px 32px | 16px | Hero, FAB |

---

## 🏷️ Chips y Badges

### Chips (Interactivos)
```
[Filtro ▼]  [Etiqueta ×]  [Opción ▼]
```
- Clickable, removable, selectable
- Max 3 en fila móvil

### Badges (Informativos)
| Tipo | Color | Uso |
|------|-------|-----|
| Count | Primary bg | Notificaciones |
| Status | Semántico | Estados |
| Label | Neutral | Categorías |
| New | Accent | Novedad |

---

## 🧭 Navegación

### App Bar
```
[←]  Título Principal    [🔍] [⋮]
```
- Título truncado con ellipsis
- Acciones max 3 (overflow menú)
- Back navigation consistente

### Tabs
```
[Activo]  [Pendiente]  [Historial]
```
- Indicador animado
- Swipe entre tabs (mobile)
- Lazy load contenido

### Breadcrumbs
```
Inicio > Productos > Electrónica > Móviles
```
- Separador: `>` o `/`
- Último = actual (no clicable)
- Max 4 niveles visibles

---

## 📱 Bottom Navigation (Mobile)
```
[🏠 Inicio] [📦 Productos] [👤 Perfil]
```
- 3-5 destinos principales
- Icon + label (o solo icon si obvio)
- Estado activo: color primary + label

---

## 📊 Data Display

### KPI Cards
```
┌─────────────────────┐
│  📈  Ventas Mes     │
│       $12,450       │  ← Large number
│   +12% vs mes ant   │  ← Trend
└─────────────────────┘
```

### Progress Indicators
| Tipo | Uso | Visual |
|------|-----|--------|
| Linear determinate | Progreso conocido | Bar |
| Linear indeterminate | Carga desconocida | Animation |
| Circular | Acciones, steps | Ring |
| Steps | Wizard, onboarding | Numbered |

---

## 🔍 Search & Filter

### Search Bar
```
┌─────────────────────────────────┐
│ 🔍  Buscar productos...    [×]  │
└─────────────────────────────────┘
```
- Debounce 300ms
- Historial reciente
- Sugerencias/autocomplete

### Filtros
| Tipo | UI | Uso |
|------|-----|-----|
| Chips | Chips removibles | Multi-select visible |
| Drawer | Panel lateral | Complejos |
| Dropdown | Dropdown | Simples |
| Chips + count | Chips con badge | Conteo visible |

---

## ⚠️ Anti-Patrones Comunes (NO HACER)

| ❌ Anti-Patrón | ✅ Solución |
|---------------|-------------|
| Placeholder como label | Label visible siempre |
| Validación solo al submit | Validación inline (blur) |
| Submit habilitado siempre | Deshabilitado hasta válido |
| Error solo en toast | Error inline + toast |
| Modal para todo | Inline > Drawer > Modal |
| Spinner en botón > 3s | Skeleton / progreso real |
| Placeholder como ayuda | Helper text visible |
| Validación solo cliente | Server + cliente |
| Color solo para estado | Icon + texto + patrón |
| Scroll horizontal en tabla | Cards / stack en mobile |

---

## 📱 Responsive Patterns

| Componente | ≤480px | 481-768px | 769-1024px | >1024px |
|------------|--------|-----------|------------|---------|
| Form | 1 col | 1-2 col | 2-3 col | 3-4 col |
| Tabla | Cards | Horiz scroll | Tabla | Tabla |
| Nav | Bottom nav | Bottom nav | Sidebar | Top nav |
| Modal | Full screen | 90% | 50% | 40% |
| Cards | 1 col | 2 col | 3 col | 4 col |
| FAB | Bottom center | Bottom center | - | - |

---

## 🎯 Quick Reference: Decisión Rápida

| Pregunta | Respuesta |
|----------|-----------|
| ¿Formulario simple? | Stack vertical, 1 col |
| ¿Muchos campos? | Secciones + accordion |
| ¿Tabla densa? | Desktop: tabla / Mobile: cards |
| ¿Acción destructiva? | Modal confirm + undo |
| ¿Lista vacía? | Ilustración + CTA |
| ¿Carga > 300ms? | Skeleton |
| ¿Error crítico? | Inline + toast |
| ¿Acción primaria? | 1 por pantalla, FAB/top-right |
| ¿Navegación profunda? | Breadcrumbs + back |
| ¿Duda entre 2 opciones? | La que reduce fricción |