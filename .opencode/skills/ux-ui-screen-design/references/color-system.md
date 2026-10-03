# 🎨 Sistema de Color Semántico

> **El color comunica significado, no decoración.**

---

## 🎨 Paleta Semántica Base (Light Mode)

```css
:root {
  /* === PRIMARY - Acción Principal === */
  --primary: #1976D2;
  --primary-hover: #1565C0;
  --primary-pressed: #0D47A1;
  --primary-container: #D6E4F0;
  --on-primary: #FFFFFF;
  --on-primary-container: #0D47A1;

  /* === SECONDARY - Acciones Secundarias === */
  --secondary: #5C6BC0;
  --secondary-hover: #3F51B5;
  --secondary-pressed: #303F9F;
  --secondary-container: #E8EAF6;
  --on-secondary: #FFFFFF;
  --on-secondary-container: #1A237E;

  /* === TERTIARY - Accentos / Tertiary Actions === */
  --tertiary: #009688;
  --tertiary-hover: #00897B;
  --tertiary-pressed: #00796B;
  --tertiary-container: #E0F2F1;
  --on-tertiary: #FFFFFF;
  --on-tertiary-container: #004D40;

  /* === ERROR - Destructivo / Error === */
  --error: #C62828;
  --error-hover: #B71C1C;
  --error-pressed: #B71C1C;
  --error-container: #FBE9E7;
  --on-error: #FFFFFF;
  --on-error-container: #B71C1C;

  /* === WARNING - Advertencia / Cuidado === */
  --warning: #F57F17;
  --warning-hover: #F9A825;
  --warning-pressed: #F9A825;
  --warning-container: #FFF8E1;
  --on-warning: #FFFFFF;
  --on-warning-container: #E65100;

  /* === SUCCESS - Éxito / Confirmación === */
  --success: #2E7D32;
  --success-hover: #1B5E20;
  --success-pressed: #1B5E20;
  --success-container: #E8F5E9;
  --on-success: #FFFFFF;
  --on-success-container: #1B5E20;

  /* === INFO - Informativo === */
  --info: #0288D1;
  --info-hover: #0277BD;
  --info-pressed: #01579B;
  --info-container: #E1F5FE;
  --on-info: #FFFFFF;
  --on-info-container: #01579B;

  /* === NEUTRAL - Fondos y Superficies === */
  --surface: #FFFFFF;
  --surface-variant: #F5F5F5;
  --surface-container: #F5F5F5;
  --surface-container-high: #EEEEEE;
  --surface-container-highest: #E0E0E0;
  --on-surface: #1C1B1F;
  --on-surface-variant: #49454F;

  /* Background */
  --background: #F5F5F5;
  --on-background: #1C1B1F;

  /* Outline / Borders */
  --outline: #79747E;
  --outline-variant: #CAC4D0;

  /* Scrim / Overlay */
  --scrim: rgba(0, 0, 0, 0.5);
  --backdrop: rgba(0, 0, 0, 0.32);
}
```

---

## 🌙 Dark Mode (prefers-color-scheme: dark)

