#!/bin/bash
# Workspace Tools - Setup Script
# Configuración completa del sistema de workspace management
#
# Uso:
#   Añade esto a tu ~/.bashrc o ~/.zshrc:
#   source ~/wrkspc.nubarchiva/tools/workspace-tools/setup.sh

# Detectar directorio del script (compatible con bash y zsh)
if [ -n "$BASH_VERSION" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [ -n "$ZSH_VERSION" ]; then
    # En Zsh, usar la expansión especial para obtener el path del script
    SCRIPT_DIR="${0:A:h}"
else
    # Fallback genérico
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# Exportar WS_TOOLS
export WS_TOOLS="$SCRIPT_DIR"

# Añadir bin/ al PATH si no está ya
if [[ ":$PATH:" != *":$SCRIPT_DIR/bin:"* ]]; then
    export PATH="$SCRIPT_DIR/bin:$PATH"
fi

# Eliminar alias ws si existe (para evitar conflicto con la función)
unalias ws 2>/dev/null || true

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
    # Añadir el directorio de completions al fpath
    fpath=("$SCRIPT_DIR/completions" ${fpath[@]})

    # Asegurarse de que compinit está inicializado (si no lo está ya)
    if ! command -v compdef &> /dev/null; then
        autoload -Uz compinit
        compinit -C  # -C para skip security check (más rápido)
    fi

    # Cargar el completion script (define _ws y ejecuta compdef)
    if [ -f "$SCRIPT_DIR/completions/ws-completion.zsh" ]; then
        source "$SCRIPT_DIR/completions/ws-completion.zsh"
    fi
fi

# Maven shortcuts para workspaces
# Funciones equivalentes a los aliases maven comunes pero a nivel workspace
wmcis() { ws mvn "$1" -T 1C clean install -DskipTests=true -Denforcer.skip=true; }
wmci() { ws mvn "$1" -T 1C clean install; }
wmcl() { ws mvn "$1" -T 1C clean; }

# Git shortcuts para workspaces
wgt() { ws git "$1" status; }
wgpa() { ws git "$1" pull --all; }
