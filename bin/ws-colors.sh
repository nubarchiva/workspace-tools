#!/bin/bash
# Sistema de colores para Workspace Tools
# Proporciona funciones y variables para output coloreado elegante

# Detectar si el terminal soporta colores
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    # Terminal con soporte de colores
    COLOR_RESET=$(tput sgr0)
    COLOR_BOLD=$(tput bold)
    COLOR_DIM=$(tput dim 2>/dev/null || echo "")

    # Colores básicos
    COLOR_RED=$(tput setaf 1)
    COLOR_GREEN=$(tput setaf 2)
    COLOR_YELLOW=$(tput setaf 3)
    COLOR_BLUE=$(tput setaf 4)
    COLOR_MAGENTA=$(tput setaf 5)
    COLOR_CYAN=$(tput setaf 6)
    COLOR_WHITE=$(tput setaf 7)

    # Combinaciones útiles
    COLOR_BOLD_CYAN="${COLOR_BOLD}${COLOR_CYAN}"
    COLOR_BOLD_GREEN="${COLOR_BOLD}${COLOR_GREEN}"
    COLOR_BOLD_RED="${COLOR_BOLD}${COLOR_RED}"
    COLOR_BOLD_YELLOW="${COLOR_BOLD}${COLOR_YELLOW}"
else
    # Terminal sin colores - usar strings vacíos
    COLOR_RESET=""
    COLOR_BOLD=""
    COLOR_DIM=""
    COLOR_RED=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_BLUE=""
    COLOR_MAGENTA=""
    COLOR_CYAN=""
    COLOR_WHITE=""
    COLOR_BOLD_CYAN=""
    COLOR_BOLD_GREEN=""
    COLOR_BOLD_RED=""
    COLOR_BOLD_YELLOW=""
fi

# Funciones de utilidad para mensajes coloreados

# Mensajes de éxito (verde)
success() {
    echo "${COLOR_GREEN}$*${COLOR_RESET}"
}

# Mensajes de error (rojo)
error() {
    echo "${COLOR_RED}$*${COLOR_RESET}"
}

# Mensajes de advertencia (amarillo)
warning() {
    echo "${COLOR_YELLOW}$*${COLOR_RESET}"
}

# Mensajes de información (cyan)
info() {
    echo "${COLOR_CYAN}$*${COLOR_RESET}"
}

# Títulos/headers (bold cyan)
header() {
    echo "${COLOR_BOLD_CYAN}$*${COLOR_RESET}"
}

# Texto secundario (dim)
secondary() {
    echo "${COLOR_DIM}$*${COLOR_RESET}"
}

# Destacar nombres (bold)
highlight() {
    echo "${COLOR_BOLD}$*${COLOR_RESET}"
}

# Header simple y elegante (usado en varios scripts)
print_header() {
    local title="$1"
    local title_clean
    # Eliminar códigos de color para calcular longitud real
    title_clean=$(echo "$title" | sed 's/\x1b\[[0-9;]*m//g')
    local len=${#title_clean}
    local line=""

    # Crear línea del tamaño exacto del título + 4 (espacios y bordes)
    for ((i=0; i<len+4; i++)); do
        line="${line}─"
    done

    echo ""
    echo "${COLOR_DIM}${line}${COLOR_RESET}"
    echo "${COLOR_BOLD_CYAN}  $title${COLOR_RESET}"
    echo "${COLOR_DIM}${line}${COLOR_RESET}"
}

# Separador de secciones
print_separator() {
    echo "${COLOR_BOLD}════════════════════════════════════════════════════${COLOR_RESET}"
}

# Separador con título
print_separator_with_title() {
    local title="$1"
    echo "${COLOR_BOLD}════════════════════════════════════════════════════${COLOR_RESET}"
    echo "${COLOR_BOLD}▶ $title${COLOR_RESET}"
    echo "${COLOR_BOLD}════════════════════════════════════════════════════${COLOR_RESET}"
}
