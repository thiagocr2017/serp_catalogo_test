# ♿ Accesibilidad - WCAG 2.1 AA (No Negociable)

> **La accesibilidad no es opcional. Si no es accesible, está roto.**

---

## 📋 Checklist WCAG 2.1 AA Completo

### 1.1 No Texto
- [ ] **1.1.1** Todo contenido no textual tiene alternativa textual
  - Imágenes: `alt` descriptivo (no "imagen de...")
  - Iconos decorativos: `alt=""` o `role="presentation"`
  - Gráficos: descripción + tabla de datos alternativa
  - CAPTCHA: alternativa accesible

### 1.2 Medios Basados en Tiempo
- [ ] **1.2.1** Solo audio/video pregrabado: alternativa
- [ ] **1.2.2** Subtítulos en pregrabado
- [ ] **1.2.3** Audiodescripción o alternativa
- [ ] **1.2.4** Subtítulos en vivo
- [ ] **1.2.5** Audiodescripción en pregrabado

### 1.3 Adaptable
- [ ] **1.3.1** Info y relaciones: estructura semántica (h1-h6, lists, tables)
- [ ] **1.3.2** Secuencia significativa: orden DOM = orden visual
- [ ] **1.3.3** Características sensoriales: no solo forma/color/posición
- [ ] **1.3.4** Orientación: no restringir a portrait/landscape
- [ ] **1.3.5** Identificar propósito: autocomplete en formularios
- [ ] **1.3.6** Identificar propósito (UI components): landmarks, regions

### 1.4 Distinguible
- [ ] **1.4.1** Uso de color: no solo color para info
- [ ] **1.4.2** Control audio: stop/pause/volumen si > 3s
- [ ] **1.4.3** Contraste mínimo: **4.5:1** (texto), **3:1** (large text 18pt+/14pt+ bold)
- [ ] **1.4.4** Resize text: 200% sin pérdida funcionalidad
- [ ] **1.4.5** Imágenes de texto: evitar, usar texto real
- [ ] **1.4.10** Reflow: 320px ancho sin scroll horizontal
- [ ] **1.4.11** Contraste no texto: **3:1** (UI components, gráficos)
- [ ] **1.4.11** Hover/Focus visible: outline 2px + offset 2px
- [ ] **1.4.13** Contenido en hover/focus: dismissible, hoverable, persistent

---

## 2.1 Teclado Accesible
- [ ] **2.1.1** Todo funcional por teclado
- [ ] **2.1.2** Sin trampa de teclado (escape siempre sale)
- [ ] **2.1.4** Atajos: desactivables, remappables, solo en focus

## 2.2 Tiempo Suficiente
- [ ] **2.2.1** Ajustable: alertas de tiempo, extender
- [ ] **2.2.2** Pausar, detener, ocultar: movimiento > 5s

## 2.3 Convulsiones
- [ ] **2.3.1** Sin flashes > 3Hz

## 2.4 Navegable
- [ ] **2.4.1** Skip links: "Saltar al contenido principal"
- [ ] **2.4.2** Título de página descriptivo
- [ ] **2.4.3** Orden foco lógico (izq→der, arriba→abajo)
- [ ] **2.4.4** Propósito enlace claro (contexto)
- [ ] **2.4.5** Múltiples vías: nav, search, sitemap
- [ ] **2.4.6** Headings/labels descriptivos
- [ ] **2.4.7** Focus visible: **outline 2px + offset 2px** mínimo

---

## 3.1 Legible
- [ ] **3.1.1** Idioma página: `lang="es"`
- [ ] **3.1.2** Idioma partes: `lang="en"` en partes

## 3.2 Predecible
- [ ] **3.2.1** En foco: no cambios contexto
- [ ] **3.2.2** En entrada: no cambios contexto
- [ ] **3.2.3** Navegación consistente
- [ ] **3.2.4** Identificación consistente

## 3.3 Asistencia Entrada
- [ ] **3.3.1** Error identificado + descrito
- [ ] **3.3.2** Labels/instrucciones en inputs
- [ ] **3.3.3** Sugerencias corrección error
- [ ] **3.3.4** Prevención errores (legal/financiero/datos): revisar, confirmar, revertir

---

## 4.1 Compatible
- [ ] **4.1.1** Parsing: HTML válido, IDs únicos
- [ ] **4.1.2** Nombre, rol, valor: components expuestos a AT
- [ ] **4.1.3** Mensajes de estado: live regions

