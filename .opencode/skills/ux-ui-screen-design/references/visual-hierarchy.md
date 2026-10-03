# 🎨 Jerarquía Visual, Tipografía, Color y Grid

> **La jerarquía visual guía al usuario. Sin ella, hay caos.**

---

## 🔤 Tipografía - Sistema Completo

### Escala Tipográfica (Base 16px, Ratio 1.25)
| Token | Tamaño | Line Height | Peso | Uso |
|-------|--------|-------------|------|-----|
| Display Large | 57px / 3.56rem | 1.12 | 400 | Hero, números heroicos |
| Display Medium | 45px / 2.81rem | 1.16 | 400 | Landing headers |
| Display Small | 36px / 2.25rem | 1.22 | 400 | Section heroes |
| **Headline Large** | **32px / 2rem** | **1.25** | **600** | **H1 - Título pantalla** |
| **Headline Medium** | **28px / 1.75rem** | **1.29** | **600** | **H2 - Secciones principales** |
| **Headline Small** | **24px / 1.5rem** | **1.33** | **600** | **H3 - Sub-secciones** |
| **Title Large** | **22px / 1.375rem** | **1.27** | **600** | **Cards, list items** |
| **Title Medium** | **16px / 1rem** | **1.5** | **600** | **Labels, chips** |
| **Title Small** | **14px / 0.875rem** | **1.43** | **600** | **Labels, captions** |
| **Body Large** | **16px / 1rem** | **1.5** | **400** | **Body text principal** |
| **Body Medium** | **14px / 0.875rem** | **1.43** | **400** | **Body secundario** |
| **Body Small** | **12px / 0.75rem** | **1.5** | **400** | **Caption, legal** |
| **Label Large** | **14px / 0.875rem** | **1.43** | **500** | **Labels, buttons** |
| **Label Small** | **11px / 0.6875rem** | **1.5** | **500** | **Overline, tags** |

### Pesos Disponibles
| Peso | Valor | Uso |
|------|-------|-----|
| Light | 300 | Display only |
| Regular | 400 | Body text |
| Medium | 500 | Labels, buttons, emphasis |
| SemiBold | 600 | Headings, emphasis |
| Bold | 700 | Rarely, only critical |

### Line Height Rules
- **Headings**: 1.2 - 1.3 (más ajustado)
- **Body**: 1.5 - 1.6 (legibilidad)
- **Captions**: 1.4 - 1.5
- **Buttons/Labels**: 1.0 - 1.2 (compacto)

---

## 🎨 Sistema de Color Semántico

### Paleta Base (Material 3 Inspired)
```css
:root {
  /* Primary - Acción principal */
  --primary: #1976D2;
  --primary-container: #D6E4F0;
  --on-primary: #FFFFFF;
  --on-primary-container: #0D47A1;

  /* Secondary - Acciones secundarias */
  --secondary: #5C6BC0;
  --secondary-container: #E8EAF6;
  --on-secondary: #FFFFFF;
  --on-secondary-container: #1A237E;

  /* Tertiary - Accentos */
  --tertiary: #009688;
  --tertiary-container: #E0F2F1;
  --on-tertiary: #FFFFFF;
  --on-tertiary-container: #004D40;

  /* Error - Destructivo */
  --error: #C62828;
  --error-container: #FBE9E7;
  --on-error: #FFFFFF;
  --on-error-container: #B71C1C;

  /* Warning - Advertencia */
  --warning: #F57F17;
  --warning-container: #FFF8E1;
  --on-warning: #FFFFFF;
  --on-warning-container: #E65100;

  /* Success - Éxito */
  --success: #2E7D32;
  --success-container: #E8F5E9;
  --on-success: #FFFFFF;
  --on-success-container: #1B5E20;

  /* Surface - Fondos */
  --surface: #FFFFFF;
  --surface-variant: #F5F5F5;
  --surface-container: #F5F5F5;
  --surface-container-high: #EEEEEE;
  --on-surface: #1C1B1F;
  --on-surface-variant: #49454F;

  /* Background */
  --background: #F5F5F5;
  --on-background: #1C1B1F;

  /* Outline / Borders */
  --outline: #79747E;
  --outline-variant: #CAC4D0;
}

/* Dark Mode */
@media (prefers-color-scheme: dark) {
  :root {
    --primary: #90CAF9;
    --primary-container: #1565C0;
    --on-primary: #000000;
    --on-primary-container: #BBDEFB;

    --secondary: #B39DDB;
    --secondary-container: #3F51B5;
    --on-secondary: #000000;
    --on-secondary-container: #E8EAF6;

    --tertiary: #80CBC4;
    --tertiary-container: #00695C;
    --on-tertiary: #000000;
    --on-tertiary-container: #E0F2F1;

    --error: #EF5350;
    --error-container: #B71C1C;
    --on-error: #FFFFFF;
    --on-error-container: #FFEBEE;

    --success: #81C784;
    --success-container: #1B5E20;
    --on-success: #000000;
    --on-success-container: #E8F5E9;

    --surface: #1E1E1E;
    --surface-variant: #2C2C2C;
    --surface-container: #2C2C2C;
    --surface-container-high: #383838;
    --on-surface: #E6E1E5;
    --on-surface-variant: #CAC4D0;

    --background: #121212;
    --on-background: #E6E1E5;

    --outline: #938F99;
    --outline-variant: #49454F;
  }
}
```