```css
@media (prefers-color-scheme: dark) {
  :root {
    /* Primary */
    --primary: #90CAF9;
    --primary-hover: #BBDEFB;
    --primary-pressed: #64B5F6;
    --primary-container: #1565C0;
    --on-primary: #000000;
    --on-primary-container: #BBDEFB;

    /* Secondary */
    --secondary: #B39DDB;
    --secondary-hover: #D1C4E9;
    --secondary-pressed: #9575CD;
    --secondary-container: #3F51B5;
    --on-secondary: #000000;
    --on-secondary-container: #E8EAF6;

    /* Tertiary */
    --tertiary: #80CBC4;
    --tertiary-hover: #B2DFDB;
    --tertiary-pressed: #4DB6AC;
    --tertiary-container: #00695C;
    --on-tertiary: #000000;
    --on-tertiary-container: #E0F2F1;

    /* Error */
    --error: #EF5350;
    --error-hover: #EF9A9A;
    --error-pressed: #EF9A9A;
    --error-container: #B71C1C;
    --on-error: #FFFFFF;
    --on-error-container: #FFCDD2;

    /* Warning */
    --warning: #FFB74D;
    --warning-hover: #FFD54F;
    --warning-pressed: #FFD54F;
    --warning-container: #E65100;
    --on-warning: #000000;
    --on-warning-container: #FFF8E1;

    /* Success */
    --success: #81C784;
    --success-hover: #A5D6A7;
    --success-pressed: #66BB6A;
    --success-container: #1B5E20;
    --on-success: #000000;
    --on-success-container: #C8E6C9;

    /* Surfaces */
    --surface: #1E1E1E;
    --surface-variant: #2C2C2C;
    --surface-container: #2C2C2C;
    --surface-container-high: #383838;
    --surface-container-highest: #444444;
    --on-surface: #E6E1E5;
    --on-surface-variant: #CAC4D0;

    /* Background */
    --background: #121212;
    --on-background: #E6E1E5;

    /* Outline */
    --outline: #938F99;
    --outline-variant: #49454F;

    /* Scrim */
    --scrim: rgba(0, 0, 0, 0.6);
    --backdrop: rgba(0, 0, 0, 0.5);
  }
}
```

---

## 🎯 Uso Semántico (NO Decorativo)

### Mapeo Contexto → Token

| Contexto | Token Fondo | Token Texto | Ejemplo |
|----------|-------------|-------------|---------|
| Botón primario | `primary` | `on-primary` | "Guardar", "Crear", "Enviar" |
| Botón secundario | `secondary` | `on-secondary` | "Cancelar", "Siguiente" |
| Botón terciario | `tertiary` | `on-tertiary` | "Saltar", "Más tarde" |
| Botón destructivo | `error` | `on-error` | "Eliminar", "Cancelar suscripción" |
| Botón outline primario | `primary-container` | `on-primary-container` | "Ver más" |
| Botón outline secundario | `secondary-container` | `on-secondary-container` | "Ver detalles" |
| Botón destructivo outline | `error-container` | `on-error-container` | "Eliminar" (menos agresivo) |
| Éxito/Confirmación | `success` / `on-success` | Toast éxito, badges |
| Advertencia | `warning` / `on-warning` | Alertas, stock bajo |
| Info | `info` / `on-info` | Tooltips, ayuda |
| Fondo tarjeta | `surface` / `on-surface` | Cards, modales, sheets |
| Fondo app | `background` / `on-background` | Scaffold, páginas |
| Texto principal | `on-surface` / `on-background` | Body text, headings |
| Texto secundario | `on-surface-variant` | Captions, hints, placeholders |
| Texto deshabilitado | `on-surface` @ 38% | Disabled inputs, labels |
| Bordes | `outline` / `outline-variant` | Cards, inputs, divisores |
| Divisores | `outline-variant` @ 10% | Divisores, líneas |
| Deshabilitado | `on-surface` @ 38% | Inputs, botones disabled |
| Overlay/Modal backdrop | `scrim` / `backdrop` | Modal backdrop, drawer |

---

## 🎯 Casos de Uso por Componente

### Botones
```tsx
// Primary - Acción principal
<Button variant="contained" color="primary">Guardar</Button>

// Secondary - Secundaria
<Button variant="outlined" color="primary">Cancelar</Button>

// Tertiary - Menos énfasis
<Button variant="text" color="primary">Saltar</Button>

// Destructivo
<Button variant="contained" color="error">Eliminar</Button>

// Outline destructivo (menos agresivo)
<Button variant="outlined" color="error">Eliminar</Button>

// Success action
<Button variant="contained" color="success">Confirmar</Button>

// Warning action
<Button variant="outlined" color="warning">Revisar</Button>
```

### Cards
```tsx
<Card sx={{ 
  background: 'surface', 
  border: '1px solid', 
  borderColor: 'outline.variant' 
}}>
  <CardContent sx={{ color: 'onSurface' }}>
    Contenido
  </CardContent>
</Card>
```

