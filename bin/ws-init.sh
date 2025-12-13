#!/bin/bash
# =============================================================================
# ws-init.sh - Inicializacion centralizada para workspace-tools
# =============================================================================
#
# Este script centraliza toda la logica de inicializacion que antes se repetia
# en cada script. Debe ser sourced al inicio de cada comando ws-*.
#
# Uso en scripts:
#   #!/bin/bash
#   source "$(dirname "${BASH_SOURCE[0]:-$0}")/ws-init.sh"
#
# Variables exportadas:
#   WORKSPACE_ROOT   - Directorio raiz (donde estan los repos)
#   WORKSPACES_DIR   - Directorio de workspaces ($WORKSPACE_ROOT/workspaces)
#   SCRIPT_DIR       - Directorio donde esta el script actual
#   WS_TOOLS         - Directorio de workspace-tools
#
# Funciones cargadas:
#   - Todas las de ws-common.sh (find_matching_workspace, get_branch_name, etc.)
#   - Todas las de ws-colors.sh (success, error, warning, info, etc.)
#   - Funciones adicionales: die, warn, debug
#
# =============================================================================

# Evitar doble carga
[[ -n "$_WS_INIT_LOADED" ]] && return 0
_WS_INIT_LOADED=1

# -----------------------------------------------------------------------------
# Detectar directorios
# -----------------------------------------------------------------------------

# Directorio del script que hizo source (compatible bash/zsh)
if [[ -n "$BASH_VERSION" ]]; then
    # En bash, BASH_SOURCE[0] es ws-init.sh, BASH_SOURCE[1] es quien lo llamo
    if [[ -n "${BASH_SOURCE[1]:-}" ]]; then
        _WS_CALLER_SCRIPT="${BASH_SOURCE[1]}"
    else
        _WS_CALLER_SCRIPT="${BASH_SOURCE[0]}"
    fi
    SCRIPT_DIR="$(cd "$(dirname "$_WS_CALLER_SCRIPT")" && pwd)"
    _WS_INIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [[ -n "$ZSH_VERSION" ]]; then
    # En zsh, funcfiletrace tiene la pila de llamadas
    _WS_CALLER_SCRIPT="${funcfiletrace[1]%:*}"
    if [[ -z "$_WS_CALLER_SCRIPT" ]]; then
        _WS_CALLER_SCRIPT="${(%):-%x}"
    fi
    SCRIPT_DIR="$(cd "$(dirname "$_WS_CALLER_SCRIPT")" && pwd)"
    _WS_INIT_DIR="${0:A:h}"
else
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    _WS_INIT_DIR="$SCRIPT_DIR"
fi

# WS_TOOLS es el directorio padre de bin/
if [[ -z "$WS_TOOLS" ]]; then
    WS_TOOLS="$(cd "$_WS_INIT_DIR/.." && pwd)"
fi
export WS_TOOLS

# -----------------------------------------------------------------------------
# Cargar configuracion de usuario (si existe)
# -----------------------------------------------------------------------------

