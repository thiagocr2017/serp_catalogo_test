#!/bin/bash

# ux-audit.sh - Auditoría rápida UX usando checklist-new-screen.md
# Uso: ./ux-audit.sh --screen "ruta/al/archivo" [--verbose]
#
# Soporta dos ecosistemas y elige los checks según la extensión del archivo:
#   .dart                 -> Flutter (checks de SERP: ColorScheme, Semantics,
#                            estados, límites de módulo y test en test/)
#   .tsx .jsx .js .ts     -> React (comportamiento original, sin cambios)
#   otras extensiones     -> solo los checks comunes de archivo
#
# Los checks de cada ecosistema son independientes: adaptar Flutter no altera
# el resultado de una auditoría React.

# No usar set -e para permitir que las checks fallen sin salir del script

SCREEN_PATH=""
VERBOSE=false

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --screen)
            SCREEN_PATH="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Uso: $0 --screen <ruta> [--verbose]"
            exit 1
            ;;
    esac
done

if [[ -z "$SCREEN_PATH" ]]; then
    echo "Error: --screen es requerido"
    echo "Uso: $0 --screen <ruta/al/archivo> [--verbose]"
    exit 1
fi

if [[ ! -f "$SCREEN_PATH" ]]; then
    echo "Error: Archivo no encontrado: $SCREEN_PATH"
    exit 1
fi

echo "🔍 Auditoría UX: $SCREEN_PATH"
echo "=================================="

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0
WARN=0

check() {
    local desc="$1"
    local condition="$2"
    local fix="$3"
    
    if eval "$condition"; then
        echo -e "${GREEN}✅ PASS${NC}: $desc"
        ((PASS++))
    else
        echo -e "${RED}❌ FAIL${NC}: $desc"
        if [[ -n "$fix" ]]; then
            echo -e "   ${YELLOW}Fix:${NC} $fix"
        fi
        ((FAIL++))
    fi
}

warn() {
    local desc="$1"
    local suggestion="$2"
    echo -e "${YELLOW}⚠️  WARN${NC}: $desc"
    if [[ -n "$suggestion" ]]; then
        echo -e "   Sugerencia: $suggestion"
    fi
    ((WARN++))
}

# Verificar archivo existe
FILE="$SCREEN_PATH"
EXT="${FILE##*.}"

# Checks básicos de archivo
check "Archivo existe" "[[ -f \"$FILE\" ]]"
check "Archivo no vacío" "[[ -s \"$FILE\" ]]"