### Uso Semántico (NO decorativo)
| Contexto | Token | Ejemplo |
|----------|-------|---------|
| Botón primario | `primary` / `on-primary` | Botón "Guardar" |
| Botón secundario | `secondary` / `on-secondary` | "Cancelar" |
| Botón destructivo | `error` / `on-error` | "Eliminar" |
| Éxito/Confirmación | `success` / `on-success` | Toast éxito |
| Advertencia | `warning` / `on-warning` | Alerta stock bajo |
| Fondo tarjeta | `surface` / `on-surface` | Cards, modales |
| Fondo app | `background` / `on-background` | Scaffold |
| Texto principal | `on-surface` / `on-background` | Body text |
| Texto secundario | `on-surface-variant` | Captions, hints |
| Bordes | `outline` / `outline-variant` | Cards, inputs |
| Deshabilitado | `on-surface` @ 38% | Disabled state |

---

## 📏 Sistema de Espaciado (8px Base)

### Tokens de Espaciado
| Token | Valor | Rem | Uso |
|-------|-------|-----|-----|
| `space-0` | 0px | 0 | Reset |
| `space-1` | 4px | 0.25rem | Icon-text gap, tight |
| `space-2` | 8px | 0.5rem | **Base unit**, icon gaps |
| `space-3` | 12px | 0.75rem | Form gaps, small |
| `space-4` | 16px | 1rem | **Default**, card padding |
| `space-5` | 20px | 1.25rem | Comfortable |
| `space-6` | 24px | 1.5rem | Section gap |
| `space-8` | 32px | 2rem | Section margin |
| `space-10` | 40px | 2.5rem | Large gap |
| `space-12` | 48px | 3rem | Page margins |
| `space-16` | 64px | 4rem | Hero sections |

### Reglas de Aplicación
| Contexto | Espaciado |
|----------|-----------|
| Icon + text | `space-2` (8px) |
| Input vertical gap | `space-3` (12px) |
| Card padding | `space-4` (16px) |
| Component gap | `space-4` (16px) |
| Section gap | `space-6` (24px) |
| Section margin | `space-8` (32px) |
| Page margins | `space-12` (48px) |
| Modal padding | `space-6` (24px) |

### CSS Custom Properties
```css
:root {
  --space-1: 4px;
  --space-2: 8px;
  --space-3: 12px;
  --space-4: 16px;
  --space-5: 20px;
  --space-5: 20px;
  --space-6: 24px;
  --space-8: 32px;
  --space-10: 40px;
  --space-12: 48px;
  --space-16: 64px;
}
```

---

## 📐 Grid System (12 Columnas)