### Inputs
```tsx
<TextField
  label="Email"
  sx={{
    '& .MuiOutlinedInput-root': {
      '&:hover .MuiOutlinedInput-notchedOutline': {
        borderColor: 'outline',
      },
      '&.Mui-focused .MuiOutlinedInput-notchedOutline': {
        borderColor: 'primary',
        borderWidth: 2,
      },
      '&.Mui-error .MuiOutlinedInput-notchedOutline': {
        borderColor: 'error',
      },
    },
  }}
/>
```

### Chips
```tsx
// Status chips
<Chip 
  label="Activo" 
  color="success" 
  variant="outlined"
  sx={{ borderColor: 'success', color: 'success.main' }}
/>

// Count badge
<Badge 
  badgeContent={count} 
  color="primary" 
  sx={{ 
    '& .MuiBadge-badge': { 
      backgroundColor: 'primary.main', 
      color: 'primary.contrastText' 
    }
  }}
/>
```

### Alerts / Alerts
```tsx
<Alert severity="success" sx={{ backgroundColor: 'success.light', color: 'success.dark' }}>
  Éxito: Operación completada
</Alert>

<Alert severity="error" sx={{ backgroundColor: 'error.light', color: 'error.dark' }}>
  Error: Algo salió mal
</Alert>

<Alert severity="warning" sx={{ backgroundColor: 'warning.light', color: 'warning.dark' }}>
  Advertencia: Stock bajo
</Alert>

<Alert severity="info" sx={{ backgroundColor: 'info.light', color: 'info.dark' }}>
  Información: Nueva versión disponible
</Alert>
```

### Badges de Estado
```tsx
const getStatusColor = (status) => {
  switch (status) {
    case 'active': return 'success';
    case 'pending': return 'warning';
    case 'inactive': return 'default';
    case 'error': return 'error';
    default: return 'default';
  };
}

<Chip 
  label={status} 
  color={getStatusColor(status)} 
  variant="outlined"
  size="small"
/>
```

### Avatars
```tsx
<Avatar 
  src={user.photo} 
  sx={{ 
    bgcolor: 'primary.container', 
    color: 'onPrimaryContainer' 
  }}
>
  {user.name[0]}
</Avatar>
```

### Tablas
```tsx
<TableContainer>
  <Table>
    <TableHead>
      <TableRow sx={{ '& > *': { backgroundColor: 'surface.variant', fontWeight: 600 } }}>
        {columns.map(col => <TableCell key={col.id}>{col.label}</TableCell>)}
      </TableRow>
    </TableHead>
    <TableBody>
      {rows.map(row => (
        <TableRow key={row.id} hover>
          {columns.map(col => (
            <TableCell key={col.id}>{col.render(row)}</TableCell>
          ))}
        </TableRow>
      ))}
    </TableBody>
  </Table>
</TableContainer>
```

---

## 🎯 Tokens CSS Listos para Usar

```css
:root {
  /* Primary */
  --color-primary: #1976D2;
  --color-primary-hover: #1565C0;
  --color-primary-container: #D6E4F0;
  --color-on-primary: #FFFFFF;
  --color-on-primary-container: #0D47A1;

  /* Secondary */
  --color-secondary: #5C6BC0;
  --color-secondary-container: #E8EAF6;
  --color-on-secondary: #FFFFFF;
  --color-on-secondary-container: #1A237E;

  /* Error */
  --color-error: #C62828;
  --color-error-container: #FBE9E7;
  --color-on-error: #FFFFFF;
  --color-on-error-container: #B71C1C;

  /* Warning */
  --color-warning: #F57F17;
  --color-warning-container: #FFF8E1;
  --color-on-warning: #FFFFFF;
  --color-on-warning-container: #E65100;

  /* Success */
  --color-success: #2E7D32;
  --color-success-container: #E8F5E9;
  --color-on-success: #FFFFFF;
  --color-on-success-container: #1B5E20;

  /* Info */
  --color-info: #0288D1;
  --color-info-container: #E1F5FE;
  --color-on-info: #FFFFFF;
  --color-on-info-container: #01579B;

  /* Surfaces */
  --color-surface: #FFFFFF;
  --color-surface-variant: #F5F5F5;
  --color-surface-container: #F5F5F5;
  --color-surface-container-high: #EEEEEE;
  --color-on-surface: #1C1B1F;
  --color-on-surface-variant: #49454F;

  /* Background */
  --color-background: #F5F5F5;
  --color-on-background: #1C1B1F;

  /* Outline */
  --color-outline: #79747E;
  --color-outline-variant: #CAC4D0;

  /* Scrim */
  --color-scrim: rgba(0, 0, 0, 0.5);
  --color-backdrop: rgba(0, 0, 0, 0.32);
}

/* Dark mode automático */
@media (prefers-color-scheme: dark) {
  :root {
    --color-primary: #90CAF9;
    --color-primary-container: #1565C0;
    --color-on-primary: #000000;
    --color-on-primary-container: #BBDEFB;
    
    --color-surface: #1E1E1E;
    --color-surface-variant: #2C2C2C;
    --color-surface-container: #2C2C2C;
    --color-on-surface: #E6E1E5;
    --color-on-surface-variant: #CAC4D0;
    --color-background: #121212;
    --color-on-background: #E6E1E5;
    --color-outline: #938F99;
    --color-outline-variant: #49454F;
    --color-scrim: rgba(0, 0, 0, 0.6);
    --color-backdrop: rgba(0, 0, 0, 0.5);
  }
}
```

