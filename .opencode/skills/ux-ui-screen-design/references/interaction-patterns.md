# 🔄 Patrones de Interacción y Feedback

> **Cada acción merece respuesta. Silencio = confusión.**

---

## ⚡ Feedback Inmediato

### Tiempos de Respuesta
| Acción | Tiempo Máx | Feedback |
|--------|------------|----------|
| Click/tap | < 100ms | Visual (ripple, scale) |
| Navegación | < 200ms | Transición + skeleton |
| Submit form | Variable | Loading en botón |
| Búsqueda | 300ms debounce | Skeleton resultados |
| Acción destructiva | Inmediato | Modal confirmación |

### Tipos de Feedback

#### 1. **Ripple / Pressed** (< 100ms)
```css
button:active { transform: scale(0.98); }
button:focus-visible { outline: 2px solid #1976D2; outline-offset: 2px; }
```

#### 2. **Loading en Botón** (acciones > 300ms)
```tsx
<Button loading={isSubmitting} disabled={isSubmitting}>
  {isSubmitting ? <Spinner size={16} /> : 'Guardar'}
</Button>
```

#### 3. **Skeleton Loading** (carga > 300ms)
```tsx
{isLoading ? (
  <Skeleton variant="rectangular" width={200} height={40} />
) : (
  <Button>Guardar</Button>
)}
```

#### 4. **Toast / Snackbar** (feedback no bloqueante)
```tsx
// Éxito
snackbar.success('Documento guardado');

// Error
snackbar.error('Error al guardar: servidor no disponible');

// Info
snackbar.info('3 elementos seleccionados');
```

**Duraciones:**
| Tipo | Duración | Acción |
|------|----------|--------|
| Éxito | 3-4s | Auto-dismiss |
| Error | 5-6s | Dismissible |
| Warning | 4-5s | Dismissible |
| Info | 3-4s | Auto-dismiss |

---

## 🔄 Estados de Carga

### Jerarquía de Loading
| Prioridad | Tipo | Uso |
|-----------|------|-----|
| 1 | **Skeleton** | Carga inicial, listas, cards |
| 2 | **Progress Bar** | Progreso conocido (uploads) |
| 3 | **Spinner** | Acciones puntuales, botones |
| 4 | **Optimistic UI** | Acciones optimistas (like, toggle) |

### Skeleton Patterns
```tsx
// Card skeleton
<Card>
  <Skeleton variant="rectangular" width="100%" height={200} />
  <Box p={3}>
    <Skeleton variant="text" width="60%" />
    <Box mt={2} />
    <Skeleton variant="text" width="40%" />
  </Box>
</Card>

// List skeleton
<List>
  {[...Array(5)].map((_, i) => (
    <ListItem key={i}>
      <Skeleton variant="circular" width={40} height={40} />
      <Box ml={2}>
        <Skeleton variant="text" width="60%" />
        <Skeleton variant="text" width="40%" />
      </Box>
    </ListItem>
  ))}
</List>
```

### Progress Indicators
```tsx
// Determinate (progreso conocido)
<LinearProgress value={progress} variant="determinate" />

// Indeterminate (carga desconocida)
<CircularProgress />

// Steps
<Stepper activeStep={step} alternativeLabel>
  {steps.map((step, i) => (
    <Step key={i}>
      <StepLabel>{step.label}</StepLabel>
    </Step>
  ))}
</Stepper>
```

---

## 🔁 Optimistic UI

### Patrón: Optimistic Update
```tsx
const toggleLike = async (itemId) => {
  // 1. UI inmediata (optimista)
  setItems(prev => prev.map(item => 
    item.id === itemId ? { ...item, liked: !item.liked, likes: item.liked ? item.likes - 1 : item.likes + 1 }
  ));

  try {
    await api.toggleLike(itemId);
  } catch (error) {
    // Rollback en error
    setItems(prev => prev.map(item => 
      item.id === itemId ? { ...item, liked: !item.liked, likes: item.liked ? item.likes + 1 : item.likes - 1 }
    ));
    toast.error('Error al actualizar');
  }
};
```

