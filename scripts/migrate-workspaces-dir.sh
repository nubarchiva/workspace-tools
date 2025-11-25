#!/bin/bash
# ══════════════════════════════════════════════════════════════
# Migración de directorio de workspaces
# ══════════════════════════════════════════════════════════════
#
# Este script mueve el directorio de workspaces a una nueva ubicación
# y actualiza la configuración de workspace-tools.
#
# Uso:
#   ./migrate-workspaces-dir.sh /nueva/ruta/workspaces
#
# Ejemplo:
#   ./migrate-workspaces-dir.sh ~/workspaces
#
# El script:
#   1. Verifica que no hay cambios sin commitear en ningún workspace
#   2. Mueve el directorio de workspaces
#   3. Repara los worktrees de Git (actualizan las rutas)
#   4. Actualiza ~/.wsrc con la nueva ubicación
#
# ══════════════════════════════════════════════════════════════

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# ══════════════════════════════════════════════════════════════
# Funciones auxiliares
# ══════════════════════════════════════════════════════════════

error() {
    echo -e "${RED}❌ Error: $1${RESET}" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}⚠️  $1${RESET}"
}

success() {
    echo -e "${GREEN}✓ $1${RESET}"
}

info() {
    echo -e "${CYAN}ℹ️  $1${RESET}"
}

# ══════════════════════════════════════════════════════════════
# Verificar argumentos
# ══════════════════════════════════════════════════════════════

