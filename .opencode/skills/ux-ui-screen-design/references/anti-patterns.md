# 🚫 Anti-Patrones UX/UI (Con Solución)

> **Aprender de los errores ajenos evita cometerlos tú.**

---

## 📝 Formularios

| ❌ Anti-Patrón | ✅ Solución |
|---------------|-------------|
| Placeholder como label | Label visible siempre + placeholder solo ejemplo |
| Validación solo al submit | Validación inline (on blur) + submit |
| Submit habilitado siempre | Deshabilitado hasta form válido |
| Error solo en toast | Error inline + toast |
| Modal para todo | Inline > Drawer > Modal |
| Spinner en botón > 3s | Skeleton / progreso real |
| Placeholder como ayuda | Helper text visible |
| Validación solo cliente | Server + cliente |
| Color solo para estado | Icon + texto + patrón |

---

## 📋 Listas y Tablas

| ❌ Anti-Patrón | ✅ Solución |
|---------------|-------------|
| Tabla densa en mobile | Cards responsive |
| Sin empty state | Ilustración + copy + CTA |
| Sin loading state | Skeleton > spinner |
| Sin empty state en filtros | "Sin resultados para X" + clear filters |
| Acciones ocultas en hover | Visibles o overflow menu |
| Sin acciones bulk | Checkbox + toolbar flotante |
| Paginación sin total | "X de Y resultados" |
| Ordenamiento invisible | Header clicable + icono dirección |

---

## 🔘 Botones y Acciones

| ❌ Anti-Patrón | ✅ Solución |
|---------------|-------------|
| 2+ botones primary | 1 primary, resto secondary/tertiary |
| Botón primary a la izquierda | Primary a la derecha (desktop) / bottom (mobile) |
| Icono solo sin label | Label visible + icon opcional |
| Color solo para estado | Icon + texto + patrón |
| Loading infinito sin feedback | Timeout + retry |
| Botón disabled sin explicación | Tooltip/hint explicando por qué |

---

## 📱 Navegación y Layout

| ❌ Anti-Patrón | ✅ Solución |
|---------------|-------------|
| Breadcrumbs en móvil | Back button + title |
| Tabs ocultos en mobile | Scroll horizontal tabs |
| Sidebar fija en mobile | Bottom nav / drawer |
| Tabs > 5 en desktop | Agrupar / dropdown |
| Navegación oculta | Siempre visible o hamburguesa clara |
| Back browser ≠ back app | Router sync + back handler |

---

## 📝 Formularios

| ❌ Anti-Patrón | ✅ Solución |
|---------------|-------------|
| Validación solo al submit | Inline on blur + submit |
| Error solo color rojo | Icon + texto + patrón |
| Campos opcionales sin marcar | Marcar requeridos (*) |
| Dropdown > 10 opciones | Autocomplete / search |
| Fecha input libre | Date picker nativo |
| Teléfono input libre | Mask + validation |
| Checkbox "Acepto términos" obligado | Link a términos + checkbox requerido |

---

## 📱 Mobile y Touch

| ❌ Anti-Patrón | ✅ Solución |
|---------------|-------------|
| Hover-only actions | Visible o long-press |
| Hover tooltips en touch | Tap para tooltip |
| Drag-drop solo mouse | Touch alternative |
| Hover menus | Click/tap to open |
| Drag scroll horizontal | Swipe nativo |
| Pinch zoom deshabilitado | Permitir zoom |
| Fixed headers sin padding | Safe area padding |
| Input zoom en iOS | font-size ≥ 16px |

---

## ♿ Accesibilidad

| ❌ Anti-Patrón | ✅ Solución |
|---------------|-------------|
| Color solo para estado | Icon + texto + patrón |
| Contraste < 4.5:1 | Mínimo 4.5:1 (AA) |
| Focus invisible | outline 2px + offset 2px |
| Tab order aleatorio | DOM order = visual order |
| Modales sin focus trap | Focus trap + restore |
| Escape no cierra modal | Escape = close |
| Imágenes sin alt | alt descriptivo / "" decorativo |
| Form sin labels | Label + for/id siempre |
| Iconos sin label | aria-label / aria-hidden |
| Carousel auto-play | Pause on hover + controls |

