# ⚠️ Estados de Error - Patrones y Mejores Prácticas

> **Un error bien diseñado enseña. Uno mal diseñado frustra.**

---

## 🎯 Tipos de Error y Cuándo Usar Cada Uno

### 1. **Error Inline (Campo Individual)**
```
┌─────────────────────────────────────┐
│ Email *                             │
│ ┌─────────────────────────────────┐ │
│ │ usuario@empresa                 │ │
└─────────────────────────────────────┘
⚠ Formato de email inválido
```
- **Cuándo:** Validación de campo individual
- **Dónde:** Debajo del input, rojo, 12px
- **Cuándo mostrar:** On blur (si error) o on submit
- **Desaparece:** Al corregir (on change)

### 2. **Toast Error (No Bloqueante)**
```
┌─────────────────────────────────────┐
│ ⚠ Error al guardar: Servidor caído  │  [×]
└─────────────────────────────────────┘
```
- **Cuándo:** Error de servidor, red, permisos
- **Posición:** Bottom-center (mobile) / bottom-right (desktop)
- **Acciones:** Reintentar, Descartar, Ver detalles
- **Duración:** 5-6s, dismissible

### 3. **Modal Error (Crítico / Bloqueante)**
```
┌─────────────────────────────────────┐
│ ⚠  Error Crítico                    │
├─────────────────────────────────────┤
│ No se pudo procesar el pago.        │
│ Tu tarjeta no ha sido cargada.      │
├─────────────────────────────────────┤
│ [Reintentar]    [Contactar Soporte] │
└─────────────────────────────────────┘
```
- **Cuándo:** Pérdida de datos, pago fallido, seguridad
- **Acciones:** Reintentar, Soporte, Ver detalles
- **No se cierra** hasta acción explícita

### 4. **Error Inline + Toast (Híbrido)**
```
# En formulario:
Campo con error inline + Toast global "Revisa los errores marcados"
```
- Para formularios con múltiples errores
- Focus automático al primer error

---

## 🎨 Estados Visuales de Error

### Input con Error
```tsx
<TextField
  error={true}
  helperText="Formato de email inválido"
  error={true}
/>
```

**Estados Visuales:**
| Estado | Border | Icon | Texto Helper |
|--------|--------|------|--------------|
| Default | Gris | - | Helper text |
| Focus | Primary 2px | - | Helper text |
| Error | Rojo 2px | ⚠ | Rojo, error text |
| Success | Verde 2px | ✓ | Verde, success text |
| Disabled | Gris 38% | - | - |

### Toast Error
```
┌─────────────────────────────────────┐
│ ❌  Error al guardar: Servidor caído │ [×]
└─────────────────────────────────────┘
```
- Icono: ❌ (rojo)
- Fondo: Error container
- Acción: "Reintentar" / "Detalles"

### Modal Error
```
┌─────────────────────────────────────┐
│ ⚠  Error Crítico                    │
├─────────────────────────────────────┤
│ No se pudo procesar el pago.        │
│ Tu tarjeta no ha sido cargada.      │
├─────────────────────────────────────┤
│ [Reintentar]    [Contactar Soporte] │
└─────────────────────────────────────┘
```

---

## 📝 Mensajes de Error: Guía de Redacción

### Plantillas por Tipo
| Error | Template | Ejemplo |
|-------|----------|---------|
| Required | "{Campo} es requerido" | "El email es requerido" |
| Formato | "Formato de {campo} inválido" | "Formato de email inválido" |
| Min length | "Mínimo {n} caracteres" | "Mínimo 8 caracteres" |
| Max length | "Máximo {n} caracteres" | "Máximo 100 caracteres" |
| Pattern | "Formato de {campo} inválido" | "Solo letras y números" |
| Duplicate | "{Entidad} ya existe" | "Email ya registrado" |
| Not found | "{Entidad} no encontrada" | "Producto no encontrado" |
| Permission | "No tienes permisos para {acción}" | "No tienes permisos para eliminar" |
| Server | "Error del servidor. Intenta de nuevo" | "Error del servidor. Intenta de nuevo" |
| Network | "Sin conexión. Verifica tu internet" | "Sin conexión. Verifica tu internet" |
| Timeout | "La operación tardó demasiado. Intenta de nuevo" | "La operación tardó demasiado" |

### Reglas de Oro
| ✅ HACER | ❌ NO HACER |
|----------|-------------|
| "Email inválido" | "Error 400: Invalid email format" |
| "El email ya está registrado" | "Duplicate entry for key email" |
| "Mínimo 8 caracteres" | "Length must be >= 8" |
| "El archivo debe ser PDF, JPG o PNG" | "Invalid file type" |
| "El archivo supera 5MB" | "File size exceeds limit" |
| "La contraseña debe tener 1 mayúscula y 1 número" | "Password policy not met" |

---

## 🎯 Errores por Contexto

### Formularios
| Error | Inline | Toast | Modal |
|-------|--------|-------|-------|
| Campo requerido | ✅ | ❌ | ❌ |
| Formato inválido | ✅ | ❌ | ❌ |
| Duplicado (email) | ✅ | ✅ | ❌ |
| Contraseña débil | ✅ | ❌ | ❌ |
| Submit fallido | ❌ | ✅ | ❌ |
| Permisos | ❌ | ✅ | ✅ |
| Sesión expirada | ❌ | ❌ | ✅ |

### Listas/Tablas
| Acción | Error | UI |
|--------|-------|-----|
| Eliminar fallido | Toast + undo | Toast + retry |
| Editar fallido | Inline + toast | Toast |
| Bulk actions | Toast con contador | Toast + detalles |

### Navegación
| Caso | UI |
|------|-----|
| 404 | Página dedicada + search |
| 403 | Modal + redirect login |
| 500 | Página error + retry |
| Offline | Banner superior + retry |

---

## 🎯 Patrones de Recuperación

### 1. Retry con Backoff
```tsx
const retryWithBackoff = async (fn, maxRetries = 3) => {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      await new Promise(r => setTimeout(r, 1000 * Math.pow(2, i)));
    }
  }
};
```

### 2. Offline Queue
```tsx
// Guardar localmente si offline
const saveOffline = (action) => {
  if (!navigator.onLine) {
    offlineQueue.push(action);
    showToast('Sin conexión. Se sincronizará al reconectar');
    return;
  }
  // Ejecutar normalmente
};
```

### 3. Retry con Backoff Exponencial
```tsx
const retryWithBackoff = async (fn, maxRetries = 3) => {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      await new Promise(r => setTimeout(r, 1000 * Math.pow(2, i)));
    }
  }
};
```

---

## 🎯 Checklist Estados de Error

- [ ] Error inline: rojo, 12px, icono ⚠, texto claro
- [ ] Toast error: 5-6s, dismissible, acción retry
- [ ] Modal error: solo críticos, acciones claras
- [ ] Focus automático al primer error en submit
- [ ] Scroll suave al primer error
- [ ] Errores se limpian al corregir (on change)
- [ ] Mensajes humanos, no técnicos
- [ ] No solo color: icon + texto
- [ ] Contraste error: ≥4.5:1
- [ ] Focus visible en error fields
- [ ] Live region para screen readers (aria-live)
- [ ] Rollback en optimistic UI fallido
- [ ] Undo para acciones reversibles
- [ ] Retry con backoff exponencial
- [ ] Offline queue para acciones offline