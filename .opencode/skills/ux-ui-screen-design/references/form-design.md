# 📝 Diseño de Formularios - Guía Completa

> **Un buen formulario es invisible. Solo se nota cuando falla.**

---

## 📐 Layout y Estructura

### Layouts por Complejidad
| Campos | Layout | Columnas |
|--------|--------|----------|
| 1-3 | Stack vertical | 1 |
| 4-6 | Grid 2 cols | 2 |
| 7-12 | Secciones + accordion | 1-2 |
| >12 | Multi-step wizard | 1 |

### Agrupación Lógica (Gestalt)
```
┌─────────────────────────────────────┐
│  📋  Datos Personales               │  ← Section header
├─────────────────────────────────────┤
│ Nombre *    │ Apellido *            │  ← Related = grouped
│ Email *     │ Teléfono              │
├─────────────────────────────────────┤
│ 🏠  Dirección                       │  ← Visual separator
├─────────────────────────────────────┤
│ Dirección *   │ Número *            │
│ Ciudad *      │ Código Postal *     │
└─────────────────────────────────────┘
```

---

## 🏷️ Labels y Helpers

### Label (Obligatorio Siempre)
```tsx
<label htmlFor="email">Email *</label>
<input id="email" type="email" required />
```

**Reglas:**
- ✅ Siempre visible (no placeholder-only)
- ✅ Asterisco * para requeridos
- ✅ `htmlFor` = `input.id`
- ✅ Tamaño: 14px, Medium weight
- ✅ Color: `on-surface` (no gris tenue)

### Helper Text (Opcional)
```tsx
<label htmlFor="password">Contraseña *</label>
<input type="password" id="password" aria-describedby="pwd-hint" />
<span id="pwd-hint">Mínimo 8 caracteres, 1 mayúscula, 1 número</span>
```
- Debajo del input, 12px, color `on-surface-variant`
- Desaparece en error (reemplazado por error)

### Placeholder (Solo Ejemplo)
```tsx
<input placeholder="ejemplo@empresa.com" />
```
- ✅ Solo ejemplo de formato
- ❌ No reemplaza label
- ❌ No instrucciones críticas

---

## 🔍 Validación

### Cuándo Validar
| Momento | Tipo | Campos |
|---------|------|--------|
| On blur | Inline | Todos |
| On change (después error) | Inline | Solo con error previo |
| On submit | Completa | Todos |

### Estados Visuales
```
┌─────────────────────────────────────┐  Estado: Idle
│ Email *                             │
│ ┌─────────────────────────────────┐ │
│ │ usuario@empresa.com             │ │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐  Estado: Error
│ Email *                             │
│ ┌─────────────────────────────────┐ │
│ │ usuario@empresa                 │ │
└─────────────────────────────────────┘
│ ⚠ Formato de email inválido       │  ← Rojo, 12px, icon
└─────────────────────────────────────┘

┌─────────────────────────────────────┐  Estado: Éxito
│ Email *                             │
│ ┌─────────────────────────────────┐ │
│ │ usuario@empresa.com      ✓      │  ← Verde, check
└─────────────────────────────────────┘
```

### Mensajes de Error
| Tipo | Mensaje | Ejemplo |
|------|---------|---------|
| Required | "Campo requerido" | "El email es requerido" |
| Format | "Formato inválido" | "Formato de email inválido" |
| Min/Max | "Mínimo X caracteres" | "Mínimo 8 caracteres" |
| Pattern | "Formato inválido" | "Solo letras y números" |
| Custom | Específico | "Email ya registrado" |

**Reglas de Mensajes:**
- ✅ Qué pasó + qué hacer
- ✅ Lenguaje humano (no técnico)
- ✅ Específico al campo
- ❌ No "Error 400", "Invalid input"

---

## ⌨️ Tipos de Input y Autocomplete

### Input Types Correctos
| Campo | Type | Autocomplete | InputMode |
|-------|------|--------------|-----------|
| Email | `email` | `email` | `email` |
| Teléfono | `tel` | `tel` | `tel` |
| Contraseña | `password` | `current-password` | - |
| Nueva contraseña | `password` | `new-password` | - |
| Código OTP | `text` | `one-time-code` | `numeric` |
| Tarjeta | `text` | `cc-number` | `numeric` |
| Fecha | `date` | `bday` | - |
| Número | `number` | - | `numeric` |
| Texto | `text` | `off` / específico | `text` |
| Búsqueda | `search` | `off` | `search` |

### Autocomplete Values Clave
```html
<!-- Dirección -->
autocomplete="street-address"
autocomplete="address-line2"
autocomplete="address-level1"  <!-- Provincia/Estado -->
autocomplete="address-level2"  <!-- Ciudad -->
autocomplete="postal-code"
autocomplete="country"

<!-- Nombre -->
autocomplete="name"
autocomplete="given-name"
autocomplete="family-name"
autocomplete="honorific-prefix"

<!-- Contacto -->
autocomplete="email"
autocomplete="tel"
autocomplete="tel-national"
autocomplete="tel-country-code"

<!-- Pago -->
autocomplete="cc-number"
autocomplete="cc-exp"
autocomplete="cc-csc"
autocomplete="cc-type"
```

