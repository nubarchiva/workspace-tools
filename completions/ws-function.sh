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

        # Ejecutar ws-switch y capturar output
        local switch_output
        switch_output=$("$WS_TOOLS/bin/ws-switch" "$workspace_pattern" 2>&1)
        local exit_code=$?

        # Si falló (ej: múltiples coincidencias, no encontrado), mostrar output y salir
        if [ $exit_code -ne 0 ]; then
            echo "$switch_output"
            return $exit_code
        fi

        # Extraer la ruta del workspace del output
        local workspace_path
        workspace_path=$(echo "$switch_output" | grep "📁 Ruta:" | cut -d: -f2- | xargs)

        if [ -n "$workspace_path" ] && [ -d "$workspace_path" ]; then
            # Cambiar al directorio
            cd "$workspace_path" || return 1
            
            # Mostrar confirmación breve
            echo "✅ Cambiado a workspace: $(basename "$workspace_path")"
            echo "📁 $workspace_path"
            echo ""
            
            # Mostrar lista de repos si los hay
            echo "$switch_output" | grep -A 100 "Estado de los repos:" | grep "^📦" || true
        else
            # Si no se pudo extraer la ruta, mostrar output completo
            echo "$switch_output"
        fi

        return 0
    else
        # Para otros comandos, delegar al script original
        "$ws_bin" "$@"
        return $?
    fi
}
