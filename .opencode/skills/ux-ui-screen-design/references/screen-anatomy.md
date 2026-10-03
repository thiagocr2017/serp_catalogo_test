# 📐 Anatomía de Pantalla por Tipo

> **Estructura estándar = usuarios felices = menos soporte.**

---

## 📱 Tipos de Pantalla y su Anatomía

### 1. **Formulario (Create/Edit)**
```
┌─────────────────────────────────────┐
│ ←  Título Pantalla          [Guardar] │  ← App Bar
├─────────────────────────────────────┤
│                                     │
│  Sección 1                          │
│ ┌─────────────────────────────────┐ │
│ │ Campo 1 *                       │ │
│ │ ┌─────────────────────────────┐ │ │
│  Campo 2 *                       │
│ └─────────────────────────────────┘ │
│                                     │
│  Sección 2                          │
│ ┌─────────────────────────────────┐ │
│  Campo 3                            │
│ └─────────────────────────────────┘ │
│                                     │
├─────────────────────────────────────┤
│           [Cancelar] [Guardar]      │  ← Sticky footer
└─────────────────────────────────────┘
```

**Elementos Obligatorios:**
- ✅ Título claro (qué se crea/edit)
- ✅ Botón primario sticky (bottom/right)
- ✅ Cancel con confirmación si dirty
- ✅ Validación inline
- ✅ Estados: dirty, saving, error

---

### 2. **Lista / Índice (List/Index)**
```
┌─────────────────────────────────────┐
│ 🔍 Buscar...              [+ Nuevo] │  ← Header + Actions
├─────────────────────────────────────┤
│ [Filtros ▼] [Columnas ▼] [Vista ▼]  │  ← Toolbar
├─────────────────────────────────────┤
│ □  Item 1          Estado  [⋮]      │
│ □  Item 2          Estado  [⋮]      │
│ □  Item 3          Estado  [⋮]      │
├─────────────────────────────────────┤
│ [◀ Anterior]  1 2 3 ... [Siguiente] │  ← Pagination
└─────────────────────────────────────┘
```

**Elementos Obligatorios:**
- ✅ Search + filters visibles
- ✅ Acciones bulk (si aplica)
- ✅ Empty state ilustrado
- ✅ Paginación / infinite scroll
- ✅ Columnas configurables

---

### 3. **Detalle / Vista (Detail/View)**
```
┌─────────────────────────────────────┐
│ ←  Título Item              [⋮]     │
├─────────────────────────────────────┤
│ 🖼️  Imagen / Avatar                 │
│  Título Principal                   │
│  Subtítulo / Estado                 │
├─────────────────────────────────────┤
│  Sección: Detalles                  │
│  ┌─────────────┬─────────────────┐  │
│  │ Campo A     │ Valor A         │  │
│  │ Campo B     │ Valor B         │  │
│  └─────────────┴─────────────────┘  │
├─────────────────────────────────────┤
│  Acciones: [Editar] [Eliminar] [⋮]  │
└─────────────────────────────────────┘
```

---

### 4. **Dashboard / Resumen**
```
┌─────────────────────────────────────┐
│ Título Dashboard        [Filtros]   │
├─────────────────────────────────────┤
│ ┌─────────┐ ┌─────────┐ ┌─────────┐ │
│ │ KPI 1   │ │ KPI 2   │ │ KPI 3   │ │  ← KPI Cards
│ │ $12.4K  │ │ 1,234   │ │ 98.5%   │ │
│ └─────────┘ └─────────┘ └─────────┘ │
├─────────────────────────────────────┤
│ 📈 Gráfico Principal                │
│ ┌─────────────────────────────────┐ │
│ │        Chart Area               │ │
│ └─────────────────────────────────┘ │
├─────────────────────────────────────┤
│ Tabla Resumen / Lista Reciente      │
└─────────────────────────────────────┘
```

---

### 5. **Wizard / Multi-step**
```
┌─────────────────────────────┐
│ Paso 1 ●────○────○  33%     │
├─────────────────────────────┤
│                             │
│   Contenido Paso 1          │
│                             │
├─────────────────────────────┤
│ [Cancelar]      [Siguiente] │
└─────────────────────────────┘
```

