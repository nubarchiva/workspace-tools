# Función ws para bash/zsh
# Wrapper inteligente que cambia automáticamente al directorio del workspace
# al usar 'ws cd' o 'ws switch'

ws() {
    # Detectar WS_TOOLS
    if [ -z "$WS_TOOLS" ]; then
        echo "❌ Error: WS_TOOLS no está definido"
        echo "💡 Añade a tu ~/.bashrc o ~/.zshrc:"
        echo "   export WS_TOOLS=~/projects/tools/workspace-tools"
        return 1
    fi

    local ws_bin="$WS_TOOLS/bin/ws"

    # Si es 'cd' o 'switch', cambiar de directorio; con --status/-s, mostrar además
    # el estado de los repos
    if [ "$1" = "cd" ] || [ "$1" = "switch" ]; then
        shift
        local workspace_pattern=""
        local show_status=false
        local arg
        for arg in "$@"; do
            case "$arg" in
                --status|-s) show_status=true ;;
                *) [ -z "$workspace_pattern" ] && workspace_pattern="$arg" ;;
            esac
        done

        # Si no hay patrón y es switch, solo mostrar lista
        if [ -z "$workspace_pattern" ]; then
            "$ws_bin" switch
            return $?
        fi

        # Cargar funciones compartidas para resolver el workspace de forma interactiva
        source "$WS_TOOLS/bin/ws-common.sh"

        # Directorios resueltos como en el resto de comandos (ws-init.sh: entorno,
        # ~/.wsrc, ubicación de workspace-tools). Son locales: la shell del usuario
        # conserva los suyos
        local ws_dirs
        ws_dirs=$(bash -c 'source "$1/bin/ws-init.sh" >/dev/null 2>&1; printf "%s\n%s" "$WORKSPACE_ROOT" "$WORKSPACES_DIR"' _ "$WS_TOOLS")
        local -x WORKSPACE_ROOT="${ws_dirs%%$'\n'*}"
        local -x WORKSPACES_DIR="${ws_dirs#*$'\n'}"

        # Resolver el workspace (permite interacción si hay múltiples coincidencias)
        local workspace_name
        workspace_name=$(find_matching_workspace "$workspace_pattern" "$WORKSPACES_DIR")
        local find_exit_code=$?

        # Si falló (ej: no encontrado, cancelado), salir
        if [ $find_exit_code -ne 0 ]; then
            return $find_exit_code
        fi

        # Migración perezosa del acceso a nuba-management (ver ws-common.sh): aquí,
        # porque es donde el usuario entra al workspace y donde se ve el aviso
        management_migrate_on_start "$WORKSPACES_DIR/$workspace_name"

        local workspace_path="$WORKSPACES_DIR/$workspace_name"

        if [ -d "$workspace_path" ]; then
            # Cambiar al directorio
            cd "$workspace_path" || return 1

            # Mostrar confirmación breve
            echo "✅ Cambiado a workspace: $workspace_name"
            echo "📁 $workspace_path"
            echo ""

            # Aviso de repositorios de entorno desactualizados o sin comprobar
            local env_warning
            env_warning=$("$WS_TOOLS/bin/ws-env" --warn 2>/dev/null)
            if [ -n "$env_warning" ]; then
                echo "$env_warning"
                echo ""
            fi

            # Con --status, el estado de cada repo; si no, solo la lista de repos
            if $show_status; then
                WS_ENV_NO_WARN=1 "$WS_TOOLS/bin/ws-switch" "$workspace_name"
                return $?
            fi

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
