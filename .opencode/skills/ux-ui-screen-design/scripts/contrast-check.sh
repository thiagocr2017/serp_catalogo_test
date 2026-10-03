#!/bin/bash

# contrast-check.sh - Verificador de contraste WCAG 2.1
# Uso: ./contrast-check.sh --fg "#1976D2" --bg "#FFFFFF"
#      ./contrast-check.sh --fg "#1976D2" --bg "#FFFFFF" --level AA --size normal

set -e

FG_COLOR=""
BG_COLOR=""
LEVEL="AA"
SIZE="normal"

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --fg)
            FG_COLOR="$2"
            shift 2
            ;;
        --bg)
            BG_COLOR="$2"
            shift 2
            ;;
        --level)
            LEVEL="$2"
            shift 2
            ;;
        --size)
            SIZE="$2"
            shift 2
            ;;
        *)
            echo "Uso: $0 --fg <color> --bg <color> [--level AA|AAA] [--size normal|large]"
            echo "Ejemplo: $0 --fg \"#1976D2\" --bg \"#FFFFFF\" --level AA --size normal"
            exit 1
            ;;
    esac
done

if [[ -z "$FG_COLOR" ]] || [[ -z "$BG_COLOR" ]]; then
    echo "Error: --fg y --bg son requeridos"
    echo "Uso: $0 --fg <color> --bg <color> [--level AA|AAA] [--size normal|large]"
    exit 1
fi

# Normalizar color (quitar # si existe)
FG_COLOR="${FG_COLOR#\#}"
BG_COLOR="${BG_COLOR#\#}"

# Validar formato hex (3, 6 u 8 chars)
validate_hex() {
    local color="$1"
    if [[ ! "$color" =~ ^([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$ ]]; then
        echo "Error: Color inválido. Use formato hex (3, 6 u 8 dígitos): #RRGGBB o #RRGGBBAA"
        exit 1
    fi
}

validate_hex "$FG_COLOR"
validate_hex "$BG_COLOR"

# Normalizar a 6 dígitos (expandir 3 dígitos)
normalize_hex() {
    local color="$1"
    if [[ ${#color} -eq 3 ]]; then
        echo "${color:0:1}${color:0:1}${color:1:1}${color:1:1}${color:2:2}${color:2:2}"
    elif [[ ${#color} -eq 8 ]]; then
        # Ignorar alpha, tomar solo RGB
        echo "${color:0:6}"
    else
        echo "$color"
    fi
}

FG_RGB=$(normalize_hex "$FG_COLOR")
BG_RGB=$(normalize_hex "$BG_COLOR")

# Convertir hex a RGB decimal
hex_to_rgb() {
    local hex="$1"
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    echo "$r $g $b"
}

FG_R=$(echo $(hex_to_rgb "$FG_RGB") | cut -d' ' -f1)
FG_G=$(echo $(hex_to_rgb "$FG_RGB") | cut -d' ' -f2)
FG_B=$(echo $(hex_to_rgb "$FG_RGB") | cut -d' ' -f3)

BG_R=$(echo $(hex_to_rgb "$BG_RGB") | cut -d' ' -f1)
BG_G=$(echo $(hex_to_rgb "$BG_RGB") | cut -d' ' -f2)
BG_B=$(echo $(hex_to_rgb "$BG_RGB") | cut -d' ' -f3)

# Convertir sRGB a lineal
srgb_to_linear() {
    local c=$1
    local c_norm=$(echo "scale=6; $c / 255" | bc -l)
    if (( $(echo "$c_norm <= 0.03928" | bc -l) )); then
        echo "scale=6; $c_norm / 12.92" | bc -l
    else
        echo "scale=6; e( l( ($c_norm + 0.055) / 1.055 ) * 2.4 )" | bc -l
    fi
}

# Luminancia relativa
luminance() {
    local r=$1
    local g=$2
    local b=$3
    
    local r_lin=$(srgb_to_linear $r)
    local g_lin=$(srgb_to_linear $g)
    local b_lin=$(srgb_to_linear $b)
    
    # L = 0.2126 * R + 0.7152 * G + 0.0722 * B
    echo "scale=6; 0.2126 * $r_lin + 0.7152 * $g_lin + 0.0722 * $b_lin" | bc -l
}

# Calcular luminancias
FG_LUM=$(luminance $FG_R $FG_G $FG_B)
BG_LUM=$(luminance $BG_R $BG_G $BG_B)

# Ratio de contraste
# (L1 + 0.05) / (L2 + 0.05) donde L1 es el más claro
if (( $(echo "$FG_LUM > $BG_LUM" | bc -l) )); then
    LIGHTER=$FG_LUM
    DARKER=$BG_LUM
else
    LIGHTER=$BG_LUM
    DARKER=$FG_LUM
fi

CONTRAST=$(echo "scale=2; ($LIGHTER + 0.05) / ($DARKER + 0.05)" | bc -l)

# Determinar umbrales según nivel y tamaño
get_threshold() {
    local level="$1"
    local size="$2"
    
    if [[ "$level" == "AAA" ]]; then
        if [[ "$size" == "large" ]]; then
            echo "4.5"
        else
            echo "7"
        fi
    else
        # AA
        if [[ "$size" == "large" ]]; then
            echo "3"
        else
            echo "4.5"
        fi
    fi
}

THRESHOLD=$(get_threshold "$LEVEL" "$SIZE")

# Formatear ratio para mostrar
CONTRAST_FMT=$(printf "%.2f" "$CONTRAST")
THRESHOLD_FMT=$(printf "%.1f" "$THRESHOLD")

# Determinar si pasa
PASSES=$(echo "$CONTRAST >= $THRESHOLD" | bc -l)

# Output
echo "=================================="
echo "   Verificador Contraste WCAG 2.1"
echo "=================================="
echo ""
echo "Color Frente:  #$FG_RGB"
echo "Color Fondo:   #$BG_RGB"
echo "Nivel WCAG:    $LEVEL"
echo "Tamaño texto:  $SIZE"
echo ""
echo "Luminancia frente:  $FG_LUM"
echo "Luminancia fondo:   $BG_LUM"
echo ""
echo "Ratio contraste:    $CONTRAST_FMT:1"
echo "Umbral requerido:   $THRESHOLD_FMT:1 (WCAG 2.1 $LEVEL, texto $SIZE)"
echo ""

if [[ "$PASSES" -eq 1 ]]; then
    echo -e "\033[0;32m✅ PASA\033[0m: El contraste cumple WCAG 2.1 $LEVEL para texto $SIZE"
    EXIT_CODE=0
else
    echo -e "\033[0;31m❌ FALLA\033[0m: El contraste NO cumple WCAG 2.1 $LEVEL para texto $SIZE"
    echo ""
    echo "Sugerencias:"
    echo "  - Aclarar color frente o oscurecer fondo"
    echo "  - Usar colores del design system semántico"
    echo "  - Verificar en modo dark/light"
    EXIT_CODE=1
fi

echo ""

# Info adicional
echo "Referencia WCAG 2.1:"
echo "  AA normal:    4.5:1"
echo "  AA large:     3:1"
echo "  AAA normal:   7:1"
echo "  AAA large:    4.5:1"
echo ""
echo "Large text = ≥18pt (24px) o ≥14pt bold (18.5px)"

exit $EXIT_CODE