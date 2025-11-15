#!/bin/bash
# Funciones compartidas para workspace-tools

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
        echo "${matches[0]}"
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

        # Retornar el workspace seleccionado (índice es 1-based, array es 0-based)
        echo "${matches[$((selection-1))]}"
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
