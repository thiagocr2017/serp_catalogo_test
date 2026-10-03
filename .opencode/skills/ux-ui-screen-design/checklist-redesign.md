# ✅ Checklist Rediseño / Auditoría UX

> **15 checks obligatorios antes de rediseñar. Si falla uno, no rediseñes a ciegas.**

---

## 🔍 Auditoría Previa (Obligatorio)

- [ ] **Auditoría completada** (`redesign-audit-template.md`)
- [ ] **Métricas baseline** capturadas (tasa conversión, tiempo tarea, errores, NPS)
- [ ] **User research** reciente (< 6 meses): interviews, analytics, heatmaps
- [ ] **Problemas reales** identificados (no asumidos)
- [ ] **Stakeholders** alineados en objetivo rediseño

---

## 🎯 Objetivos Medibles

- [ ] **Métrica primaria** definida (ej: reducir tiempo tarea 30%)
- [ ] **Métricas secundarias** (errores, satisfacción, tiempo)
- [ ] **Baseline** medido antes de empezar
- [ ] **Objetivo numérico** definido (ej: "reducir clicks de 8 a 5")
- [ ] **Plan de medición** post-lanzamiento (A/B test, cohortes)

---

## 🧭 Flujo de Usuario

- [ ] **Journey map** actual vs objetivo documentado
- [ ] **Puntos de fricción** mapeados (analytics + cualitativo)
- [ ] **Happy path** optimizado (menos clicks, menos pantallas)
- [ ] **Edge cases** cubiertos (vacío, error, permisos, offline)
- [ ] **Accesos directos** para usuarios expertos (shortcuts, power users)

---

## 🎨 Consistencia Visual

- [ ] **Design system** respetado (tokens, componentes)
- [ ] **Tipografía** consistente (escala, pesos)
- [ ] **Espaciado** sistema 8px respetado
- [ ] **Color semántico** respetado (primary/error/success)
- [ ] **Iconografía** consistente (outline/filled, tamaños)
- [ ] **Border radius** consistente (4/8/12/16px)
- [ ] **Sombras/elevación** escala consistente

---

## 📱 Responsive y Dispositivos

- [ ] **Mobile first** verificado (320px min)
- [ ] **Breakpoints** probados: 320, 375, 428, 768, 1024, 1440, 1920
- [ ] **Touch targets** ≥48x48px
- [ ] **Safe areas** respetadas (notch, home indicator)
- [ ] **Landscape** funcional
- [ ] **Orientación** lock solo si crítico

---

## ♿ Accesibilidad (WCAG 2.1 AA)

- [ ] **Contraste** ≥4.5:1 texto, ≥3:1 UI/grande
- [ ] **Focus visible** outline 2px + offset 2px
- [ ] **Labels** asociados (for/id)
- [ ] **ARIA labels** en icon-only buttons
- [ ] **ARIA live** en actualizaciones dinámicas
- [ ] **Skip link** funcional
- [ ] **Navegación teclado** completa (Tab/Enter/Esc)
- [ ] **Focus trap** en modales
- [ ] **Zoom 200%** sin pérdida funcionalidad
- [ ] **Screen reader** prueba (NVDA/VoiceOver)
- [ ] **prefers-reduced-motion** respetado

---

## 📝 Formularios y Validación

- [ ] **Labels visibles** + asterisco requeridos
- [ ] **Validación inline** (blur) + submit
- [ ] **Submit deshabilitado** hasta válido
- [ ] **Autofocus** primer campo
- [ ] **Autocomplete** attributes correctos
- [ ] **Error inline** + toast global
- [ ] **Submit deshabilitado** hasta válido
- [ ] **Autofocus** primer campo
- [ ] **Autocomplete** attributes correctos

---

## ⚡ Performance y Carga

- [ ] **Skeleton** > spinner > progress bar
- [ ] **Lazy load** imágenes/listas >50 items
- [ ] **Virtualización** listas >100 items
- [ ] **Code splitting** por ruta
- [ ] **Imágenes** WebP, lazy, responsive
- [ ] **Bundle size** controlado (< 200KB gzipped inicial)
- [ ] **CLS** < 0.1 (no layout shift)
- [ ] **TTI** < 3.5s en 3G

---

## 🔄 Estados y Edge Cases

- [ ] **Empty state**: ilustración + copy + CTA
- [ ] **Loading**: skeleton > spinner > progress
- [ ] **Error inline**: rojo, 12px, icono ⚠, texto claro
- [ ] **Toast error**: 5-6s, dismissible, retry
- [ ] **Modal error**: solo críticos
- [ ] **Focus automático** al primer error
- [ ] **Scroll suave** al primer error
- [ ] **Errores se limpian** al corregir (on change)

---

## 📱 Mobile y Touch

- [ ] **Touch targets** ≥48x48px
- [ ] **Safe areas** (notch, home indicator)
- [ ] **Keyboard** no tapa campos
- [ ] **Pull to refresh** si lista
- [ ] **Swipe actions** si lista accionable
- [ ] **Bottom sheet** en vez de modal completo
- [ ] **FAB** para acción principal

---

## 🧪 Testing y Validación

- [ ] **Usability test** 5 usuarios mínimos
- [ ] **A/B test** si cambio significativo
- [ ] **Analytics** eventos trackeados (funnel)
- [ ] **Error tracking** (Sentry/LogRocket)
- [ ] **Performance** Lighthouse >90
- [ ] **Regression** visual (Chromatic/Percy)
- [ ] **Cross-browser** (Chrome, Firefox, Safari, Edge)
- [ ] **Cross-device** (iOS Safari, Android Chrome)

---

## 📊 Métricas Post-Lanzamiento

- [ ] **Dashboards** creados (Mixpanel/Amplitude/GA4)
- [ ] **Alertas** configuradas (regression >5%)
- [ ] **Rollback plan** documentado
- [ ] **Feature flag** para rollback instantáneo
- [ ] **Comunicación** a usuarios si breaking change

---

## 🚀 Pre-Lanzamiento Final

- [ ] **Feature flag** activado en staging
- [ ] **QA** firma off en staging
- [ ] **Stakeholder demo** aprobado
- [ ] **Rollback plan** probado (< 5 min)
- [ ] **Comunicación** a usuarios si breaking
- [ ] **Documentación** actualizada
- [ ] **Training** soporte si necesario

---

> **Regla de Oro: Si no puedes medir la mejora, no rediseñes. El rediseño sin métricas es opiniones, no diseño.**