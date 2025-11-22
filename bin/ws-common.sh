#!/bin/bash
# Funciones compartidas para workspace-tools

# Valida que un nombre de workspace sea válido
# Uso: validate_workspace_name <nombre>
# Retorna: 0 si es válido, 1 si no (con mensaje de error)
validate_workspace_name() {
    local name="$1"

    # Vacío
    if [[ -z "$name" ]]; then
        error "El nombre del workspace no puede estar vacío"
        return 1
    fi

    # Muy largo (límite razonable para paths)
    if [[ ${#name} -gt 64 ]]; then
        error "El nombre del workspace es demasiado largo (máx 64 caracteres)"
        return 1
    fi

    # Espacios
    if [[ "$name" =~ [[:space:]] ]]; then
        error "El nombre del workspace no puede contener espacios"
        return 1
    fi

    # Caracteres no permitidos en sistemas de archivos
    if [[ "$name" =~ [/\\:\*\?\"\'\<\>\|] ]]; then
        error "El nombre contiene caracteres no permitidos: / \\ : * ? \" ' < > |"
        return 1
    fi

    # No empezar con punto o guión
    if [[ "$name" =~ ^[.-] ]]; then
        error "El nombre no puede empezar con punto o guión"
        return 1
    fi

    # Nombres reservados
    if [[ "$name" == "workspaces" || "$name" == "repos" || "$name" == "tools" ]]; then
        error "'$name' es un nombre reservado"
        return 1
    fi

    return 0
}

# Función para encontrar workspaces que coincidan con un patrón (búsqueda parcial)
# Uso: find_matching_workspace <patron> <workspaces_dir>
# Retorna: nombre exacto del workspace encontrado
# Sale con error si no hay coincidencias o permite seleccionar si hay múltiples
find_matching_workspace() {
    local pattern=$1
    local workspaces_dir=$2

    # Si el patrón es exactamente "master" o "develop", retornarlo directamente
    if [ "$pattern" = "master" ] || [ "$pattern" = "develop" ]; then
        echo "$pattern"
        return 0
    fi

    # Buscar coincidencias parciales en todos los workspaces
    if [ ! -d "$workspaces_dir" ]; then
        echo "❌ No hay workspaces disponibles" >&2
        return 1
    fi

    # Buscar todos los workspaces que contengan el patrón
    local matches=()
    while IFS= read -r workspace_dir; do
        if [ -d "$workspace_dir" ]; then
            local workspace_name=$(basename "$workspace_dir")
            # Búsqueda case-insensitive (compatible con bash y zsh)
            local workspace_lower=$(echo "$workspace_name" | tr '[:upper:]' '[:lower:]')
            local pattern_lower=$(echo "$pattern" | tr '[:upper:]' '[:lower:]')
            if [[ "$workspace_lower" == *"$pattern_lower"* ]]; then
                matches+=("$workspace_name")
            fi
        fi
    done < <(find "$workspaces_dir" -maxdepth 1 -type d -not -path "$workspaces_dir")

    # Analizar resultados
    local num_matches=${#matches[@]}

    if [ $num_matches -eq 0 ]; then
        echo "❌ No se encontró ningún workspace que coincida con: '$pattern'" >&2
        echo "" >&2
        echo "Workspaces disponibles:" >&2
        if [ -d "$workspaces_dir" ]; then
            for workspace_dir in "$workspaces_dir"/*; do
                if [ -d "$workspace_dir" ]; then
                    echo "  • $(basename "$workspace_dir")" >&2
                fi
            done
        fi
        return 1
    elif [ $num_matches -eq 1 ]; then
        # Una sola coincidencia, usarla automáticamente
        # Compatible bash (0-indexed) y zsh (1-indexed)
        if [ -n "$ZSH_VERSION" ]; then
            echo "${matches[1]}"
        else
            echo "${matches[0]}"
        fi
        return 0
    else
        # Múltiples coincidencias, mostrar menú
        echo "" >&2
        echo "Se encontraron $num_matches workspaces que coinciden con '$pattern':" >&2
        echo "" >&2

        local i=1
        for match in "${matches[@]}"; do
            echo "  $i) $match" >&2
            ((i++))
        done

        echo "" >&2
        echo -n "Selecciona una opción [1-$num_matches] (o 0 para cancelar): " >&2
        read -r selection

        if [ -z "$selection" ] || [ "$selection" = "0" ]; then
            echo "❌ Cancelado" >&2
            return 1
        fi

        if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt $num_matches ]; then
            echo "❌ Selección inválida: $selection" >&2
            return 1
        fi

        # Retornar el workspace seleccionado
        # En bash: índice es 1-based (user), array es 0-based → selection-1
        # En zsh: índice es 1-based (user), array es 1-based → selection
        if [ -n "$ZSH_VERSION" ]; then
            echo "${matches[$selection]}"
        else
            echo "${matches[$((selection-1))]}"
        fi
        return 0
    fi
}

# Función para determinar el nombre de la branch según el workspace
# Uso: get_branch_name <workspace_name>
# Retorna: nombre de la branch (master, develop, o feature/nombre)
get_branch_name() {
    local workspace_name=$1

    if [ "$workspace_name" = "master" ]; then
        echo "master"
    elif [ "$workspace_name" = "develop" ]; then
        echo "develop"
    else
        echo "feature/$workspace_name"
    fi
}

# Función para encontrar todos los repos en un workspace (incluyendo subdirectorios)
find_repos_in_workspace() {
    local workspace_dir=$1
    # Buscar directorios .git hasta 3 niveles de profundidad
    find "$workspace_dir" -maxdepth 3 -name ".git" -type d -o -name ".git" -type f 2>/dev/null | \
        sed "s|$workspace_dir/||" | \
        sed 's|/.git||' | \
        sort
}

# Función para copiar configuraciones de IDE y AI assistants al workspace
# Uso: copy_workspace_config <workspace_dir>
# Directorio de referencia: usa CONFIG_REFERENCE_DIR si está definida, sino WORKSPACE_ROOT
copy_workspace_config() {
    local workspace_dir=$1

    # Evaluar en tiempo de ejecución para asegurar que WORKSPACE_ROOT está definida
    local config_source="${CONFIG_REFERENCE_DIR}"
    if [ -z "$config_source" ]; then
        config_source="$WORKSPACE_ROOT"
    fi

    echo ""
    echo "📋 Configurando workspace desde $config_source..."

    # Crear symlinks para documentación AI (SSOT - Single Source of Truth)
    if [ -f "$config_source/AI.md" ]; then
        echo "  • Enlazando AI.md (SSOT)"
        ln -sf "$config_source/AI.md" "$workspace_dir/AI.md"
    fi

    if [ -d "$config_source/.ai" ]; then
        echo "  • Enlazando .ai/ (documentación AI)"
        ln -sf "$config_source/.ai" "$workspace_dir/.ai"
    fi

    if [ -d "$config_source/docs" ]; then
        echo "  • Enlazando docs/ (documentación compartida)"
        ln -sf "$config_source/docs" "$workspace_dir/docs"
    fi

    # Copiar .idea/ (IntelliJ IDEA)
    if [ -d "$config_source/.idea" ]; then
        echo "  • Copiando configuración IntelliJ (.idea/)"
        cp -r "$config_source/.idea" "$workspace_dir/.idea"

        # Limpiar archivos específicos de sesión que no deben copiarse
        rm -f "$workspace_dir/.idea/workspace.xml" 2>/dev/null
        rm -f "$workspace_dir/.idea/usage.statistics.xml" 2>/dev/null
        rm -rf "$workspace_dir/.idea/shelf/" 2>/dev/null
        rm -f "$workspace_dir/.idea/tasks.xml" 2>/dev/null
    fi

    # Copiar .cursor/ (Cursor AI)
    if [ -d "$config_source/.cursor" ]; then
        echo "  • Copiando configuración Cursor (.cursor/)"
        cp -r "$config_source/.cursor" "$workspace_dir/.cursor"
    fi

    echo "  ✅ Configuración completada"
}

# Función para detectar el workspace actual basándose en el directorio actual
# Retorna: nombre del workspace si estamos dentro de uno, vacío si no
detect_current_workspace() {
    local current_dir="$(pwd)"

    # Usar WORKSPACES_DIR si ya esta definida, sino calcular
    local workspaces_dir
    if [ -n "$WORKSPACES_DIR" ]; then
        workspaces_dir="$WORKSPACES_DIR"
    elif [ -n "$WORKSPACE_ROOT" ]; then
        workspaces_dir="$WORKSPACE_ROOT/workspaces"
    elif [ -n "$WS_TOOLS" ]; then
        workspaces_dir="${WS_TOOLS%/tools/workspace-tools}/workspaces"
    else
        workspaces_dir=~/wrkspc.nubarchiva/workspaces
    fi

    # Verificar si estamos dentro de un workspace
    # Los workspaces están en $workspaces_dir/<nombre>/...
    if [[ "$current_dir" == "$workspaces_dir"/* ]]; then
        # Extraer el nombre del workspace (primer nivel después de workspaces/)
        local workspace_name="${current_dir#$workspaces_dir/}"
        workspace_name="${workspace_name%%/*}"
        echo "$workspace_name"
        return 0
    fi

    return 1
}
