---
name: "ux-ui-screen-design"
description: "Experto en UX/UI para diseño y rediseño de pantallas. Aplica principios de usabilidad, accesibilidad, jerarquía visual y patrones probados. Prioriza experiencia de usuario sobre estética."
version: "1.0.0"
author: "UX/UI Expert"
tags: ["ux", "ui", "design", "usability", "accessibility", "screen-design"]
---

# 🎨 UX/UI Screen Design Skill

> **"Diseña para el usuario, no para el stakeholder. La belleza emerge de la usabilidad."**

---

## 🎯 Cuándo usar esta skill

**SIEMPRE que:**
- ✅ Crees una pantalla nueva (formulario, lista, dashboard, detalle, onboarding, etc.)
- ✅ Rediseñes una pantalla existente (mejora usabilidad, modernización, migración)
- ✅ Revises una PR que afecte UI/UX
- ✅ Definieras especificaciones de una pantalla nueva
- ✅ Realices auditoría UX de pantallas existentes
- ✅ Prepares especificaciones para desarrollo

**NO uses esta skill para:**
- ❌ Cambios puramente de backend/API
- ❌ Configuración de infraestructura
- ❌ Migraciones de base de datos

---

## 🧠 Principios Fundamentales (SIEMPRE aplicar)

### 1. **Usuario Primero, Siempre**
- ¿Qué problema resuelve para el usuario?
- ¿Cuál es el objetivo principal del usuario en esta pantalla?
- ¿Qué fricción puedo eliminar?

### 2. **Simplicidad Radical**
- Una pantalla, **un objetivo principal** claro
- Elimina todo lo que no sirve al objetivo principal
- "La perfección se alcanza no cuando no hay nada más que añadir, sino cuando no hay nada más que quitar" — Antoine de Saint-Exupéry

### 3. **Consistencia como Contrato**
- Mismos patrones = misma comportamiento
- Sistema de diseño = lenguaje compartido
- Romper consistencia = romper confianza del usuario

### 4. **Feedback Inmediato y Honesto**
- Cada acción = respuesta visible (< 100ms ideal)
- Estados: idle → loading → success/error
- Nunca dejes al usuario preguntándose "¿pasó algo?"

### 5. **Accesibilidad No Negociable**
- Contraste mínimo 4.5:1 (WCAG 2.1 AA)
- Navegación 100% por teclado
- Screen readers: labels, roles, ARIA correctos
- No solo color para transmitir información

### 6. **Prevención > Corrección**
- Validación en tiempo real (no al enviar)
- Confirmaciones para acciones destructivas
- Undo > Confirmación modal cuando sea posible

### 7. **Carga Cognitiva Mínima**
- Agrupa información relacionada (Ley de proximity)
- Scan-friendly: headings, bullets, whitespace
- Memoria de trabajo: 7±2 items máximos visibles

---

## 📐 Anatomía de Pantalla Estándar

```
┌─────────────────────────────────────────────────────┐
│  APP BAR / HEADER (56-64px)                         │
│  [← Back]  Título Principal          [Acciones]     │
├─────────────────────────────────────────────────────┤
│  SUB-NAV / TABS (opcional, 48px)                    │
├─────────────────────────────────────────────────────┤
│                                                     │
│  CONTENIDO PRINCIPAL (flexible)                     │
│  ┌─────────────┐  ┌─────────────┐                  │
│  │  SECCIÓN A  │  │  SECCIÓN B  │  ← Grid/Columns  │
│  └─────────────┘  └─────────────┘                  │
│                                                     │
│  [Empty State] / [Loading] / [Error] / [Data]      │
│                                                     │
├─────────────────────────────────────────────────────┤
│  BOTTOM BAR / FAB (opcional, 56-72px)               │
│  [Acción Principal]          [Acciones Secundarias] │
└─────────────────────────────────────────────────────┘
```

**Reglas de Oro:**
- Header siempre visible (sticky) en scroll largo
- Acciones primarias: FAB (mobile) / Top-right (desktop)
- Estados vacíos: ilustración + mensaje humano + CTA claro
- Loading: skeleton > spinner (perceived performance)

---

## 🎨 Sistema Visual Mínimo Viable

### Tipografía (Escala 1.25)
| Token | Tamaño | Uso |
|-------|--------|-----|
| Display | 32-48px | Hero, números grandes |
| H1 | 28px | Título pantalla |
| H2 | 22px | Secciones |
| H3 | 18px | Sub-secciones |
| Body | 16px | Texto base |
| Caption | 14px | Metadatos, ayuda |
| Overline | 12px | Labels, categorías |

**Peso:** Regular (400) base, Medium (500) énfasis, SemiBold (600) headings

### Espaciado (Base 8px)
| Token | Valor | Uso |
|-------|-------|-----|
| xs | 4px | Icon-text gap |
| sm | 8px | Component padding |
| md | 16px | Component gap, card padding |
| lg | 24px | Section gap |
| xl | 32px | Section margin |
| xxl | 48px | Page margins |

### Color Semántico (no decorativo)
| Rol | Light | Dark | Uso |
|-----|-------|------|-----|
| Primary | #1976D2 | #90CAF9 | Acción principal |
| Success | #2E7D32 | #81C784 | Éxito, confirmado |
| Warning | #F57F17 | #FFB74D | Advertencia |
| Error | #C62828 | #EF5350 | Error, destructivo |
| Surface | #FFFFFF | #1E1E1E | Fondos tarjetas |
| Background | #F5F5F5 | #121212 | Fondo app |
| On-primary | #FFFFFF | #000000 | Texto sobre primario |

---

## ♿ Checklist Accesibilidad (WCAG 2.1 AA)

