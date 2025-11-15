#!/bin/bash
# Workspace Tools - Setup Script
# Configuración completa del sistema de workspace management
#
# Uso:
#   Añade esto a tu ~/.bashrc o ~/.zshrc:
#   source ~/wrkspc.nubarchiva/tools/workspace-tools/setup.sh

# Detectar directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Exportar WS_TOOLS
export WS_TOOLS="$SCRIPT_DIR"

# Añadir bin/ al PATH si no está ya
if [[ ":$PATH:" != *":$SCRIPT_DIR/bin:"* ]]; then
    export PATH="$SCRIPT_DIR/bin:$PATH"
fi

# Cargar la función ws() (permite 'ws cd' para cambiar de directorio)
if [ -f "$SCRIPT_DIR/completions/ws-function.sh" ]; then
    source "$SCRIPT_DIR/completions/ws-function.sh"
fi

# Cargar autocompletado según el shell
if [ -n "$BASH_VERSION" ]; then
    # Estamos en Bash
    if [ -f "$SCRIPT_DIR/completions/ws-completion.bash" ]; then
        source "$SCRIPT_DIR/completions/ws-completion.bash"
    fi
elif [ -n "$ZSH_VERSION" ]; then
    # Estamos en Zsh
    if [ -f "$SCRIPT_DIR/completions/ws-completion.zsh" ]; then
        source "$SCRIPT_DIR/completions/ws-completion.zsh"
    fi
fi
