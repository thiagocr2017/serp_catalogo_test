# 📱 Responsive Breakpoints y Tokens

> **Mobile First. Siempre.**

---

## 📏 Breakpoints Oficiales

| Token | Ancho | Dispositivo | Columnas Grid | Gutter | Margin |
|---------|-------|-------------|---------------|--------|--------|
| `xs` | 0 - 599px | Mobile | 4 | 16px | 16px |
| `sm` | 600 - 959px | Tablet portrait | 8 | 24px | 24px |
| `md` | 960 - 1279px | Tablet landscape / Small desktop | 12 | 24px | 24px |
| `lg` | 1280 - 1919px | Desktop | 12 | 24px | 32px |
| `xl` | ≥ 1920px | Large desktop | 12 | 24px | 48px |

### Media Queries CSS
```css
/* Mobile First - Min Width */
@media (min-width: 600px) { /* sm */ }
@media (min-width: 960px) { /* md */ }
@media (min-width: 1280px) { /* lg */ }
@media (min-width: 1920px) { /* xl */ }

/* Max Width (para overrides) */
@media (max-width: 599px) { /* xs only */ }
@media (min-width: 600px) and (max-width: 959px) { /* sm only */ }
@media (min-width: 960px) and (max-width: 1279px) { /* md only */ }
@media (min-width: 1280px) and (max-width: 1919px) { /* lg only */ }
@media (min-width: 1920px) { /* xl only */ }
```

### Container Queries (Modern)
```css
/* Container queries para componentes */
.card-container {
  container-type: inline-size;
}

@container (min-width: 400px) {
  .card { display: grid; grid-template-columns: 1fr 1fr; }
}

@container (min-width: 600px) {
  .card { grid-template-columns: 1fr 1fr 1fr; }
}
```

---

## 📐 Container Widths

| Breakpoint | Max Container Width |
|------------|---------------------|
| xs | 100% |
| sm | 576px |
| md | 720px |
| lg | 1024px |
| xl | 1280px |
| xxl | 1440px |

```css
.container {
  width: 100%;
  max-width: 1440px;
  margin: 0 auto;
  padding: 0 var(--space-4);
}

@media (min-width: 600px) {
  .container { max-width: 576px; }
}
@media (min-width: 960px) {
  .container { max-width: 720px; }
}
@media (min-width: 1280px) {
  .container { max-width: 1024px; }
}
@media (min-width: 1920px) {
  .container { max-width: 1280px; }
}
```

---

## 📐 Grid System (12 Columnas)

### Column Classes
```css
/* Base 12-column grid */
.col-1  { width: 8.33%; }
.col-2  { width: 16.66%; }
.col-3  { width: 25%; }
.col-4  { width: 33.33%; }
.col-5  { width: 41.66%; }
.col-6  { width: 50%; }
.col-7  { width: 58.33%; }
.col-8  { width: 66.66%; }
.col-9  { width: 75%; }
.col-10 { width: 83.33%; }
.col-11 { width: 91.66%; }
.col-12 { width: 100%; }

/* Offset */
.offset-1 { margin-left: 8.33%; }
.offset-2 { margin-left: 16.66%; }
.offset-3 { margin-left: 25%; }

/* Responsive */
@media (min-width: 600px) {
  .sm-col-6 { width: 50%; }
  .sm-col-4 { width: 33.33%; }
  .sm-col-3 { width: 25%; }
}

@media (min-width: 960px) {
  .md-col-4 { width: 33.33%; }
  .md-col-6 { width: 50%; }
  .md-col-3 { width: 25%; }
}

@media (min-width: 1280px) {
  .lg-col-3 { width: 25%; }
  .lg-col-4 { width: 33.33%; }
}
```

### Grid Container
```css
.grid {
  display: grid;
  grid-template-columns: repeat(12, 1fr);
  gap: var(--space-6); /* 24px */
}

@media (max-width: 599px) {
  .grid { grid-template-columns: repeat(4, 1fr); gap: var(--space-4); }
}

@media (min-width: 600px) and (max-width: 959px) {
  .grid { grid-template-columns: repeat(8, 1fr); gap: var(--space-6); }
}

@media (min-width: 960px) {
  .grid { grid-template-columns: repeat(12, 1fr); gap: var(--space-6); }
}
```

### Utility Classes
```css
/* Span */
.col-span-1  { grid-column: span 1; }
.col-span-2  { grid-column: span 2; }
.col-span-3  { grid-column: span 3; }
.col-span-4  { grid-column: span 4; }
.col-span-6  { grid-column: span 6; }
.col-span-12 { grid-column: span 12; }

/* Responsive span */
@media (min-width: 600px) {
  .sm-col-span-6 { grid-column: span 6; }
}

@media (min-width: 960px) {
  .md-col-span-4 { grid-column: span 4; }
  .md-col-span-6 { grid-column: span 6; }
}
```