if [ $# -ne 1 ]; then
    echo "Uso: $0 <nueva-ruta-workspaces>"
    echo ""
    echo "Ejemplo:"
    echo "  $0 ~/workspaces"
    echo "  $0 /Volumes/SSD/workspaces"
    exit 1
fi

NEW_WORKSPACES_DIR="$1"

# Expandir ~ si existe
NEW_WORKSPACES_DIR="${NEW_WORKSPACES_DIR/#\~/$HOME}"

# Convertir a ruta absoluta
NEW_WORKSPACES_DIR="$(cd "$(dirname "$NEW_WORKSPACES_DIR")" 2>/dev/null && pwd)/$(basename "$NEW_WORKSPACES_DIR")" || {
    # El directorio padre no existe, verificar si podemos crearlo
    PARENT_DIR="$(dirname "$NEW_WORKSPACES_DIR")"
    if [ ! -d "$PARENT_DIR" ]; then
        error "El directorio padre no existe: $PARENT_DIR"
    fi
    NEW_WORKSPACES_DIR="$PARENT_DIR/$(basename "$NEW_WORKSPACES_DIR")"
}

# ══════════════════════════════════════════════════════════════
# Detectar configuración actual
# ══════════════════════════════════════════════════════════════

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Migración de directorio de workspaces"
echo "════════════════════════════════════════════════════════════"
echo ""

# Cargar configuración actual
if [ -f "$HOME/.wsrc" ]; then
    source "$HOME/.wsrc"
fi

# Detectar WORKSPACE_ROOT si no está definido
if [ -z "$WORKSPACE_ROOT" ]; then
    # Intentar detectar desde WS_TOOLS
    if [ -n "$WS_TOOLS" ]; then
        WORKSPACE_ROOT="${WS_TOOLS%/tools/workspace-tools}"
    else
        # Fallback
        WORKSPACE_ROOT="$HOME/wrkspc.nubarchiva"
    fi
fi

# Detectar WORKSPACES_DIR actual
if [ -z "$WORKSPACES_DIR" ]; then
    CURRENT_WORKSPACES_DIR="$WORKSPACE_ROOT/workspaces"
else
    CURRENT_WORKSPACES_DIR="$WORKSPACES_DIR"
fi

echo "Configuración actual:"
echo "  WORKSPACE_ROOT:  $WORKSPACE_ROOT"
echo "  WORKSPACES_DIR:  $CURRENT_WORKSPACES_DIR"
echo ""
echo "Nueva ubicación:"
echo "  WORKSPACES_DIR:  $NEW_WORKSPACES_DIR"
echo ""

# ══════════════════════════════════════════════════════════════
# Verificaciones previas
# ══════════════════════════════════════════════════════════════

# Verificar que el directorio actual existe
if [ ! -d "$CURRENT_WORKSPACES_DIR" ]; then
    error "El directorio de workspaces actual no existe: $CURRENT_WORKSPACES_DIR"
fi

# Verificar que la nueva ubicación no existe o está vacía
if [ -d "$NEW_WORKSPACES_DIR" ]; then
    if [ "$(ls -A "$NEW_WORKSPACES_DIR" 2>/dev/null)" ]; then
        error "La nueva ubicación ya existe y no está vacía: $NEW_WORKSPACES_DIR"
    fi
fi

# Verificar que no es la misma ubicación
if [ "$CURRENT_WORKSPACES_DIR" = "$NEW_WORKSPACES_DIR" ]; then
    error "La nueva ubicación es la misma que la actual"
fi

# ══════════════════════════════════════════════════════════════
# Verificar estado de los workspaces
# ══════════════════════════════════════════════════════════════

echo "Verificando estado de los workspaces..."
echo ""

WORKSPACES_WITH_CHANGES=()
WORKSPACE_COUNT=0

for ws_dir in "$CURRENT_WORKSPACES_DIR"/*/; do
    [ -d "$ws_dir" ] || continue

    ws_name=$(basename "$ws_dir")
    ((WORKSPACE_COUNT++))

    # Buscar repos en el workspace
    for repo_dir in "$ws_dir"/*/ "$ws_dir"/*/*/; do
        [ -d "$repo_dir/.git" ] || continue

        # Verificar cambios sin commitear
        if [ -n "$(git -C "$repo_dir" status --porcelain 2>/dev/null)" ]; then
            WORKSPACES_WITH_CHANGES+=("$ws_name: $(basename "$repo_dir")")
        fi
    done
done

if [ ${#WORKSPACES_WITH_CHANGES[@]} -gt 0 ]; then
    echo -e "${RED}════════════════════════════════════════════════════════════${RESET}"
    echo -e "${RED}  ❌ Hay workspaces con cambios sin commitear${RESET}"
    echo -e "${RED}════════════════════════════════════════════════════════════${RESET}"
    echo ""
    echo "Los siguientes repos tienen cambios pendientes:"
    for change in "${WORKSPACES_WITH_CHANGES[@]}"; do
        echo "  • $change"
    done
    echo ""
    echo "Por seguridad, haz commit o stash de los cambios antes de migrar."
    echo ""
    exit 1
fi

success "Verificados $WORKSPACE_COUNT workspaces - ninguno tiene cambios pendientes"
echo ""

# ══════════════════════════════════════════════════════════════
# Confirmación
# ══════════════════════════════════════════════════════════════

echo "Se realizarán las siguientes acciones:"
echo ""
echo "  1. Mover directorio:"
echo "     $CURRENT_WORKSPACES_DIR"
echo "     → $NEW_WORKSPACES_DIR"
echo ""
echo "  2. Reparar worktrees de Git (actualizar rutas)"
echo ""
echo "  3. Actualizar ~/.wsrc con:"
echo "     WORKSPACES_DIR=\"$NEW_WORKSPACES_DIR\""
echo ""

read -p "¿Continuar? (s/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Migración cancelada"
    exit 0
fi

echo ""

# ══════════════════════════════════════════════════════════════
# Ejecutar migración
# ══════════════════════════════════════════════════════════════

# Paso 1: Mover directorio
info "Moviendo directorio de workspaces..."

# Crear directorio padre si no existe
mkdir -p "$(dirname "$NEW_WORKSPACES_DIR")"

# Mover
mv "$CURRENT_WORKSPACES_DIR" "$NEW_WORKSPACES_DIR"
success "Directorio movido"

# Paso 2: Reparar worktrees
info "Reparando worktrees de Git..."

REPOS_REPAIRED=0
for ws_dir in "$NEW_WORKSPACES_DIR"/*/; do
    [ -d "$ws_dir" ] || continue

    ws_name=$(basename "$ws_dir")

    # Buscar repos en el workspace
    for repo_dir in "$ws_dir"/*/ "$ws_dir"/*/*/; do
        [ -d "$repo_dir/.git" ] || continue

        # Obtener el repo principal desde el worktree
        git_dir=$(git -C "$repo_dir" rev-parse --git-dir 2>/dev/null)
        if [ -n "$git_dir" ]; then
            # El git-dir apunta al .git del repo principal
            main_repo=$(dirname "$git_dir")
            main_repo=$(dirname "$main_repo")  # subir de .git/worktrees/xxx
            main_repo=$(dirname "$main_repo")  # subir de .git/worktrees
            main_repo=$(dirname "$main_repo")  # subir de .git

            if [ -d "$main_repo/.git" ]; then
                git -C "$main_repo" worktree repair 2>/dev/null && ((REPOS_REPAIRED++))
            fi
        fi
    done
done

success "Reparados worktrees ($REPOS_REPAIRED repos)"

# Paso 3: Actualizar ~/.wsrc
info "Actualizando ~/.wsrc..."

WSRC_FILE="$HOME/.wsrc"

if [ -f "$WSRC_FILE" ]; then
    # Hacer backup
    cp "$WSRC_FILE" "$WSRC_FILE.bak"

    # Actualizar o añadir WORKSPACES_DIR
    if grep -q "^WORKSPACES_DIR=" "$WSRC_FILE"; then
        # Reemplazar línea existente
        sed -i.tmp "s|^WORKSPACES_DIR=.*|WORKSPACES_DIR=\"$NEW_WORKSPACES_DIR\"|" "$WSRC_FILE"
        rm -f "$WSRC_FILE.tmp"
    else
        # Añadir nueva línea
        echo "" >> "$WSRC_FILE"
        echo "# Directorio de workspaces (migrado $(date +%Y-%m-%d))" >> "$WSRC_FILE"
        echo "WORKSPACES_DIR=\"$NEW_WORKSPACES_DIR\"" >> "$WSRC_FILE"
    fi
    success "Actualizado ~/.wsrc (backup en ~/.wsrc.bak)"
else
    # Crear nuevo archivo
    cat > "$WSRC_FILE" << EOF
# Configuración de workspace-tools
# Generado por migrate-workspaces-dir.sh ($(date +%Y-%m-%d))

# Directorio raíz donde están los repos
WORKSPACE_ROOT="$WORKSPACE_ROOT"

# Directorio de workspaces
WORKSPACES_DIR="$NEW_WORKSPACES_DIR"
EOF
    success "Creado ~/.wsrc"
fi

# ══════════════════════════════════════════════════════════════
# Finalización
# ══════════════════════════════════════════════════════════════

echo ""
echo "════════════════════════════════════════════════════════════"
echo -e "  ${GREEN}✓ Migración completada${RESET}"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Nueva ubicación de workspaces:"
echo "  $NEW_WORKSPACES_DIR"
echo ""
echo "Siguiente paso:"
echo "  Recarga tu shell para aplicar los cambios:"
echo ""
echo "    source ~/.bashrc   # o ~/.zshrc"
echo ""
echo "Verificación:"
echo "  ws list"
echo ""