### Cuándo Usar
| Acción | Optimistic? | Rollback |
|----------|-------------|----------|
| Like/favorite | ✅ Sí | Fácil |
| Toggle estado | ✅ Sí | Fácil |
| Crear recurso | ⚠️ Parcial | Complejo |
| Eliminar | ⚠️ Parcial | Undo mejor |
| Pago/Compra | ❌ No | Crítico |

---

## 🔄 Undo Pattern (Mejor que Confirmación)

### Cuándo Usar Undo vs Confirmación
| Acción | Patrón |
|--------|---------|
| Eliminar item lista | **Undo** (5-10s) |
| Archivar | **Undo** |
| Enviar email | Confirmación modal |
| Pago | Confirmación + 2FA |
| Eliminar cuenta | Confirmación + 2FA + delay |

### Implementación Undo
```tsx
const [snackbar, setSnackbar] = useState(null);

const handleDelete = (item) => {
  const previousItems = items;
  setItems(prev => prev.filter(i => i.id !== item.id));
  
  setSnackbar({
    message: 'Elemento eliminado',
    action: 'Deshacer',
    onAction: () => setItems(previousItems),
    duration: 8000
  });

  // Auto-delete tras timeout
  setTimeout(() => {
    if (snackbar) api.delete(item.id);
  }, 8000);
};
```

---

## 🔄 Estados de Formulario

### Estados del Botón Submit
| Estado | Visual | Comportamiento |
|--------|--------|----------------|
| Idle | Primary enabled | Click = submit |
| Validating | Spinner 16px | Deshabilitado |
| Success | Check + verde | Auto-navigate / toast |
| Error | Error inline + toast | Re-enabled |

```tsx
const [submitState, setSubmitState] = useState('idle'); // idle | validating | success | error

<Button
  type="submit"
  disabled={submitState !== 'idle'}
  loading={submitState === 'validating'}
  startIcon={submitState === 'success' ? <CheckIcon /> : submitState === 'error' ? <ErrorIcon /> : null}
>
  {submitState === 'validating' ? 'Guardando...' : 'Guardar'}
</Button>
```

---

## 🔔 Notificaciones: Cuándo Cada Una

| Tipo | Componente | Cuándo |
|------|------------|--------|
| Éxito simple | Toast | Operación completada |
| Error recuperable | Toast + acción | Error con retry |
| Error crítico | Modal + toast | Pérdida datos, pago fallido |
| Advertencia | Toast warning | Stock bajo, expiración |
| Info neutra | Toast info | Cambios guardados auto |
| Confirmación destructiva | Modal | Eliminar, cancelar cuenta |
| Progreso largo | Progress bar + toast | Upload, export, sync |

### Toast Anatomy
```
┌─────────────────────────────────────┐
│ ✅  Documento guardado        [×]   │
└─────────────────────────────────────┘
```
- Posición: bottom-center (mobile), bottom-right (desktop)
- Stack: max 3 simultáneos
- Swipe to dismiss (mobile)
- Click acción = focus acción relacionada

---

## 🔄 Pull to Refresh / Infinite Scroll

### Pull to Refresh (Mobile)
```tsx
<RefreshIndicator onRefresh={onRefresh} refreshing={refreshing}>
  <List>...</List>
</RefreshIndicator>
```
- Trigger: 80px drag
- Feedback: spinner + "Suelta para actualizar"
- Timeout: 10s max

### Infinite Scroll
```tsx
<InfiniteScroll
  dataLength={items.length}
  next={loadMore}
  hasMore={hasMore}
  loader={<CircularProgress />}
  endMessage="No hay más elementos"
>
  {items.map(item => <Item key={item.id} {...item} />)}
</InfiniteScroll>
```
- Trigger: 200px antes del final
- Loader: spinner centrado
- End message claro

---

## 🎯 Checklist Feedback Completo

- [ ] Click/tap → ripple < 100ms
- [ ] Submit → loading en botón + disabled
- [ ] Carga > 300ms → skeleton
- [ ] Éxito → toast 3-4s
- [ ] Error → inline + toast + focus error
- [ ] Acción destructiva → modal confirm / undo
- [ ] Loading > 300ms → skeleton > spinner
- [ ] Optimistic UI para likes/toggles
- [ ] Undo > confirmación para acciones reversibles
- [ ] Loading states en TODAS las acciones async
- [ ] Focus management en modales/drawers
- [ ] Live regions para actualizaciones dinámicas