---

## 📐 Layouts de Formulario

### Vertical Stack (Default)
```tsx
<Box sx={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
  <TextField label="Nombre *" required />
  <TextField label="Email *" type="email" required />
  <TextField label="Teléfono" type="tel" />
</Box>
```

### Grid 2 Columnas (Tablet/Desktop)
```tsx
<Grid container spacing={3} columns={{ xs: 1, sm: 2 }}>
  <Grid item xs={12} sm={6}>
    <TextField label="Nombre *" required />
  </Grid>
  <Grid item xs={12} sm={6}>
    <TextField label="Apellido *" required />
  </Grid>
  <Grid item xs={12} sm={6}>
    <TextField label="Email *" type="email" required />
  </Grid>
  <Grid item xs={12} sm={6}>
    <TextField label="Teléfono" type="tel" />
  </Grid>
</Grid>
```

### Secciones Colapsables (Formularios Largos)
```tsx
<Accordion>
  <AccordionSummary expandIcon={<ExpandMoreIcon />}>
    <Typography variant="subtitle1">Datos Personales</Typography>
  </AccordionSummary>
  <AccordionDetails>
    <FormFields />
  </AccordionDetails>
  
  <AccordionSummary expandIcon={<ExpandMoreIcon />}>
    <Typography variant="subtitle1">Dirección</Typography>
  </AccordionSummary>
  <AccordionDetails>
    <AddressFields />
  </AccordionDetails>
</Accordion>
```

---

## 🎯 Patrones Específicos

### Contraseña con Toggle
```tsx
const [showPassword, setShowPassword] = useState(false);

<TextField
  type={showPassword ? 'text' : 'password'}
  label="Contraseña"
  InputProps={{
    endAdornment: (
      <InputAdornment position="end">
        <IconButton
          onClick={() => setShowPassword(!showPassword)}
          edge="end"
          aria-label={showPassword ? 'Ocultar' : 'Mostrar'}
        >
          {showPassword ? <VisibilityOffIcon /> : <VisibilityIcon />}
        </IconButton>
      </InputAdornment>
    )}
  />
```

### Select / Autocomplete
```tsx
<Autocomplete
  options={options}
  getOptionLabel={(o) => o.name}
  renderInput={(params) => (
    <TextField {...params} label="Categoría *" required />
  )}
  renderOption={(props, option) => (
    <Box {...props} sx={{ py: 1 }}>
      {option.name}
    </Box>
  )}
/>
```

### File Upload
```tsx
const [file, setFile] = useState(null);

<input
  type="file"
  accept=".pdf,.jpg,.png"
  onChange={(e) => setFile(e.target.files?.[0])}
  hidden
  id="file-upload"
  ref={inputRef}
/>
<Button 
  variant="outlined" 
  component="label" 
  onClick={() => inputRef.current?.click()}
  startIcon={<CloudUploadIcon />}
>
  Adjuntar archivo
</Button>
{file && <Chip label={file.name} onDelete={() => setFile(null)} />}
```

### Date Picker
```tsx
<LocalizationProvider dateAdapter={AdapterDateFns}>
  <DatePicker
    label="Fecha de nacimiento"
    value={date}
    onChange={setDate}
    slotProps={{
      textField: { 
        inputFormat: 'dd/MM/yyyy',
        placeholder: 'DD/MM/AAAA'
      }
    }}
  />
</LocalizationProvider>
```

---

## ✅ Checklist Formulario Completo

- [ ] Título claro (Crear/Editar + Entidad)
- [ ] Botón guardar sticky (bottom/right)
- [ ] Cancel con confirmación si dirty
- [ ] Validación inline (blur)
- [ ] Submit deshabilitado hasta válido
- [ ] Autofocus primer campo
- [ ] Autocomplete attributes correctos
- [ ] Labels visibles + asterisco requeridos
- [ ] Helper text donde necesario
- [ ] Validación inline (blur) + submit
- [ ] Error inline + toast
- [ ] Submit deshabilitado hasta válido
- [ ] Autofocus primer campo
- [ ] Autocomplete attributes
- [ ] Labels visibles + asterisco requeridos
- [ ] Helper text donde necesario
- [ ] Validación inline (blur) + submit
- [ ] Error inline + toast
- [ ] Submit deshabilitado hasta válido
- [ ] Autofocus primer campo
- [ ] Autocomplete attributes
- [ ] Loading en submit
- [ ] Éxito → toast + navigate
- [ ] Error → toast + focus error
- [ ] Responsive: 1 col mobile, 2 col tablet, 3 col desktop