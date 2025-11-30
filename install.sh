#!/bin/bash
# Script de instalación para workspace-tools
#
# Uso:
#   ./install.sh              # Instalación interactiva
#   ./install.sh --help       # Mostrar ayuda

set -e

# Colores (si el terminal los soporta)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' BOLD='' RESET=''
fi

# Directorio donde está este script (donde se clonó workspace-tools)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ══════════════════════════════════════════════════════════════
# Funciones de ayuda
# ══════════════════════════════════════════════════════════════

show_help() {
    cat << 'EOF'
Workspace Tools - Instalador

Uso:
  ./install.sh              Instalación interactiva
  ./install.sh --help       Mostrar esta ayuda

El instalador:
  1. Verifica requisitos del sistema (Bash 4+, Git 2.15+)
  2. Configura permisos de ejecución
  3. Te pregunta dónde está tu proyecto (WORKSPACE_ROOT)
  4. Crea/actualiza ~/.wsrc con la configuración
  5. Muestra instrucciones para configurar tu shell

Después de instalar, añade a tu ~/.bashrc o ~/.zshrc:
  source /ruta/a/workspace-tools/setup.sh

Para más información: https://github.com/nubarchiva/workspace-tools
EOF
    exit 0
}

# ══════════════════════════════════════════════════════════════
# Verificación de requisitos
# ══════════════════════════════════════════════════════════════

check_bash_version() {
    local bash_path
    local bash_version
    local bash_major

    if command -v bash &> /dev/null; then
        bash_path=$(command -v bash)
        bash_version=$(bash --version | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
        bash_major=${bash_version%%.*}

        if [[ $bash_major -ge 4 ]]; then
            echo -e "   ${GREEN}✓${RESET} Bash $bash_version ($bash_path)"
            return 0
        else
            echo -e "   ${RED}✗${RESET} Bash $bash_version - Se requiere 4.0+"
            echo -e "     ${YELLOW}En macOS: brew install bash${RESET}"
            return 1
        fi
    else
        echo -e "   ${RED}✗${RESET} Bash no encontrado"
        return 1
    fi
}

check_git_version() {
    local git_version
    local git_major
    local git_minor

    if command -v git &> /dev/null; then
        git_version=$(git --version | grep -oE '[0-9]+\.[0-9]+' | head -n1)
        git_major=${git_version%%.*}
        git_minor=${git_version#*.}

        if [[ $git_major -gt 2 ]] || [[ $git_major -eq 2 && $git_minor -ge 15 ]]; then
            echo -e "   ${GREEN}✓${RESET} Git $git_version"
            return 0
        else
            echo -e "   ${RED}✗${RESET} Git $git_version - Se requiere 2.15+"
            echo -e "     ${YELLOW}Git worktrees requieren Git 2.15+${RESET}"
            return 1
        fi
    else
        echo -e "   ${RED}✗${RESET} Git no encontrado"
        return 1
    fi
}

check_user_shell() {
    local user_shell=$(basename "$SHELL")
    local shell_version
    local major

    case "$user_shell" in
        bash)
            shell_version=$(bash --version | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
            major=${shell_version%%.*}
            if [[ $major -ge 4 ]]; then
                echo -e "   ${GREEN}✓${RESET} Shell: Bash $shell_version"
            else
                echo -e "   ${YELLOW}⚠${RESET} Shell: Bash $shell_version (4.0+ recomendado)"
            fi
            ;;
        zsh)
            shell_version=$(zsh --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -n1)
            major=${shell_version%%.*}
            if [[ $major -ge 5 ]]; then
                echo -e "   ${GREEN}✓${RESET} Shell: Zsh $shell_version"
            else
                echo -e "   ${YELLOW}⚠${RESET} Shell: Zsh $shell_version (5.0+ recomendado)"
            fi
            ;;
        *)
            echo -e "   ${YELLOW}⚠${RESET} Shell: $user_shell (bash/zsh recomendado)"
            ;;
    esac
}

# ══════════════════════════════════════════════════════════════
# Configuración
# ══════════════════════════════════════════════════════════════

