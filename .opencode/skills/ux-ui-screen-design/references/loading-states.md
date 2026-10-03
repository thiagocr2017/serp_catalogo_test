# ⏳ Estados de Carga - Patrones y Mejores Prácticas

> **La espera se siente más corta cuando el usuario entiende qué pasa.**

---

## 🎯 Jerarquía de Loading

### Prioridad de Uso
| Prioridad | Tipo | Cuándo Usar |
|-----------|------|-------------|
| 1 | **Skeleton** | Carga inicial, listas, cards, tablas |
| 2 | **Progress Bar** | Progreso conocido (uploads, imports) |
| 3 | **Spinner** | Acciones puntuales, botones, acciones rápidas |
| 4 | **Optimistic UI** | Acciones inmediatas (like, toggle, delete) |

---

## 💀 Skeleton Loading (Prioridad #1)

### Cuándo Usar
- Carga inicial de pantalla
- Listas, grids, tablas
- Cards con imagen + texto
- Tablas con datos
- Perfiles, dashboards

### Patrones por Componente

#### Card Skeleton
```tsx
<Card>
  <Skeleton variant="rectangular" width="100%" height={200} />
  <Box p={3}>
    <Skeleton variant="text" width="60%" />
    <Box mt={2} />
    <Skeleton variant="text" width="40%" />
    <Box mt={2} />
    <Skeleton variant="circular" width={32} height={32} />
  </Box>
</Card>
```

#### List Skeleton
```tsx
<List>
  {[...Array(5)].map((_, i) => (
    <ListItem key={i} disablePadding>
      <Skeleton variant="circular" width={48} height={48} />
      <Box sx={{ ml: 2, flex: 1 }}>
        <Skeleton variant="text" width="60%" />
        <Skeleton variant="text" width="40%" />
      </Box>
    </ListItem>
  ))}
</List>
```

#### Table Skeleton
```tsx
<TableContainer>
  <Table>
    <TableHead>
      <TableRow>
        {columns.map(col => (
          <TableCell key={col.id}>
            <Skeleton variant="text" width={col.width} height={24} />
          </TableCell>
        ))}
      </TableRow>
    </TableHead>
    <TableBody>
      {[...Array(5)].map((_, i) => (
        <TableRow key={i}>
          {columns.map(col => (
            <TableCell key={col.id}>
              <Skeleton variant="text" width={col.width} />
            </TableCell>
          ))}
        </TableRow>
      ))}
    </TableBody>
  </Table>
</TableContainer>
```

#### Dashboard Skeleton
```tsx
<Grid container spacing={3}>
  {/* KPI Cards */}
  {[1,2,3,4].map(i => (
    <Grid item xs={12} sm={6} md={3} key={i}>
      <Card>
        <Box p={3}>
          <Skeleton variant="text" width="40%" />
          <Box mt={1} />
          <Skeleton variant="text" width="80%" height={32} />
        </Box>
      </Card>
    )}
    
    {/* Chart */}
    <Grid item xs={12} md={8}>
      <Card>
        <Box p={3} minHeight={300}>
          <Skeleton variant="rectangular" width="100%" height="300" />
        </Box>
      </Card>
    </Grid>
    
    {/* Table */}
    <Grid item xs={12} md={4}>
      <Card>
        <TableSkeleton rows={5} cols={4} />
      </Card>
    </Grid>
  </Grid>
```

---

## 📊 Progress Bar (Progreso Conocido)

### Cuándo Usar
- Uploads con progreso conocido
- Imports/exports
- Multi-step processes con pasos conocidos
- Descargas

### Linear Progress
```tsx
// Determinate
<LinearProgress 
  value={progress} 
  variant="determinate"
  color="primary"
  sx={{ height: 8, borderRadius: 4 }}
/>

// Con label
<Box>
  <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
    <Typography variant="body2">Subiendo archivo...</Typography>
    <Typography variant="caption">{Math.round(progress)}%</Typography>
  </Box>
  <LinearProgress value={progress} variant="determinate" />
</Box>
```