# ---------------------------------------------------------------------------
# Rama Flutter / Dart
# ---------------------------------------------------------------------------
if [[ "$EXT" == "dart" ]]; then

    # Es un widget de pantalla
    check "Es un widget" "grep -q 'StatelessWidget\\|StatefulWidget\\|ConsumerWidget\\|ConsumerStatefulWidget\\|HookConsumerWidget' \"$FILE\"" \
        "Una pantalla de Flutter debe ser un widget (Stateless/Stateful/Consumer)."

    # Tema: usar ColorScheme en vez de colores fijos
    check "Usa Theme/ColorScheme" "grep -q 'Theme.of(\\|ColorScheme' \"$FILE\"" \
        "Usa Theme.of(context).colorScheme; el modo oscuro es el predeterminado."
    if grep -qE 'Color\(0x|Colors\.[a-zA-Z]+' "$FILE"; then
        warn "Hay colores literal en el archivo" \
            "Sustituir por ColorScheme salvo colores semánticos con contraste explícito (ver AGENTS.md)."
    fi

    # Accesibilidad
    check "Semántica accesible" "grep -q 'Semantics(\\|semanticsLabel\\|semanticsValue\\|Tooltip(' \"$FILE\"" \
        "Añadir Semantics/Tooltip; los iconos sin etiqueta no son accesibles."
    if grep -q 'IconButton\|Image\.' "$FILE"; then
        check "Iconos/imagenes con etiqueta" "grep -q 'tooltip\\|semanticLabel\\|semanticsLabel' \"$FILE\"" \
            "IconButton e Image deben declarar tooltip o semanticLabel."
    fi

    # Estados de carga y error
    check "Loading state presente" "grep -q 'CircularProgressIndicator\\|LinearProgressIndicator\\|isLoading\\|Skeleton\\|Shimmer' \"$FILE\"" \
        "Toda pantalla con datos asíncronos debe mostrar estado de carga."
    check "Estados de error" "grep -q 'error\\|Error\\|catch' \"$FILE\"" \
        "Toda pantalla asíncrona debe manejar y mostrar el error."

    # Formularios
    if grep -q 'TextFormField\\|TextField\\|DropdownButtonFormField\\|InputDecoration' "$FILE"; then
        check "Campos con etiqueta" "grep -q 'labelText\\|label:\\|InputDecoration' \"$FILE\"" \
            "Los campos necesitan etiqueta visible, no solo hintText."
        check "Form con GlobalKey o validator" "grep -q 'GlobalKey<FormState>\\|validator' \"$FILE\"" \
            "Un formulario debe validar antes de persistir."
        check "Gestion de foco" "grep -q 'FocusNode\\|FocusScope\\|focusNode\\|textInputAction\\|autofocus' \"$FILE\"" \
            "Define FocusNode/textInputAction para navegación por teclado."
    fi

    # Límites de módulo (regla crítica de este proyecto)
    check "Sin imports internos de otros modulos" \
        "! grep -qE \"import ['\\\"]package:[^'\\\"]*/modules/[a-z_]+/(data|domain|di|presentation|services)/\" \"$FILE\"" \
        "Solo se puede importar <name>_module.dart de otros módulos (MODULE_SECURITY_CONTRACT.md)."

    # Salud de código en presentación
    if grep -q 'print(' "$FILE"; then
        warn "Hay print() en presentación" "Usar un logger o eliminarlo antes de PR."
    fi

    # Test: en este proyecto vive en test/ reflejando lib/
    MOD_TEST_DIR=$(echo "$FILE" | sed -E 's#^lib/##; s#^modules/##; s#^([a-z_]+)/.*#\1#' | sed 's#^#test/modules/#')
    BASE=$(basename "$FILE" .dart)
    # customers_page -> customers | product_form_page -> product | agent_page -> agent
    NAME=$(echo "$BASE" | sed -E 's#_form_page$##; s#_page$##; s#_form$##')
    FOUND_TEST=""
    for cand in \
        "${FILE%.dart}_test.dart" \
        "$MOD_TEST_DIR/presentation/${BASE}_test.dart" \
        "$MOD_TEST_DIR/presentation/${NAME}_test.dart"; do
        if [[ -f "$cand" ]]; then FOUND_TEST="$cand"; break; fi
    done
    # Último recurso: cualquier *_test.dart del módulo cuyo nombre contenga el
    # nombre base de la pantalla (cubre <entidad>_form_validation_test.dart).
    if [[ -z "$FOUND_TEST" ]] && [[ -d "$MOD_TEST_DIR/presentation" ]]; then
        FOUND_TEST=$(ls "$MOD_TEST_DIR"/presentation/*"$NAME"*_test.dart 2>/dev/null | head -1)
    fi
    if [[ -n "$FOUND_TEST" ]]; then
        check "Test file existe" "true"
    else
        warn "No test file encontrado" \
            "Crear $MOD_TEST_DIR/presentation/${NAME}_form_validation_test.dart (ver DOCUMENT_STANDARDS.md §12)."
    fi

# ---------------------------------------------------------------------------
# Rama React (comportamiento original, sin cambios)
# ---------------------------------------------------------------------------
elif [[ "$EXT" == "tsx" ]] || [[ "$EXT" == "jsx" ]] || [[ "$EXT" == "js" ]] || [[ "$EXT" == "ts" ]]; then

    check "Import React" "grep -q 'import React' \"$FILE\""
    check "Import hooks" "grep -q 'useState\\|useEffect\\|useRef' \"$FILE\""

    if [[ "$EXT" == "tsx" ]] || [[ "$EXT" == "jsx" ]]; then
        check "Export default" "grep -q 'export default' \"$FILE\""
        check "Componente funcional" "grep -q 'function\\|const.*=.*=>' \"$FILE\""
    fi

    # Accesibilidad básica
    check "No divs sin rol en botones" "! grep -q '<div.*onClick' \"$FILE\" || grep -q 'role=\"button\"' \"$FILE\""
    check "Inputs tienen labels" "! grep -q '<input' \"$FILE\" || grep -q 'htmlFor\\|id=' \"$FILE\""
    check "Imágenes tienen alt" "! grep -q '<img' \"$FILE\" || grep -q 'alt=' \"$FILE\""
    check "No color solo para estado" "! grep -q 'color.*red\\|color.*green\\|color.*blue' \"$FILE\" || grep -q 'icon\\|icon:' \"$FILE\""

    # Estados de carga
    check "Loading state presente" "grep -q 'loading\\|Loading\\|skeleton\\|Skeleton' \"$FILE\" || true"
    check "Estados de error" "grep -q 'error\\|Error' \"$FILE\" || true"

    # Responsive
    check "Responsive breakpoints" "grep -q 'xs\\|sm\\|md\\|lg\\|xl' \"$FILE\" || true"

    # Focus visible
    check "Focus visible" "grep -q 'focus-visible\\|focus-visible' \"$FILE\" || grep -q 'outline' \"$FILE\""

    # TypeScript
    if [[ "$EXT" == "tsx" ]]; then
        check "Tipos definidos" "grep -q 'interface\\|type ' \"$FILE\" || true"
        check "Props tipadas" "grep -q 'interface.*Props\\|type.*Props' \"$FILE\" || true"
    fi

    # Tests
    TEST_FILE="${SCREEN_PATH%.*}.test.${EXT}"
    if [[ -f "$TEST_FILE" ]]; then
        check "Test file existe" "[[ -f \"$TEST_FILE\" ]]"
    else
        warn "No test file encontrado" "Crear $TEST_FILE"
    fi

    # Verificar imports de design system
    check "Design system imports" "grep -q '@mui\\|@radix\\|styled-components\\|emotion\\|tailwind' \"$FILE\" || true"

    # Verificar hooks personalizados
    check "Custom hooks" "grep -q 'use[A-Z]' \"$FILE\" || true"

    # Verificar error boundaries
    if grep -q "class.*extends.*Component" "$FILE"; then
        check "Error boundary" "grep -q 'componentDidCatch\\|getDerivedStateFromError' \"$FILE\" || true"
    fi

    # Verificar hooks de accesibilidad
    check "useRef para focus" "grep -q 'useRef' \"$FILE\" || true"
    check "useEffect cleanup" "grep -q 'useEffect.*return.*=>' \"$FILE\" || true"

else
    warn "Extensión '$EXT' sin checks específicos" \
        "Solo se aplicaron los checks comunes de archivo."
fi

# Resumen
echo ""
echo "=================================="
echo -e "Resultados: ${GREEN}$PASS pass${NC}, ${RED}$FAIL fail${NC}, ${YELLOW}$WARN warn${NC}"

if [[ $FAIL -gt 0 ]]; then
    echo -e "${RED}❌ AUDITORÍA FALLÓ${NC}: $FAIL checks fallaron"
    exit 1
elif [[ $WARN -gt 0 ]]; then
    echo -e "${YELLOW}⚠️  AUDITORÍA CON ADVERTENCIAS${NC}: $WARN warnings"
    exit 0
else
    echo -e "${GREEN}✅ AUDITORÍA PASÓ${NC}: Todos los checks OK"
    exit 0
fi