### Breakpoints
| Breakpoint | Ancho | Columns | Gutter | Margin |
|------------|-------|---------|--------|--------|
| xs | < 600px | 4 | 16px | 16px |
| sm | 600-959px | 8 | 24px | 24px |
| md | 960-1279px | 12 | 24px | 24px |
| lg | 1280-1919px | 12 | 24px | 32px |
| xl | ≥1920px | 12 | 24px | 48px |

### Container Widths
| Breakpoint | Max Width |
|------------|-----------|
| xs | 100% |
| sm | 576px |
| md | 720px |
| lg | 1024px |
| xl | 1280px |
| xxl | 1440px |

### Column Classes (Utility)
```css
.col-1 { width: 8.33%; }
.col-2 { width: 16.66%; }
.col-3 { width: 25%; }
.col-4 { width: 33.33%; }
.col-6 { width: 50%; }
.col-8 { width: 66.66%; }
.col-12 { width: 100%; }

/* Responsive */
@media (min-width: 600px) {
  .sm-col-6 { width: 50%; }
}
@media (min-width: 960px) {
  .md-col-4 { width: 33.33%; }
  .md-col-6 { width: 50%; }
}
```

---

## 📏 Responsive Breakpoints (Tokens)

```css
:root {
  --breakpoint-xs: 0;
  --breakpoint-sm: 600px;
  --breakpoint-md: 960px;
  --breakpoint-lg: 1280px;
  --breakpoint-xl: 1920px;
}

/* Media Queries */
@media (max-width: 599px) { /* xs */ }
@media (min-width: 600px) and (max-width: 959px) { /* sm */ }
@media (min-width: 960px) and (max-width: 1279px) { /* md */ }
@media (min-width: 1280px) and (max-width: 1919px) { /* lg */ }
@media (min-width: 1920px) { /* xl */ }

/* Container Queries (Modern) */
@container (min-width: 400px) { /* card context */ }
@container (min-width: 600px) { /* sidebar context */ }
```

---

## 🎯 Quick Reference: Decisión Rápida

| Pregunta | Respuesta |
|----------|-----------|
| ¿Qué tamaño de fuente? | Body 16px, H1 32px, escala 1.25 |
| ¿Qué espaciado? | Múltiplos de 8px (base) |
| ¿Qué color? | Semántico (primary/error/success) |
| ¿Cuántas columnas? | Mobile 1, tablet 2, desktop 3-4 |
| ¿Qué breakpoint? | xs<600, sm 600, md 960, lg 1280, xl 1920 |
| ¿Contraste? | 4.5:1 texto, 3:1 UI/grande |
| ¿Focus? | outline 2px + offset 2px |
| ¿Animación? | 150-300ms, ease-out, prefers-reduced-motion |

---

## 🎯 Quick Reference: Tokens CSS

```css
/* Ejemplo uso en componente */
.my-card {
  padding: var(--space-4);        /* 16px */
  margin-bottom: var(--space-6);  /* 24px */
  border-radius: 12px;
  background: var(--surface);
  border: 1px solid var(--outline-variant);
  box-shadow: 0 1px 3px rgba(0,0,0,0.08);
}

.my-card:hover {
  box-shadow: 0 4px 12px rgba(0,0,0,0.12);
}

.my-button {
  padding: var(--space-2) var(--space-4);
  font-size: 14px;
  font-weight: 500;
  border-radius: 8px;
}
```

---

## 🎯 Checklist Visual Completo

- [ ] Tipografía: escala 1.25, weights correctos
- [ ] Espaciado: múltiplos de 8px
- [ ] Color: semántico, no decorativo
- [ ] Contraste: ≥4.5:1 texto, ≥3:1 UI
- [ ] Focus visible: outline 2px + offset 2px
- [ ] Grid: 12 col, gutters 24px
- [ ] Breakpoints: xs/sm/md/lg/xl
- [ ] Dark mode: tokens completos
- [ ] Reduced motion: respeta preferencia
- [ ] Focus visible: outline 2px + offset 2px