### Circular Progress
```tsx
// Con porcentaje
<Box sx={{ position: 'relative', width: 64, height: 64 }}>
  <CircularProgress
    value={progress}
    variant="determinate"
    thickness={4}
    size={64}
  />
  <Box sx={{
    position: 'absolute',
    top: 0, left: 0, right: 0, bottom: 0,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center'
  }}>
    <Typography variant="caption">{Math.round(progress)}%</Typography>
  </Box>
</Box>
```

### Step Progress (Wizard)
```tsx
<Stepper activeStep={step} alternativeLabel>
  {steps.map((step, index) => (
    <Step key={step.label}>
      <StepLabel 
        StepIconProps={{ 
          fontSize: 'small',
        }}
      >
        {step.label}
      </StepLabel>
    </Step>
  ))}
</Stepper>
```

---

## 🔄 Spinner (Acciones Puntuales)

### Cuándo Usar
- Botón submit (loading)
- Acciones rápidas (< 3s)
- Botones de acción
- Refresh manual

### Button Loading
```tsx
<Button
  variant="contained"
  loading={isSubmitting}
  disabled={isSubmitting}
  startIcon={isSubmitting ? <CircularProgress size={16} color="inherit" /> : undefined}
>
  {isSubmitting ? 'Guardando...' : 'Guardar'}
</Button>
```

### Button States
| Estado | Visual | Texto |
|--------|--------|-------|
| Idle | Normal | "Guardar" |
| Loading | Spinner 16px | "Guardando..." |
| Success | ✓ + verde | "Guardado" |
| Error | ⚠ rojo | "Error" |

---

## 🎯 Optimistic UI (Feedback Inmediato)

### Cuándo Usar
| Acción | Optimistic? | Rollback |
|--------|-------------|----------|
| Like/Favorite | ✅ Sí | Fácil |
| Toggle estado | ✅ Sí | Fácil |
| Seguir/Dejar seguir | ✅ Sí | Fácil |
| Crear recurso | ⚠️ Parcial | Complejo |
| Eliminar | ⚠️ Parcial | Undo mejor |
| Pago/Compra | ❌ No | Crítico |

### Implementación
```tsx
const toggleLike = async (itemId) => {
  // 1. UI inmediata (optimista)
  setItems(prev => prev.map(item => 
    item.id === itemId 
      ? { ...item, liked: !item.liked, likes: item.liked ? item.likes - 1 : item.likes + 1 }
      : item
  ));

  try {
    await api.toggleLike(itemId);
  } catch (error) {
    // Rollback en error
    setItems(prev => prev.map(item => 
      item.id === itemId 
        ? { ...item, liked: !item.liked, likes: item.liked ? item.likes + 1 : item.likes - 1 }
        : item
    ));
    toast.error('Error al actualizar');
  }
};
```

---

## 🎯 Pull to Refresh / Infinite Scroll

### Pull to Refresh (Mobile)
```tsx
<RefreshIndicator 
  onRefresh={onRefresh} 
  refreshing={refreshing}
  progressBackgroundColor="#fff"
  color="#1976D2"
>
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

## 🎯 Loading States Checklist

- [ ] Carga inicial → Skeleton
- [ ] Lista/tabla → Skeleton rows
- [ ] Card con imagen → Skeleton image + text
- [ ] Tabla → Skeleton rows + headers
- [ ] Dashboard → KPI skeletons + chart skeleton + table skeleton
- [ ] Upload → Progress bar determinate
- [ ] Import/Export → Progress bar + steps
- [ ] Botón submit → Spinner en botón
- [ ] Acción rápida → Spinner en botón
- [ ] Like/Toggle → Optimistic UI
- [ ] Pull to refresh → 80px drag, spinner
- [ ] Infinite scroll → 200px threshold, spinner
- [ ] Loading > 300ms → Skeleton
- [ ] Loading < 300ms → Spinner
- [ ] Loading determinate → Progress bar
- [ ] Loading indeterminate → Skeleton/Spinner
- [ ] Optimistic UI para likes/toggles
- [ ] Rollback en error de optimistic UI
- [ ] Pull to refresh: 80px drag
- [ ] Infinite scroll: 200px threshold
- [ ] Pull to refresh timeout: 10s
- [ ] Infinite scroll end message