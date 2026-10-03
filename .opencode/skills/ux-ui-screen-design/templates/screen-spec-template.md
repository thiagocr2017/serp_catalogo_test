# 📋 Especificación de Pantalla

> **Completa esto ANTES de diseñar. Una spec clara = menos iteraciones.**

---

## 📋 Información General

| Campo | Valor |
|-------|-------|
| **Nombre Pantalla** | |
| **Tipo** | Form / List / Detail / Dashboard / Wizard / Modal / Empty |
| **Ruta** | `/ruta/pantalla` |
| **Autor** | |
| **Fecha** | |
| **Versión** | |
| **Estado** | Draft / Review / Approved / Implemented |

---

## 🎯 Objetivo y Usuario

| Campo | Descripción |
|-------|-------------|
| **Objetivo Principal** | Una frase: qué logra el usuario |
| **Usuario Objetivo** | Rol, experiencia, contexto |
| **Problema que Resuelve** | Pain point actual |
| **Métrica de Éxito** | KPI medible (ej: "reducir tiempo 30%") |

---

## 👤 User Journey

### Happy Path
```
Paso 1 → Paso 2 → Paso 3 → Éxito
```

### Edge Cases
| Caso | Comportamiento Esperado |
|------|-------------------------|
| Vacío | |
| Error validación | |
| Error servidor | |
| Sin permisos | |
| Offline | |
| Datos duplicados | |

---

## 📐 Wireframe / Estructura

### Anatomía
```
[Header] ← Título + Acciones
[Content] ← Form / List / Detail / Dashboard
[Footer/Sticky] ← Acciones principales
```

### Componentes Requeridos
| Componente | Props / Props Requeridos |
|------------|--------------------------|
| | |
| | |

---

## 📝 Especificación de Campos (si Form)

| Campo | Tipo | Requerido | Validación | Autocomplete | Helper |
|-------|------|-----------|------------|--------------|--------|
| | | | | | |
| | | | | | |

---

## 🎨 Estados de la Pantalla

| Estado | Descripción | UI |
|--------|-------------|----|
| Loading inicial | | Skeleton |
| Empty | | Ilustración + CTA |
| Error | | Inline + Toast |
| Success | | Toast + navigate |
| Empty (permisos) | | Mensaje + acción |
| Offline | | Banner + queue |

---

## 🔄 Interacciones y Flujo

### Acciones Principales
| Acción | Trigger | Feedback | Navegación |
|--------|---------|----------|------------|
| Guardar | Click btn | Loading → Toast → Nav | Go to list/detail |
| Cancelar | Click btn | Confirm si dirty | Back |
| Eliminar | Click btn | Modal confirm → Undo | Stay / Back |

### Validaciones
| Campo | Regla | Mensaje Error |
|-------|-------|---------------|
| | | |

---

## ♿ Accesibilidad

- [ ] Contraste ≥ 4.5:1
- [ ] Focus visible
- [ ] Labels + for/id
- [ ] ARIA labels en icon-only
- [ ] ARIA live en dinámicos
- [ ] Skip link
- [ ] Navegación teclado
- [ ] Focus trap modales
- [ ] Zoom 200%

---

## 📱 Responsive

| Breakpoint | Layout | Acciones |
|-----------|--------|----------|
| Mobile (≤480) | | |
| Tablet (481-768) | | |
| Desktop (769-1024) | | |
| Large (>1024) | | |

---

## ♿ Accesibilidad

- [ ] Contraste ≥ 4.5:1
- [ ] Focus visible
- [ ] Labels + for/id
- [ ] ARIA labels
- [ ] ARIA live
- [ ] Skip link
- [ ] Teclado completo
- [ ] Focus trap
- [ ] Zoom 200%

---

## 🧪 Testing

- [ ] Unit tests validación
- [ ] Integration submit flow
- [ ] E2E happy path + 2 edge
- [ ] Visual regression
- [ ] A11y audit (axe-core)
- [ ] Performance (Lighthouse >90)

---

## 📋 Notas y Decisiones

| Decisión | Justificación |
|----------|---------------|
| | |

---

## ✅ Aprobaciones

| Rol | Nombre | Firma | Fecha |
|-----|--------|-------|-------|
| Product Designer | | | |
| Tech Lead | | | |
| Product Owner | | | |