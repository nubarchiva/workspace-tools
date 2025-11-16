# Función ws para bash/zsh
# Wrapper inteligente que cambia automáticamente al directorio del workspace
# al usar 'ws cd' o 'ws switch'

ws() {
    # Detectar WS_TOOLS
    if [ -z "$WS_TOOLS" ]; then
        echo "❌ Error: WS_TOOLS no está definido"
        echo "💡 Añade a tu ~/.bashrc o ~/.zshrc:"
        echo "   export WS_TOOLS=~/wrkspc.nubarchiva/tools/workspace-tools"
        return 1
    fi

    local ws_bin="$WS_TOOLS/bin/ws"

    # Si es 'cd' o 'switch', intentar cambiar directorio
    if [ "$1" = "cd" ] || [ "$1" = "switch" ]; then
        local workspace_pattern="$2"

        # Si no hay patrón y es switch, solo mostrar lista
        if [ -z "$workspace_pattern" ]; then
            "$ws_bin" switch
            return $?
        fi

        # Cargar funciones compartidas para resolver el workspace de forma interactiva
        source "$WS_TOOLS/bin/ws-common.sh"

        # Detectar WORKSPACE_ROOT
        if [ -n "$WS_TOOLS" ]; then
            WORKSPACE_ROOT="${WS_TOOLS%/tools/workspace-tools}"
        else
            WORKSPACE_ROOT=~/wrkspc.nubarchiva
        fi
        WORKSPACES_DIR=$WORKSPACE_ROOT/workspaces

        # Resolver el workspace (permite interacción si hay múltiples coincidencias)
        local workspace_name
        workspace_name=$(find_matching_workspace "$workspace_pattern" "$WORKSPACES_DIR")
        local find_exit_code=$?

        # Si falló (ej: no encontrado, cancelado), salir
        if [ $find_exit_code -ne 0 ]; then
            return $find_exit_code
        fi

        # Ahora ejecutar ws-switch con el nombre exacto y capturar output
        local switch_output
        switch_output=$("$WS_TOOLS/bin/ws-switch" "$workspace_name" 2>&1)
        local exit_code=$?

        if [ $exit_code -ne 0 ]; then
            echo "$switch_output"
            return $exit_code
        fi

        # Extraer la ruta del workspace del output
        local workspace_path="$WORKSPACES_DIR/$workspace_name"

        if [ -d "$workspace_path" ]; then
            # Cambiar al directorio
            cd "$workspace_path" || return 1

            # Mostrar confirmación breve
            echo "✅ Cambiado a workspace: $workspace_name"
            echo "📁 $workspace_path"
            echo ""

            # Mostrar lista de repos si los hay
            local repos=$(find_repos_in_workspace "$workspace_path" 2>/dev/null)
            if [ -n "$repos" ]; then
                echo "📦 Repos:"
                echo "$repos" | while read -r repo; do
                    echo "   • $repo"
                done
            fi
        else
            echo "❌ Error: No se pudo acceder a $workspace_path"
            return 1
        fi

        return 0
    else
        # Para otros comandos, delegar al script original
        "$ws_bin" "$@"
        return $?
    fi
}