---

## 🎨 Visual y UI

| ❌ Anti-Patrón | ✅ Solución |
|---------------|-------------|
| Sombras inconsistentes | Sistema elevación (0-24dp) |
| Border radius aleatorios | Sistema 4/8/12/16/24 |
| Sombras duras (box-shadow 0 0 20px) | Elevation system |
| Colores hardcodeados | Design tokens |
| Fuentes > 3 familias | Máx 2 familias |
| Texto justificado | Left align / justify solo ancho |
| All caps en body | Sentence case |
| Line height < 1.5 en body | ≥ 1.5 |
| Imágenes sin alt | alt="" decorativo / descriptivo |

---

## 🔄 Estados y Feedback

| ❌ Anti-Patrón | ✅ Solución |
|---------------|-------------|
| Sin loading state | Skeleton > spinner |
| Spinner infinito | Timeout 10s + retry |
| Error solo toast | Inline + toast |
| Error solo color | Icon + texto + patrón |
| Sin confirmación destructiva | Modal / Undo |
| Success sin feedback | Toast + visual |
| Optimistic UI sin rollback | Rollback automático |
| Double submit posible | Disable on submit |

---

## 📊 Datos y Tablas

| ❌ Anti-Patrón | ✅ Solución |
|---------------|-------------|
| Tabla horizontal scroll mobile | Cards responsive |
| Ordenamiento invisible | Header clicable + icon |
| Filtros ocultos | Visibles / collapsible |
| Sin total resultados | "X de Y" + paginación |
| Acciones ocultas en hover | Visibles / overflow menu |
| Datos sin contexto | Empty state + CTA |

---

## 🎨 Visual y Branding

| ❌ Anti-Patrón | ✅ Solución |
|---------------|-------------|
| Logo en header + footer | Solo header |
| Favicon genérico | Brand.ico + apple-touch-icon |
| Splash screen > 3s | Skeleton inmediato |
| Loading spinners múltiples | 1 solo loader |
| Animaciones > 500ms | 150-300ms max |
| Parallax sin reduce-motion | Respect prefers-reduced-motion |

---

## 🚀 Performance y UX

| ❌ Anti-Patrón | ✅ Solución |
|---------------|-------------|
| Layout shift (CLS > 0.1) | Reserve space / aspect-ratio |
| Imágenes sin dimensions | width/height / aspect-ratio |
| Fuentes bloqueando render | font-display: swap |
| JS bloqueando render | defer / async / code-split |
| Bundle > 200KB gzipped | Code splitting |
| No skeleton loading | Skeleton > spinner |
| Re-renders innecesarios | React.memo / useMemo |
| Imágenes sin lazy | loading="lazy" |

---

## 🎯 Quick Reference: Top 10 Anti-Patrones

| # | Anti-Patrón | Impacto | Fix Rápido |
|---|-------------|---------|------------|
| 1 | Placeholder = Label | Alto | Label visible + placeholder ejemplo |
| 2 | Validación solo submit | Alto | Inline on blur |
| 3 | Submit siempre habilitado | Alto | Disabled hasta válido |
| 4 | Error solo toast | Alto | Inline + toast |
| 4 | Tabla horizontal scroll mobile | Alto | Cards responsive |
| 5 | Tabla horizontal scroll mobile | Alto | Cards responsive |
| 6 | Color solo para estado | Medio | Icon + texto |
| 7 | Focus invisible | Alto | outline 2px + offset 2px |
| 8 | Submit doble posible | Alto | Disable on submit |
| 9 | Loading > 3s sin skeleton | Medio | Skeleton |
| 10 | Modal para todo | Medio | Inline > Drawer > Modal |

---

## 🎯 Regla de Oro

> **Si el usuario tiene que pensar "¿qué hago ahora?", ya fallaste.**