---

## 📱 Responsive Patterns por Componente

### Formularios
| Breakpoint | Layout | Max Width |
|------------|--------|-----------|
| xs (<600) | 1 col, full width | 100% |
| sm (600+) | 1-2 col | 50% |
| md (960+) | 2-3 col | 66% |
| lg (1280+) | 3-4 col | 75% |
| xl (1920+) | 4 col | 80% |

```tsx
<Grid container spacing={3} columns={{ xs: 1, sm: 2, md: 3, lg: 4 }}>
  {fields.map(field => (
    <Grid item xs={12} sm={6} md={4} lg={3} key={field.name}>
      <TextField {...field} />
    </Grid>
  )}
</Grid>
```

### Tablas
| Breakpoint | Comportamiento |
|------------|----------------|
| xs | Cards (stack) |
| sm | Horizontal scroll |
| md+ | Tabla completa |

```tsx
<TableContainer sx={{ overflowX: 'auto' }}>
  <Table>
    {/* Headers */}
    <TableBody>
      {items.map(item => (
        <TableRow key={item.id}>
          {columns.map(col => (
            <TableCell key={col.id}>
              {col.render ? col.render(item) : item[col.field]}
            </TableCell>
          ))}
        </TableRow>
      ))}
    </TableBody>
  </Table>
</TableContainer>
```

### Cards Grid
| Breakpoint | Columnas |
|------------|----------|
| xs | 1 |
| sm | 2 |
| md | 3 |
| lg | 4 |
| xl | 4-5 |

```tsx
<Grid container spacing={3} columns={{ xs: 1, sm: 2, md: 3, lg: 4 }}>
  {items.map(item => (
    <Grid item xs={12} sm={6} md={4} lg={3} key={item.id}>
      <Card>{/* content */}</Card>
    </Grid>
  ))}
</Grid>
```

### Navigation
| Breakpoint | Tipo |
|------------|------|
| xs | Bottom Navigation |
| sm | Bottom Navigation |
| md | Sidebar (collapsible) |
| lg | Sidebar persistente |
| xl | Sidebar persistente + secondary |

### Modals
| Breakpoint | Ancho | Alto |
|------------|-------|------|
| xs | 100% (fullscreen) | 100% |
| sm | 90% | 90% |
| md | 50% | 80% |
| lg | 40% | 80% |
| xl | 33% | 70% |

---

## 🎯 Container Queries (Modern)

### Container Queries
```css
.card-container {
  container-type: inline-size;
}

@container (min-width: 300px) {
  .card { 
    display: grid; 
    grid-template-columns: 1fr 1fr; 
  }
}

@container (min-width: 500px) {
  .card { 
    grid-template-columns: 1fr 1fr 1fr; 
  }
}
```

---

## 🎯 Tokens CSS Completos

```css
:root {
  /* Breakpoints */
  --bp-xs: 0;
  --bp-sm: 600px;
  --bp-md: 960px;
  --bp-lg: 1280px;
  --bp-xl: 1920px;

  /* Container max widths */
  --container-sm: 576px;
  --container-md: 720px;
  --container-lg: 1024px;
  --container-xl: 1280px;
  --container-xxl: 1440px;

  /* Grid */
  --grid-columns: 12;
  --grid-gutter: 24px;
  --grid-margin-xs: 16px;
  --grid-margin-sm: 24px;
  --grid-margin-md: 24px;
  --grid-margin-lg: 32px;
  --grid-margin-xl: 48px;
}

/* Media Queries */
@media (min-width: 600px) { /* sm */ }
@media (min-width: 960px) { /* md */ }
@media (min-width: 1280px) { /* lg */ }
@media (min-width: 1920px) { /* xl */ }

/* Container Queries */
.card-container {
  container-type: inline-size;
}

@container (min-width: 300px) { .card { grid-template-columns: 1fr 1fr; } }
@container (min-width: 500px) { .card { grid-template-columns: 1fr 1fr 1fr; } }
```

---

## 🎯 Quick Reference

| Pregunta | Respuesta |
|----------|-----------|
| Mobile breakpoint? | 600px |
| Tablet breakpoint? | 960px |
| Desktop breakpoint? | 1280px |
| Large desktop? | 1920px |
| Grid columns? | 12 |
| Base gutter? | 24px |
| Mobile columns? | 4 |
| Tablet columns? | 8 |
| Desktop columns? | 12 |
| Container max xl? | 1280px |
| Container max xxl? | 1440px |
| Gutter base? | 24px |
| Margin mobile? | 16px |
| Margin desktop? | 24-32px |