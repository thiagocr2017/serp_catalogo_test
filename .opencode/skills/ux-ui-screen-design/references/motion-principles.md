# 🎬 Principios de Movimiento y Animación

> **El movimiento guía, no decora. Cada animación tiene propósito.**

---

## ⏱️ Duraciones Estándar

| Tipo | Duración | Easing | Uso |
|------|----------|--------|-----|
| **Instant** | 0ms | - | Estados binarios (toggle) |
| **Fast** | 100-150ms | ease-out | Micro-interacciones, hover, ripple |
| **Normal** | 200-250ms | ease-out | Transiciones estándar, modales |
| **Slow** | 300-400ms | ease-in-out | Navegación, drawers, bottom sheets |
| **Page** | 300-500ms | ease-in-out | Transiciones página |

### Tokens CSS
```css
:root {
  --duration-instant: 0ms;
  --duration-fast: 100ms;
  --duration-normal: 200ms;
  --duration-slow: 300ms;
  --duration-page: 400ms;

  --easing-linear: linear;
  --easing-ease-in: cubic-bezier(0.4, 0, 1, 1);
  --easing-ease-out: cubic-bezier(0, 0, 0.2, 1);
  --easing-ease-in-out: cubic-bezier(0.4, 0, 0.2, 1);
  --easing-emphasized: cubic-bezier(0.4, 0, 0.2, 1);
  --easing-bounce: cubic-bezier(0.34, 1.56, 0.64, 1);
}
```

---

## 🎯 Cuándo Animar (y Cuándo No)

### ✅ SÍ Animar
- Transiciones de estado (hover, focus, active)
- Navegación entre pantallas
- Feedback de acciones (ripple, loading)
- Entrada/salida de modales, drawers, toasts
- Expandir/colapsar (accordions, trees)
- Indicadores de progreso
- Transiciones de página

### ❌ NO Animar
- Cambios de contenido instantáneos (tabs, sorting)
- Scroll nativo (usa scroll-behavior: smooth si necesario)
- Text rendering changes
- Layout shifts que causan reflow masivo
- Cuando `prefers-reduced-motion: reduce`

---

## 🎭 Easing Functions

### Estándar (Material Design)
```css
/* Ease-out: Entrada natural, salida rápida */
--easing-ease-out: cubic-bezier(0, 0, 0.2, 1);

/* Ease-in: Entrada lenta, salida natural */
--easing-ease-in: cubic-bezier(0.4, 0, 1, 1);

/* Ease-in-out: Equilibrado */
--easing-ease-in-out: cubic-bezier(0.4, 0, 0.2, 1);

/* Emphasized: Más dramático para atención */
--easing-emphasized: cubic-bezier(0.4, 0, 0.2, 1);

/* Bounce: Para celebraciones, éxito */
--easing-bounce: cubic-bezier(0.34, 1.56, 0.64, 1);
```

### Cuál Usar
| Situación | Easing |
|-----------|--------|
| Entrada (enter) | ease-out |
| Salida (exit) | ease-in |
| Transición completa | ease-in-out |
| Llamar atención | emphasized / bounce |
| Lineal (spinners) | linear |

---

## 🎯 Patrones de Animación

### 1. **Fade + Slide (Entrada/Salida)**
```css
/* Enter */
@keyframes fadeInUp {
  from { opacity: 0; transform: translateY(16px); }
  to { opacity: 1; transform: translateY(0); }
}

/* Exit */
@keyframes fadeOutDown {
  from { opacity: 1; transform: translateY(0); }
  to { opacity: 0; transform: translateY(16px); }
}

.fade-in-up {
  animation: fadeInUp var(--duration-normal) var(--easing-ease-out);
}
.fade-out-down {
  animation: fadeOutDown var(--duration-fast) var(--easing-ease-in);
}
```

### 2. **Scale (Modales, Tooltips)**
```css
@keyframes scaleIn {
  from { opacity: 0; transform: scale(0.9); }
  to { opacity: 1; transform: scale(1); }
}

@keyframes scaleOut {
  from { opacity: 1; transform: scale(1); }
  to { opacity: 0; transform: scale(0.95); }
}

.scale-in {
  animation: scaleIn var(--duration-normal) var(--easing-ease-out);
}
.scale-out {
  animation: scaleOut var(--duration-fast) var(--easing-ease-in);
}
```