---

## 🎯 Quick Wins (Implementar Ya)

### Focus Visible (CSS)
```css
:focus-visible {
  outline: 2px solid #1976D2;
  outline-offset: 2px;
}

/* No quitar outline nunca */
*:focus { outline: none; }  /* ❌ NUNCA */
*:focus-visible { outline: 2px solid #1976D2; outline-offset: 2px; }  /* ✅ */
```

### Skip Link
```html
<a href="#main-content" class="skip-link">Saltar al contenido principal</a>
```
```css
.skip-link {
  position: absolute;
  top: -100%;
  left: 50%;
  transform: translateX(-50%);
  padding: 8px 16px;
  background: #1976D2;
  color: white;
  z-index: 1000;
  border-radius: 4px;
}
.skip-link:focus { top: 8px; }
```

### Skip to Main Content
```html
<header>...</header>
<main id="main-content">...</main>
```

### ARIA Labels (Icon Buttons)
```html
<!-- ❌ MAL -->
<button><Icon name="delete" /></button>

<!-- ✅ BIEN -->
<button aria-label="Eliminar producto">
  <Icon name="delete" aria-hidden="true" />
</button>
```

### Live Regions
```html
<!-- Para notificaciones dinámicas -->
<div aria-live="polite" aria-atomic="true" class="sr-only">
  {mensaje}
</div>

<!-- Para errores urgentes -->
<div aria-live="assertive" aria-atomic="true" class="sr-only">
  {error}
</div>
```

### Form Labels
```html
<!-- ✅ CORRECTO -->
<label for="email">Email</label>
<input type="email" id="email" name="email" aria-describedby="email-hint" />
<span id="email-hint">Tu email de trabajo</span>

<!-- ❌ MAL -->
<input type="email" placeholder="Email" />
```

### Error Messages
```html
<label for="email">Email *</label>
<input 
  type="email" 
  id="email" 
  aria-invalid="true" 
  aria-describedby="email-error"
/>
<span id="email-error" role="alert" class="error">
  Formato de email inválido
</span>
```

### Focus Management (Modales)
```javascript
// Al abrir modal
const previousFocus = document.activeElement;
modalElement.focus();
// Guardar previousFocus para restaurar al cerrar

// Al cerrar
previousFocus?.focus();
```

### Skip Link CSS
```css
.skip-link {
  position: absolute;
  top: -100%;
  left: 50%;
  transform: translateX(-50%);
  padding: 12px 24px;
  background: #1976D2;
  color: white;
  font-weight: 500;
  border-radius: 8px;
  z-index: 10000;
  transition: top 0.2s;
}
.skip-link:focus {
  top: 16px;
}
```

### Reduced Motion
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

### Focus Visible (No quitar outline)
```css
/* ❌ NUNCA HACER ESTO */
*:focus { outline: none; }

/* ✅ SIEMPRE HACER ESTO */
:focus-visible {
  outline: 2px solid #1976D2;
  outline-offset: 2px;
}

/* Para botones específicamente */
button:focus-visible,
a:focus-visible,
input:focus-visible,
select:focus-visible,
textarea:focus-visible {
  outline: 2px solid #1976D2;
  outline-offset: 2px;
}
```

### Contraste Mínimo (WCAG 2.1 AA)
| Texto | Ratio Mínimo |
|-------|--------------|
| Normal (< 18pt / < 14pt bold) | 4.5:1 |
| Grande (≥ 18pt o ≥ 14pt bold) | 3:1 |
| UI Components / Gráficos | 3:1 |

### Herramientas Verificación
```bash
# Verificar contraste
npx @axe-core/cli https://tu-app.com

# En CI
npm install -D @axe-core/playwright
# playwright test --project=chromium --reporter=line
```

### Testing Checklist Manual
- [ ] Navegar solo con Tab/Shift+Tab
- [ ] Escape cierra modales/dropdowns
- [ ] Enter envía formularios
- [ ] Escape cancela/closes
- [ ] Zoom 200% funciona
- [ ] Screen reader (NVDA/VoiceOver) lee todo
- [ ] Contraste verificado (DevTools > Elements > Accessibility)
- [ ] Focus visible en todos los interactivos
- [ ] Skip link funciona
- [ ] Live regions anuncian cambios