configure_workspace_root() {
    local wsrc_file="$HOME/.wsrc"
    local current_root=""
    local default_suggestion=""

    # Leer configuración existente si existe
    if [[ -f "$wsrc_file" ]]; then
        current_root=$(grep -E "^WORKSPACE_ROOT=" "$wsrc_file" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'" || true)
        # Expandir ~ si está presente
        current_root="${current_root/#\~/$HOME}"
    fi

    # Determinar sugerencia por defecto
    if [[ -n "$current_root" && -d "$current_root" ]]; then
        default_suggestion="$current_root"
        echo ""
        echo -e "   ${CYAN}Configuración existente detectada:${RESET}"
        echo -e "   WORKSPACE_ROOT = $current_root"
    else
        # Sugerir un directorio común
        default_suggestion="$HOME/projects"
    fi

    echo ""
    echo -e "${BOLD}¿Dónde está el proyecto que quieres gestionar?${RESET}"
    echo ""
    echo "   WORKSPACE_ROOT es el directorio raíz donde están tus repositorios."
    echo "   Ejemplo de estructura:"
    echo ""
    echo "   ~/projects/mi-proyecto/     ← WORKSPACE_ROOT"
    echo "   ├── app/                    (repo)"
    echo "   ├── libs/common/            (repo)"
    echo "   └── workspaces/             (creado automáticamente)"
    echo ""

    read -p "   Ruta [$default_suggestion]: " user_input

    # Usar default si está vacío
    local workspace_root="${user_input:-$default_suggestion}"

    # Expandir ~
    workspace_root="${workspace_root/#\~/$HOME}"

    # Validar que existe o preguntar si crear
    if [[ ! -d "$workspace_root" ]]; then
        echo ""
        read -p "   El directorio no existe. ¿Crearlo? (s/n) [s]: " create_dir
        create_dir="${create_dir:-s}"

        if [[ "$create_dir" =~ ^[Ss]$ ]]; then
            mkdir -p "$workspace_root"
            echo -e "   ${GREEN}✓${RESET} Directorio creado: $workspace_root"
        else
            echo -e "   ${YELLOW}⚠${RESET} Deberás crear el directorio manualmente"
        fi
    fi

    # Guardar en ~/.wsrc
    echo ""
    echo "Guardando configuración en ~/.wsrc..."

    # Crear o actualizar ~/.wsrc
    if [[ -f "$wsrc_file" ]]; then
        # Actualizar WORKSPACE_ROOT existente o añadirlo
        if grep -q "^WORKSPACE_ROOT=" "$wsrc_file" 2>/dev/null; then
            # Usar sed compatible con macOS y Linux
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|^WORKSPACE_ROOT=.*|WORKSPACE_ROOT=\"$workspace_root\"|" "$wsrc_file"
            else
                sed -i "s|^WORKSPACE_ROOT=.*|WORKSPACE_ROOT=\"$workspace_root\"|" "$wsrc_file"
            fi
        else
            echo "WORKSPACE_ROOT=\"$workspace_root\"" >> "$wsrc_file"
        fi
    else
        cat > "$wsrc_file" << EOF
# Workspace Tools - Configuración
# Generado por install.sh

# Directorio raíz donde están tus repositorios
WORKSPACE_ROOT="$workspace_root"

# Directorio donde se crean los workspaces (opcional)
# WORKSPACES_DIR="\$WORKSPACE_ROOT/workspaces"

# Modo debug (opcional)
# WS_DEBUG=1
EOF
    fi

    echo -e "${GREEN}✓${RESET} Configuración guardada en ~/.wsrc"

    # Guardar para uso posterior en el script
    CONFIGURED_WORKSPACE_ROOT="$workspace_root"
}

# ══════════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════════

# Procesar argumentos
case "${1:-}" in
    --help|-h|help)
        show_help
        ;;
esac

# Header
echo ""
echo -e "${BOLD}════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  Workspace Tools - Instalación${RESET}"
echo -e "${BOLD}════════════════════════════════════════════════════${RESET}"
echo ""

# 1. Verificar requisitos
echo -e "${BOLD}1. Verificando requisitos del sistema...${RESET}"
echo ""

REQUIREMENTS_MET=true

if ! check_bash_version; then
    REQUIREMENTS_MET=false
fi

if ! check_git_version; then
    REQUIREMENTS_MET=false
fi

check_user_shell

echo ""

if [[ "$REQUIREMENTS_MET" != "true" ]]; then
    echo -e "${RED}════════════════════════════════════════════════════${RESET}"
    echo -e "${RED}  ✗ Requisitos no cumplidos${RESET}"
    echo -e "${RED}════════════════════════════════════════════════════${RESET}"
    echo ""
    echo "Por favor, instala las versiones requeridas antes de continuar."
    exit 1
fi

echo -e "${GREEN}✓ Requisitos verificados${RESET}"

# 2. Configurar permisos
echo ""
echo -e "${BOLD}2. Configurando permisos...${RESET}"
echo ""

chmod +x "$SCRIPT_DIR/bin/"* 2>/dev/null || true
echo -e "   ${GREEN}✓${RESET} Scripts en $SCRIPT_DIR/bin/"

# 3. Configurar WORKSPACE_ROOT
echo ""
echo -e "${BOLD}3. Configurando proyecto...${RESET}"

configure_workspace_root

# 4. Instrucciones finales
echo ""
echo -e "${BOLD}════════════════════════════════════════════════════${RESET}"
echo -e "${GREEN}  ✓ Instalación completada${RESET}"
echo -e "${BOLD}════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${BOLD}Siguiente paso:${RESET}"
echo ""
echo "   Añade esta línea a tu ~/.bashrc o ~/.zshrc:"
echo ""
echo -e "   ${CYAN}source $SCRIPT_DIR/setup.sh${RESET}"
echo ""
echo "   Luego recarga tu shell:"
echo ""
echo -e "   ${CYAN}source ~/.bashrc${RESET}  (o ~/.zshrc)"
echo ""
echo -e "${BOLD}Primeros comandos:${RESET}"
echo ""
echo "   ws --help                    # Ver ayuda"
echo "   ws new feature-1 app lib     # Crear workspace"
echo "   ws list                      # Listar workspaces"
echo "   ws cd feature-1              # Cambiar a workspace"
echo ""
echo -e "${BOLD}Documentación:${RESET}"
echo ""
echo "   README.md      - Introducción y uso rápido"
echo "   USER_GUIDE.md  - Referencia completa"
echo ""
