# 📏 Sistema de Espaciado (8px Base)

> **El espaciado es el silencio entre las notas. Sin él, no hay música.**

---

## 📏 Tokens de Espaciado (Base 8px)

| Token | Px | Rem | Uso Principal |
|-------|-----|-----|---------------|
| `space-0` | 0 | 0 | Reset, overlap |
| `space-1` | 4px | 0.25rem | Icon-text gap, tight |
| `space-2` | 8px | 0.5rem | **Base unit**, icon gaps, tight |
| `space-3` | 12px | 0.75rem | Form gaps, small gaps |
| `space-4` | 16px | 1rem | **Default**, card padding, input gap |
| `space-5` | 20px | 1.25rem | Comfortable gap |
| `space-6` | 24px | 1.5rem | Section gap, card gap |
| `space-8` | 32px | 2rem | Section margin, large gap |
| `space-10` | 40px | 2.5rem | Large section gap |
| `space-12` | 48px | 3rem | Page margins, hero |
| `space-16` | 64px | 4rem | Hero sections, major sections |

---

## 📐 Reglas de Aplicación por Contexto

| Contexto | Espaciado | Token |
|----------|-----------|-------|
| Icon + text gap | 8px | `space-2` |
| Input label → input | 8px | `space-2` |
| Input vertical gap | 12px | `space-3` |
| Field group gap | 16px | `space-4` |
| Card padding | 16px | `space-4` |
| Component gap | 16px | `space-4` |
| Section gap | 24px | `space-6` |
| Section margin | 32px | `space-8` |
| Page margins | 48px | `space-12` |
| Modal padding | 24px | `space-6` |
| Button padding | 10px 24px | `space-2.5` / `space-6` |
| Button gap | 8px | `space-2` |
| List item gap | 8px | `space-2` |
| Chip gap | 8px | `space-2` |
| Chip internal padding | 8px 12px | `space-2` / `space-3` |
| Avatar + text | 12px | `space-3` |
| Avatar + text (compact) | 8px | `space-2` |
| Section title → content | 16px | `space-4` |
| Section title → next section | 32px | `space-8` |
| Page top padding | 24px | `space-6` |
| Page bottom padding | 32px | `space-8` |

---

## 📐 Reglas de Composición

### 1. **Proximidad (Gestalt)**
- Elementos relacionados → cerca (`space-2` a `space-4`)
- Elementos no relacionados → lejos (`space-6` a `space-8`)

### 2. **Ritmo Vertical**
```
Sección A
[space-6]
Título Sección
[space-4]
Contenido
[space-8]
Siguiente Sección
```

### 3. **Alineación Óptica**
- Texto alinea con texto (baseline)
- Iconos alinean con texto (center)
- Números alinean a la derecha

---

## 📏 CSS Custom Properties

```css
:root {
  /* Base 8px scale */
  --space-0: 0;
  --space-1: 4px;    /* 0.25rem */
  --space-2: 8px;    /* 0.5rem - BASE */
  --space-3: 12px;   /* 0.75rem */
  --space-4: 16px;   /* 1rem - DEFAULT */
  --space-5: 20px;   /* 1.25rem */
  --space-6: 24px;   /* 1.5rem */
  --space-8: 32px;   /* 2rem */
  --space-10: 40px;  /* 2.5rem */
  --space-12: 48px;  /* 3rem */
  --space-16: 64px;  /* 4rem */
  --space-20: 80px;  /* 5rem */
  --space-24: 96px;  /* 6rem */
  
  /* Semantic aliases */
  --space-xs: var(--space-1);
  --space-sm: var(--space-2);
  --space-md: var(--space-4);
  --space-lg: var(--space-6);
  --space-xl: var(--space-8);
  --space-xxl: var(--space-12);
  
  /* Semantic */
  --gap-icon-text: var(--space-2);
  --gap-input: var(--space-2);
  --gap-field: var(--space-3);
  --gap-component: var(--space-4);
  --gap-section: var(--space-6);
  --gap-page: var(--space-12);
  --padding-card: var(--space-4);
  --padding-modal: var(--space-6);
  --padding-page: var(--space-12);
  --gap-button: var(--space-2);
  --padding-button: var(--space-2) var(--space-6);
}
```