_WS_CONFIG_FILE="${WS_CONFIG_FILE:-$HOME/.wsrc}"
if [[ -f "$_WS_CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$_WS_CONFIG_FILE"
fi

# -----------------------------------------------------------------------------
# Determinar WORKSPACE_ROOT
# -----------------------------------------------------------------------------
# Prioridad:
#   1. Variable WORKSPACE_ROOT ya definida (por entorno o .wsrc)
#   2. Derivar de WS_TOOLS (asume estructura tools/workspace-tools)
#   3. Fallback configurable via WS_DEFAULT_ROOT
#   4. Fallback final: ~/projects

if [[ -z "$WORKSPACE_ROOT" ]]; then
    if [[ -n "$WS_TOOLS" && "$WS_TOOLS" == */tools/workspace-tools ]]; then
        WORKSPACE_ROOT="${WS_TOOLS%/tools/workspace-tools}"
    elif [[ -n "$WS_DEFAULT_ROOT" ]]; then
        WORKSPACE_ROOT="$WS_DEFAULT_ROOT"
    else
        WORKSPACE_ROOT="$HOME/projects"
    fi
fi
export WORKSPACE_ROOT

# Directorio de workspaces
if [[ -z "$WORKSPACES_DIR" ]]; then
    WORKSPACES_DIR="$WORKSPACE_ROOT/workspaces"
fi
export WORKSPACES_DIR

# -----------------------------------------------------------------------------
# Cargar modulos
# -----------------------------------------------------------------------------

# Cargar colores primero (otros modulos pueden usarlos)
if [[ -f "$_WS_INIT_DIR/ws-colors.sh" ]]; then
    # shellcheck source=/dev/null
    source "$_WS_INIT_DIR/ws-colors.sh"
fi

# Cargar funciones comunes
if [[ -f "$_WS_INIT_DIR/ws-common.sh" ]]; then
    # shellcheck source=/dev/null
    source "$_WS_INIT_DIR/ws-common.sh"
fi

# Cargar utilidades Git
if [[ -f "$_WS_INIT_DIR/ws-git-utils.sh" ]]; then
    # shellcheck source=/dev/null
    source "$_WS_INIT_DIR/ws-git-utils.sh"
fi

# -----------------------------------------------------------------------------
# Funciones de utilidad adicionales
# -----------------------------------------------------------------------------

# Terminar con error
die() {
    error "❌ $*"
    exit 1
}

# Warning (no termina)
warn() {
    warning "⚠️  $*"
}

# Debug (solo si WS_DEBUG=1)
debug() {
    [[ -n "$WS_DEBUG" ]] && echo "[DEBUG] $*" >&2
}

# Verificar que un comando existe
require_command() {
    local cmd="$1"
    local msg="${2:-}"
    if ! command -v "$cmd" &> /dev/null; then
        if [[ -n "$msg" ]]; then
            die "$msg"
        else
            die "Comando requerido no encontrado: $cmd"
        fi
    fi
}

# Verificar que estamos en un directorio git
require_git_repo() {
    if ! git rev-parse --git-dir &> /dev/null; then
        die "No estamos en un repositorio Git"
    fi
}

# -----------------------------------------------------------------------------
# Funciones de resolución de workspace
# -----------------------------------------------------------------------------

# Verifica si un string coincide parcialmente con algún workspace existente
# Uso: if is_workspace_pattern "8400"; then echo "es workspace"; fi
# Retorna: 0 si coincide, 1 si no
is_workspace_pattern() {
    local pattern="$1"
    local pattern_lower
    pattern_lower=$(echo "$pattern" | tr '[:upper:]' '[:lower:]')

    if [[ ! -d "$WORKSPACES_DIR" ]]; then
        return 1
    fi

    for ws_dir in "$WORKSPACES_DIR"/*; do
        if [[ -d "$ws_dir" ]]; then
            local ws_name ws_name_lower
            ws_name=$(basename "$ws_dir")
            ws_name_lower=$(echo "$ws_name" | tr '[:upper:]' '[:lower:]')
            if [[ "$ws_name_lower" == *"$pattern_lower"* ]]; then
                return 0
            fi
        fi
    done

    return 1
}

# Resuelve un patrón de workspace y define WORKSPACE_NAME y WORKSPACE_DIR
# Si no hay patrón, intenta auto-detectar
# Uso: resolve_workspace "$WORKSPACE_PATTERN" "ws stash <workspace>"
#      resolve_workspace "" "ws stash <workspace>"  # auto-detecta
# Resultado: WORKSPACE_NAME y WORKSPACE_DIR definidos, o exit 1 si falla
resolve_workspace() {
    local pattern="$1"
    local usage_hint="${2:-ws <comando> <workspace>}"

    if [[ -n "$pattern" ]]; then
        WORKSPACE_NAME=$(find_matching_workspace "$pattern" "$WORKSPACES_DIR")
        if [[ $? -ne 0 ]]; then
            exit 1
        fi
    else
        WORKSPACE_NAME=$(detect_current_workspace)
        if [[ -z "$WORKSPACE_NAME" ]]; then
            error "❌ No se especificó workspace y no se pudo detectar automáticamente"
            echo ""
            info "💡 Ejecuta desde dentro de un workspace o especifica el nombre:"
            echo "   $usage_hint"
            exit 1
        fi
        info "🔍 Workspace detectado: $WORKSPACE_NAME"
    fi

    WORKSPACE_DIR="$WORKSPACES_DIR/$WORKSPACE_NAME"
    if [[ ! -d "$WORKSPACE_DIR" ]]; then
        die "Workspace no existe: $WORKSPACE_NAME"
    fi
}

# -----------------------------------------------------------------------------
# Debug info (si WS_DEBUG=1)
# -----------------------------------------------------------------------------

debug "ws-init.sh cargado"
debug "  WORKSPACE_ROOT=$WORKSPACE_ROOT"
debug "  WORKSPACES_DIR=$WORKSPACES_DIR"
debug "  WS_TOOLS=$WS_TOOLS"
debug "  SCRIPT_DIR=$SCRIPT_DIR"