- [ ] Contraste texto ≥ 4.5:1 (grande 3:1)
- [ ] Contraste UI components ≥ 3:1
- [ ] Focus visible: outline 2px + offset 2px
- [ ] Orden tab lógico (izq→der, arriba→abajo)
- [ ] Skip to main content link
- [ ] ARIA labels en icon-only buttons
- [ ] Live regions para actualizaciones dinámicas
- [ ] Form labels asociados (for/id)
- [ ] Error messages vinculados (aria-describedby)
- [ ] No solo color: icon + texto + patrón
- [ ] Motion reduce: prefers-reduced-motion
- [ ] Zoom 200% sin pérdida funcionalidad

---

## 🧩 Patrones de Interacción Canónicos

### Formularios
```
Label (requerido *)
┌─────────────────────────┐
│ Input con hint          │  ← Helper text abajo
│ ▼ Error inline (rojo)   │  ← Solo si error
└─────────────────────────┘
[Cancelar]  [Guardar]     ← Primary a la derecha
```

**Reglas:**
- Label siempre visible (no placeholder-only)
- Validación inline al perder foco (blur)
- Submit deshabilitado hasta válido
- Autocomplete attributes correctos
- Enter = submit, Escape = cancel

### Listas/Tablas
| Elemento | Desktop | Mobile |
|----------|---------|--------|
| Row click | Navega | Navega |
| Hover | Highlight row | N/A |
| Actions | Inline (3 max) | Menú overflow |
| Bulk actions | Checkbox + toolbar | Bottom sheet |
| Empty state | Ilustración + CTA | Centrado |

### Estados Vacíos
```
┌─────────────────────────┐
│    📭  Ilustración      │
│    Sin documentos aún   │
│    Crea tu primero →    │  ← Primary button
└─────────────────────────┘
```

---

## 🔄 Flujo de Trabajo con Esta Skill

### Para Pantalla Nueva:
1. **Lee** `references/screen-anatomy.md` + `checklist-new-screen.md`
2. **Completa** `templates/screen-spec-template.md`
3. **Diseña** aplicando `references/visual-hierarchy.md` + `references/ui-patterns.md`
4. **Valida** con `checklist-new-screen.md` + `scripts/ux-audit.sh`
5. **Accesibilidad** → `references/accessibility.md` + `scripts/contrast-check.sh`

### Para Rediseño:
1. **Audita** con `templates/redesign-audit-template.md`
2. **Identifica** problemas usando `references/anti-patterns.md`
3. **Aplica** patrones de `references/ui-patterns.md`
4. **Valida** con `checklist-redesign.md`

---

## 📋 Checklists Rápidas

### Nueva Pantalla (`checklist-new-screen.md`)
- [ ] Objetivo único definido en spec
- [ ] Anatomía estándar respetada
- [ ] Jerarquía visual clara (H1→H2→Body)
- [ ] Espaciado sistema 8px
- [ ] Estados: empty, loading, error, success
- [ ] Formularios: labels, validación inline, submit deshabilitado
- [ ] Accesibilidad: contraste, focus, labels, ARIA
- [ ] Responsive: mobile ≤768px, tablet 768-1024px, desktop >1024px
- [ ] Loading states: skeleton > spinner
- [ ] Empty states: ilustración + copy humano + CTA

### Rediseño (`checklist-redesign.md`)
- [ ] Auditoría completada (`redesign-audit-template.md`)
- [ ] Problemas mapeados a anti-patterns
- [ ] Flujo usuario simplificado (menos clicks)
- [ ] Consistencia con design system
- [ ] Métricas de éxito definidas
- [ ] Test usabilidad planificado

---

## 📁 Archivos de Referencia (resumen)

| Archivo | Propósito |
|---------|-----------|
| `ux-principles.md` | 10 principios UX inquebrantables |
| `ui-patterns.md` | 20+ patrones listos para usar |
| `screen-anatomy.md` | Estructura estándar por tipo pantalla |
| `accessibility.md` | WCAG 2.1 AA checklist completo |
| `visual-hierarchy.md` | Tipografía, color, espaciado, grid |
| `ui-patterns.md` | Formularios, listas, tablas, cards, modals |
| `interaction-patterns.md` | Feedback, loading, undo, confirm |
| `form-design.md` | Validación, layout, autocomplete |
| `error-states.md` | Inline, toast, modal, empty |
| `loading-states.md` | Skeleton, progress, optimistic UI |
| `responsive-breakpoints.md` | Mobile/Tablet/Desktop tokens |
| `color-system.md` | Semántico, accesible, dark mode |
| `spacing-scale.md` | 8px base, tokens, componentes |
| `iconography.md` | Estilo, tamaños, accesibilidad |
| `motion-principles.md` | Duraciones, easing, reduce-motion |
| `checklist-new-screen.md` | 25 checks antes de PR |
| `checklist-redesign.md` | 15 checks auditoría |
| `anti-patterns.md` | 15+ anti-patrones con solución |

---

## ⚙️ Scripts Incluidos

```bash
# Auditoría rápida UX (usa checklist-new-screen.md)
.opencode/skills/ux-ui-screen-design/scripts/ux-audit.sh --screen "ruta/pantalla"

# Verificador contraste (WCAG)
.opencode/skills/ux-ui-screen-design/scripts/contrast-check.sh --fg "#1976D2" --bg "#FFFFFF"
```

---

## 🎯 Principio Guía Final

> **"Si dudas entre dos opciones, elige la que reduzca fricción al usuario. La coherencia interna vence a la innovación visual. La accesibilidad no es opcional."**

---

*Skill version 1.0.0 — Última actualización: 2024*