**Reglas:**
- ✅ Progress indicator visible
- ✅ Pasos previos clicables (si válidos)
- ✅ Validación por paso
- ✅ Resumen final antes de confirmar

---

### 6. **Modal / Drawer**
```
┌─────────────────────────────────────┐
│ ✕  Título                    [×]    │
├─────────────────────────────────────┤
│                                     │
│   Contenido / Formulario            │
│                                     │
├─────────────────────────────────────┤
│ [Cancelar]              [Aceptar]   │
└─────────────────────────────────────┘
```

---

### 6. **Empty State**
```
┌─────────────────────────────────────┐
│                                     │
│        📭  Ilustración              │
│                                     │
│     No hay elementos aún            │
│                                     │
│     [Crear Primero]  ← Primary      │
│                                     │
└─────────────────────────────────────┘
```

---

## 🧱 Componentes Reutilizables por Tipo

| Tipo Pantalla | Componentes Requeridos | Opcionales |
|---------------|------------------------|------------|
| Form | ListTile, Input, Select, DatePicker, Switch, Button | DatePicker, Autocomplete, FileUpload |
| List | SearchBar, FilterChips, DataTable/ListView, Pagination | BulkActions, ColumnPicker |
| Detail | Header, SectionCard, ActionButtons | RelatedItems, Timeline |
| Dashboard | KPICard, Chart, DataTable, QuickActions | DateRangePicker, Export |
| Wizard | Stepper, StepContent, NavigationButtons | ProgressSummary |
| Modal | Header, Content, Actions | CloseIcon, Backdrop |
| EmptyState | Illustration, Title, Description, PrimaryCTA | SecondaryCTA |

---

## 📱 Responsive por Tipo

| Tipo | Mobile (≤480) | Tablet (481-768) | Desktop (>768) |
|------|---------------|------------------|----------------|
| Form | 1 col, full width | 1-2 col | 2-3 col, max 720px |
| List | Cards, swipe actions | Table + cards | Tabla densa |
| Detail | Stack vertical | 2-col sidebar | 2-col + sidebar |
| Dashboard | Stack KPIs, stack charts | 2-col KPIs | Grid 3-4 col |
| Form | Stack, bottom actions | 1-2 col, sticky actions | 2-col, sticky actions |
| Modal | Full screen | 90% width | 50% width |

---

## 🧭 Navegación por Tipo

| Tipo | Navegación Primaria | Secundaria |
|------|---------------------|------------|
| Form | Back + Save/Cancel | Breadcrumbs |
| List | Search + Filters | Breadcrumbs + Pagination |
| Detail | Back + Actions | Tabs/Sub-tabs |
| Dashboard | Global nav + Tabs | Date picker + Filters |
| Wizard | Stepper + Next/Back | Stepper |
| Modal | Close + Actions | - |
| Empty | CTA Principal | Help link |

---

## 🎯 Checklist Anatomía por Tipo

### Formulario
- [ ] Título claro (Crear/Editar + Entidad)
- [ ] Botón guardar sticky
- [ ] Cancel con confirmación si dirty
- [ ] Validación inline (blur)
- [ ] Submit deshabilitado hasta válido
- [ ] Autofocus primer campo
- [ ] Autocomplete attributes

### Lista
- [ ] Search + filtros visibles
- [ ] Empty state con CTA
- [ ] Paginación / infinite scroll
- [ ] Columnas configurables
- [ ] Acciones bulk si >1 selección

### Detalle
- [ ] Header con título + acciones
- [ ] Secciones agrupadas lógicamente
- [ ] Acciones contextuales
- [ ] Estados vacíos en secciones

### Dashboard
- [ ] KPIs arriba (3-5 máx)
- [ ] Gráfico principal
- [ ] Tabla/lista accionable
- [ ] Filtros de fecha globales

### Wizard
- [ ] Stepper visible
- [ ] Validación por paso
- [ ] Resumen final
- [ ] Pasos previos editables

### Modal
- [ ] Focus trap
- [ ] Escape = cerrar
- [ ] Overlay click = cerrar (si clean)
- [ ] Restore focus al cerrar

### Empty State
- [ ] Ilustración relevante
- [ ] Copy humano (no técnico)
- [ ] CTA primaria clara
- [ ] Link ayuda si complejo