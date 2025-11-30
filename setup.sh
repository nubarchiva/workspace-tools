#!/bin/bash
# Workspace Tools - Setup Script
# Configuración completa del sistema de workspace management
#
# Uso:
#   Añade esto a tu ~/.bashrc o ~/.zshrc:
#   source ~/projects/tools/workspace-tools/setup.sh
#
# Requisitos:
#   - Bash 4.0+ o Zsh 5.0+ (para este script)
#   - Bash 4.0+ instalado en el sistema (para los scripts en bin/)
#   - Git 2.15+ (para worktrees)

# ══════════════════════════════════════════════════════════════
# Verificación de versión del shell
# ══════════════════════════════════════════════════════════════

_ws_check_shell_version() {
    local shell_ok=true

    if [ -n "$BASH_VERSION" ]; then
        # Verificar Bash >= 4.0
        local bash_major=${BASH_VERSION%%.*}
        if [[ $bash_major -lt 4 ]]; then
            echo "[workspace-tools] ⚠️  Bash $BASH_VERSION detectado, se recomienda 4.0+"
            echo "                   Algunas funcionalidades pueden no funcionar correctamente."
            shell_ok=false
        fi
    elif [ -n "$ZSH_VERSION" ]; then
        # Verificar Zsh >= 5.0
        local zsh_major=${ZSH_VERSION%%.*}
        if [[ $zsh_major -lt 5 ]]; then
            echo "[workspace-tools] ⚠️  Zsh $ZSH_VERSION detectado, se recomienda 5.0+"
            echo "                   Algunas funcionalidades pueden no funcionar correctamente."
            shell_ok=false
        fi
    else
        echo "[workspace-tools] ⚠️  Shell no reconocido (no es bash ni zsh)"
        echo "                   Las funciones de navegación (ws cd, wscd) pueden no funcionar."
        shell_ok=false
    fi

    # Verificar que bash está disponible para los scripts
    if ! command -v bash &> /dev/null; then
        echo "[workspace-tools] ❌ Bash no encontrado en el sistema"
        echo "                   Los scripts requieren Bash para ejecutarse."
        return 1
    fi

    # Verificar versión de bash del sistema (para los scripts)
    local system_bash_version=$(bash -c 'echo ${BASH_VERSION}' 2>/dev/null)
    if [ -n "$system_bash_version" ]; then
        local system_bash_major=${system_bash_version%%.*}
        if [[ $system_bash_major -lt 4 ]]; then
            echo "[workspace-tools] ❌ Bash del sistema es $system_bash_version, se requiere 4.0+"
            echo "                   En macOS: brew install bash"
            return 1
        fi
    fi

    return 0
}

# Ejecutar verificación (solo muestra warnings, no bloquea)
_ws_check_shell_version || {
    echo "[workspace-tools] ⚠️  Continuando con posibles limitaciones..."
}

# ══════════════════════════════════════════════════════════════
# Detectar directorio del script
# ══════════════════════════════════════════════════════════════

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
wmis() { ws mvn "$1" -T 1C install -DskipTests=true -Denforcer.skip=true; }
wmci() { ws mvn "$1" -T 1C clean install; }
wmcl() { ws mvn "$1" -T 1C clean; }

# Git shortcuts para workspaces
wgt() { ws git "$1" status; }
wgpa() { ws git "$1" pull --all; }
wstash() { ws stash "$@"; }
wgrep() { ws grep "$@"; }

# Navigation shortcuts para workspaces
# wscd: Navega a un repo dentro del workspace actual con matching parcial
wscd() {
    local repo_path
    repo_path=$("$WS_TOOLS/bin/ws-repo-path" "$@" 2>&1)
    local exit_code=$?

    if [ $exit_code -eq 0 ] && [ -n "$repo_path" ]; then
        cd "$repo_path" || return 1
        # Mostrar dónde estamos
        echo "${COLOR_CYAN}$(pwd)${COLOR_RESET}"
    else
        # Mostrar error del helper (ya viene formateado)
        echo "$repo_path"
        return 1
    fi
}
