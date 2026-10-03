# ✅ Checklist Nueva Pantalla

> **25 checks obligatorios antes de hacer PR. Si falla uno, no merge.**

---

## 🎯 Objetivo y Alcance

- [ ] **Objetivo único** definido en una frase
- [ ] **Usuario objetivo** identificado
- [ ] **Flujo principal** documentado (happy path)
- [ ] **Casos edge** identificados (vacío, error, loading)

---

## 🏗️ Estructura y Anatomía

- [ ] **Anatomía estándar** respetada (header, content, footer)
- [ ] **Header**: título claro + acciones (max 3)
- [ ] **Contenido**: jerarquía visual clara (H1→H2→Body)
- [ ] **Footer/Acciones**: sticky si scroll largo
- [ ] **Navegación**: back visible, breadcrumbs si profundo

---

## 🎨 Visual y Jerarquía

- [ ] **Tipografía**: escala 1.25, pesos correctos (H1=32px/600, H2=22px/600, Body=16px/400)
- [ ] **Espaciado**: múltiplos de 8px (space-4=16px default)
- [ ] **Color**: semántico (primary/error/success), no decorativo
- [ ] **Contraste**: ≥4.5:1 texto, ≥3:1 UI/grande
- [ ] **Focus visible**: outline 2px + offset 2px
- [ ] **Estados**: hover, focus, active, disabled, loading, error

---

## 📝 Formularios

- [ ] **Labels visibles** + asterisco en requeridos
- [ ] **Validación inline** (on blur) + submit
- [ ] **Submit deshabilitado** hasta válido
- [ ] **Autofocus** primer campo
- [ ] **Autocomplete** attributes correctos
- [ ] **Helper text** donde necesario
- [ ] **Error inline** + toast global
- [ ] **Autocomplete attributes** correctos (email, tel, etc.)
- [ ] **Submit deshabilitado** hasta válido
- [ ] **Autofocus** primer campo

---

## 📱 Responsive

- [ ] **Mobile** (≤480px): 1 col, full width, bottom actions
- [ ] **Tablet** (481-768px): 2 cols, side-by-side
- [ ] **Desktop** (769-1024px): 2-3 cols, max 720px form
- [ ] **Large** (>1024px): 3-4 cols, max 1200px container
- [ ] **Touch targets**: ≥48x48px
- [ ] **No horizontal scroll** en mobile

---

## ♿ Accesibilidad

- [ ] **Contraste**: ≥4.5:1 texto, ≥3:1 UI/grande
- [ ] **Focus visible**: outline 2px + offset 2px
- [ ] **Labels** asociados (for/id)
- [ ] **ARIA labels** en icon-only buttons
- [ ] **ARIA live** en actualizaciones dinámicas
- [ ] **Skip link** funcional
- [ ] **Navegación teclado** completa (Tab/Enter/Esc)
- [ ] **Focus trap** en modales
- [ ] **Zoom 200%** sin pérdida funcionalidad
- [ ] **Screen reader** prueba (NVDA/VoiceOver)

---

## 🔄 Estados de Carga y Error

- [ ] **Loading**: skeleton > spinner > progress
- [ ] **Empty state**: ilustración + copy humano + CTA
- [ ] **Error inline**: rojo, 12px, icono ⚠, texto claro
- [ ] **Toast error**: 5-6s, dismissible, acción retry
- [ ] **Modal error**: solo críticos, acciones claras
- [ ] **Focus automático** al primer error en submit
- [ ] **Scroll suave** al primer error
- [ ] **Errores se limpian** al corregir (on change)

---

## ⚡ Performance y UX

- [ ] **Skeleton** > spinner > progress bar
- [ ] **Optimistic UI** para likes/toggles
- [ ] **Rollback** en error optimistic UI
- [ ] **Undo** > confirmación para acciones reversibles
- [ ] **Debounce** búsqueda (300ms)
- [ ] **Lazy load** imágenes/listas largas
- [ ] **Virtualización** listas >100 items
- [ ] **No layout shift** (CLS < 0.1)

---

## 📱 Estados y Edge Cases

- [ ] **Empty state**: ilustración + copy humano + CTA
- [ ] **Loading skeleton** (no spinner solo)
- [ ] **Error parcial** (fallo parcial en bulk)
- [ ] **Offline**: banner + queue actions
- [ ] **Permisos**: estados vacíos por permisos
- [ ] **Offline queue** sincroniza al reconectar

---

## 📱 Mobile Específico

- [ ] **Touch targets** ≥48x48px
- [ ] **Safe areas** (notch, home indicator)
- [ ] **Keyboard** no tapa campos (scroll into view)
- [ ] **Pull to refresh** si lista
- [ ] **Swipe actions** si lista accionable
- [ ] **Bottom sheet** en vez de modal completo
- [ ] **FAB** para acción principal

---

## 🧪 Testing

- [ ] **Unit tests** lógica validación
- [ ] **Integration** submit flow
- [ ] **E2E** happy path + 2 edge cases
- [ ] **Visual regression** (Chromatic/Percy)
- [ ] **A11y audit** (axe-core)
- [ ] **Performance** (Lighthouse >90)

---

## 📋 Documentación

- [ ] **Spec** actualizado en `/docs/screens/`
- [ ] **Figma/Design** linkado en PR
- [ ] **Decisiones UX** documentadas en PR
- [ ] **Breaking changes** documentados

---

## 🚀 Pre-Merge Final

- [ ] **Self-review** completado
- [ ] **Design review** aprobado
- [ ] **QA** en staging
- [ ] **Analytics** eventos trackeados
- [ ] **Rollback plan** si rompe
- [ ] **Feature flag** si risky

---

> **Si dudas en algún check → No merges. Pregunta al equipo UX.**