### 3. **Slide (Drawers, Bottom Sheets)**
```css
@keyframes slideUp {
  from { transform: translateY(100%); }
  to { transform: translateY(0); }
}

@keyframes slideDown {
  from { transform: translateY(0); }
  to { transform: translateY(100%); }
}

.slide-up { animation: slideIn var(--duration-slow) var(--easing-ease-out); }
.slide-down { animation: slideOut var(--duration-normal) var(--easing-ease-in); }
```

### 4. **Expand/Collapse (Accordions)**
```css
@keyframes expand {
  from { height: 0; opacity: 0; }
  to { height: auto; opacity: 1; }
}

@keyframes collapse {
  from { height: auto; opacity: 1; }
  to { height: 0; opacity: 0; }
}

/* Nota: height: auto no se puede animar directamente.
   Usar max-height o transform: scaleY() */
```

---

## ♿ Reduce Motion (Accesibilidad)

### CSS
```css
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

### JavaScript Check
```javascript
const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

if (!prefersReducedMotion) {
  // Animar
  element.animate(keyframes, { duration: 300, easing: 'ease-out' });
} else {
  // Sin animación, estado final inmediato
  element.style.opacity = 1;
}
```

---

## ♿ Accesibilidad y Movimiento

### Reglas de Oro
1. **Respeta `prefers-reduced-motion`** - Siempre
2. **No auto-play** - Carousels, videos, animaciones infinitas
3. **Pause/Stop** - Controles para pausar animaciones > 5s
4. **No flash > 3Hz** - WCAG 2.3.1
4. **Parallax** - Solo si `prefers-reduced-motion: no-preference`

### Checklist
- [ ] `@media (prefers-reduced-motion: reduce)` implementado
- [ ] No auto-play en carousels/videos
- [ ] Controles pause/play en animaciones > 5s
- [ ] No flash > 3Hz
- [ ] Parallax solo si `no-preference`
- [ ] Transiciones instantáneas en reduced-motion

---

## 🎯 Micro-interacciones

### Ripple Effect
```css
@keyframes ripple {
  from { transform: scale(0); opacity: 0.3; }
  to { transform: scale(4); opacity: 0; }
}

.ripple {
  position: relative;
  overflow: hidden;
}
.ripple::after {
  content: '';
  position: absolute;
  border-radius: 50%;
  background: currentColor;
  opacity: 0.3;
  animation: ripple 600ms ease-out;
  pointer-events: none;
}
```

### Hover States
```css
.card {
  transition: transform var(--duration-fast) var(--easing-ease-out),
              box-shadow var(--duration-fast) var(--easing-ease-out);
}
.card:hover {
  transform: translateY(-4px);
  box-shadow: 0 12px 24px rgba(0,0,0,0.15);
}

.button {
  transition: transform var(--duration-fast) var(--easing-ease-out);
}
.button:active {
  transform: scale(0.98);
}
```

### Focus Ring
```css
:focus-visible {
  outline: 2px solid var(--color-primary);
  outline-offset: 2px;
}

/* Para elementos que necesitan offset personalizado */
.custom-focus:focus-visible {
  outline: 2px solid var(--color-primary);
  outline-offset: 4px;
}
```

### Loading States
```css
@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

.skeleton {
  animation: pulse 1.5s ease-in-out infinite;
  background: linear-gradient(90deg, 
    var(--surface-variant) 25%, 
    var(--surface-container-high) 50%, 
    var(--surface-variant) 75%
  );
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
}

@keyframes shimmer {
  0% { background-position: -200% 0; }
  100% { background-position: 200% 0; }
}
```

---

## 🎯 Checklist Animaciones

- [ ] Duraciones: instant(0) / fast(100-150) / normal(200-250) / slow(300-400) / page(300-500)
- [ ] Easing: ease-out (enter), ease-in (exit), ease-in-out (transitions)
- [ ] `prefers-reduced-motion: reduce` respaldado
- [ ] No auto-play carousels/videos
- [ ] Pause/stop en animaciones > 5s
- [ ] Focus visible en todos interactivos
- [ ] No flash > 3Hz
- [ ] Parallax solo si `no-preference`
- [ ] Loading states: skeleton > spinner > progress
- [ ] Optimistic UI para acciones reversibles
- [ ] Undo > confirmación para acciones reversibles
- [ ] Focus trap en modales/drawers
- [ ] Focus restoration al cerrar modales