---

## 🎯 Uso en Componentes

```tsx
// Button
<Button 
  variant="contained" 
  sx={{ 
    backgroundColor: 'var(--color-primary)', 
    color: 'var(--color-on-primary)',
    '&:hover': { backgroundColor: 'var(--color-primary-hover)' },
    '&:active': { backgroundColor: 'var(--color-primary-pressed)' },
  }}
>
  Guardar
</Button>

// Card
<Card sx={{ 
  backgroundColor: 'var(--color-surface)', 
  border: '1px solid var(--color-outline-variant)',
  borderRadius: 12,
  boxShadow: '0 1px 3px rgba(0,0,0,0.08)',
  '&:hover': { boxShadow: '0 4px 12px rgba(0,0,0,0.12)' }
}}>
  <CardContent sx={{ color: 'var(--color-on-surface)' }}>
    Content
  </CardContent>
</Card>

// Input
<TextField
  sx={{
    '& .MuiOutlinedInput-root': {
      '& .MuiOutlinedInput-notchedOutline': {
        borderColor: 'var(--color-outline-variant)',
      },
      '&:hover .MuiOutlinedInput-notchedOutline': {
        borderColor: 'var(--color-outline)',
      },
      '&.Mui-focused .MuiOutlinedInput-notchedOutline': {
        borderColor: 'var(--color-primary)',
        borderWidth: 2,
      },
      '&.Mui-error .MuiOutlinedInput-notchedOutline': {
        borderColor: 'var(--color-error)',
      },
    },
  }}
/>

// Chip
<Chip 
  label="Activo" 
  sx={{ 
    backgroundColor: 'var(--color-success-container)', 
    color: 'var(--color-on-success-container)',
    border: '1px solid var(--color-success)',
    fontWeight: 500,
  }}
/>
```

---

## 🎯 Quick Reference

| Componente | Background | Text | Border |
|------------|------------|------|--------|
| Primary Button | `primary` | `on-primary` | - |
| Secondary Button | `secondary-container` | `on-secondary-container` | `secondary` |
| Error Button | `error` | `on-error` | - |
| Outline Error | `error-container` | `on-error-container` | `error` |
| Card | `surface` | `on-surface` | `outline-variant` |
| Input | `surface` | `on-surface` | `outline-variant` / `primary` (focus) / `error` (error) |
| Chip Success | `success-container` | `on-success-container` | `success` |
| Chip Error | `error-container` | `on-error-container` | `error` |
| Chip Warning | `warning-container` | `on-warning-container` | `warning` |
| Chip Info | `info-container` | `on-info-container` | `info` |
| Chip Neutral | `surface-variant` | `on-surface-variant` | `outline-variant` |
| Avatar | `primary-container` | `on-primary-container` | - |
| Divider | - | - | `outline-variant` |
| Disabled Text | - | `on-surface` @ 38% | - |
| Link | - | `primary` | - |
| Link Hover | - | `primary-hover` | - |