---

## 📐 CSS Utility Classes

```css
/* Gap utilities */
.gap-0 { gap: var(--space-0); }
.gap-1 { gap: var(--space-1); }
.gap-2 { gap: var(--space-2); }
.gap-3 { gap: var(--space-3); }
.gap-4 { gap: var(--space-4); }
.gap-5 { gap: var(--space-5); }
.gap-6 { gap: var(--space-6); }
.gap-8 { gap: var(--space-8); }
.gap-10 { gap: var(--space-10); }
.gap-12 { gap: var(--space-12); }
.gap-16 { gap: var(--space-16); }

/* Padding */
.p-0 { padding: var(--space-0); }
.p-1 { padding: var(--space-1); }
.p-2 { padding: var(--space-2); }
.p-3 { padding: var(--space-3); }
.p-4 { padding: var(--space-4); }
.p-5 { padding: var(--space-5); }
.p-6 { padding: var(--space-6); }
.p-8 { padding: var(--space-8); }
.p-12 { padding: var(--space-12); }
.p-16 { padding: var(--space-16); }

.px-2 { padding-left: var(--space-2); padding-right: var(--space-2); }
.px-4 { padding-left: var(--space-4); padding-right: var(--space-4); }
.px-6 { padding-left: var(--space-6); padding-right: var(--space-6); }
.py-2 { padding-top: var(--space-2); padding-bottom: var(--space-2); }
.py-4 { padding-top: var(--space-4); padding-bottom: var(--space-4); }
.py-6 { padding-top: var(--space-6); padding-bottom: var(--space-6); }

/* Margin */
.m-0 { margin: var(--space-0); }
.m-1 { margin: var(--space-1); }
.m-2 { margin: var(--space-2); }
.m-3 { margin: var(--space-3); }
.m-4 { margin: var(--space-4); }
.m-6 { margin: var(--space-6); }
.m-8 { margin: var(--space-8); }
.m-12 { margin: var(--space-12); }
.m-16 { margin: var(--space-16); }

.mt-4 { margin-top: var(--space-4); }
.mb-4 { margin-bottom: var(--space-4); }
.mt-6 { margin-top: var(--space-6); }
.mb-6 { margin-bottom: var(--space-6); }
.mt-8 { margin-top: var(--space-8); }
.mb-8 { margin-bottom: var(--space-8); }
.mt-12 { margin-top: var(--space-12); }
.mb-12 { margin-bottom: var(--space-12); }

.mx-auto { margin-left: auto; margin-right: auto; }

/* Responsive spacing */
@media (max-width: 599px) {
  .space-page { padding: var(--space-4); }
  .section-gap { gap: var(--space-4); }
}

@media (min-width: 600px) {
  .space-page { padding: var(--space-6); }
  .section-gap { gap: var(--space-6); }
}

@media (min-width: 1280px) {
  .space-page { padding: var(--space-8); }
  .section-gap { gap: var(--space-8); }
}
```

---

## 📐 Quick Reference

| Pregunta | Respuesta |
|----------|-----------|
| Base unit? | 8px |
| Default padding? | 16px (space-4) |
| Default gap? | 16px (space-4) |
| Section gap? | 24px (space-6) |
| Section margin? | 32px (space-8) |
| Page margin? | 48px (space-12) |
| Card padding? | 16px (space-4) |
| Input gap? | 12px (space-3) |
| Button gap? | 8px (space-2) |
| Icon + text? | 8px (space-2) |
| Modal padding? | 24px (space-6) |
| Page margin mobile? | 16px (space-4) |
| Page margin desktop? | 48px (space-12) |

---

## 🎯 Checklist Espaciado

- [ ] Todo espaciado múltiplo de 8px
- [ ] Padding tarjetas: 16px
- [ ] Gap entre componentes: 16px
- [ ] Gap secciones: 24px
- [ ] Margin secciones: 32px
- [ ] Page margins: 48px (desktop) / 16px (mobile)
- [ ] Input gap: 12px
- [ ] Button gap: 8px
- [ ] Modal padding: 24px
- [ ] Page margin mobile: 16px
- [ ] Page margin desktop: 48px
- [ ] No magic numbers (solo tokens)
- [ ] Responsive: mobile < tablet < desktop