#!/bin/bash
# Funciones compartidas para workspace-tools

# Función para encontrar workspaces que coincidan con un patrón (búsqueda parcial)
# Uso: find_matching_workspace <tipo> <patron> <workspaces_dir>
# Retorna: nombre exacto del workspace encontrado
# Sale con error si no hay coincidencias o permite seleccionar si hay múltiples
find_matching_workspace() {
    local workspace_type=$1
    local pattern=$2
    local workspaces_dir=$3
    
    # Para master y develop, no necesitamos búsqueda (son únicos)
    if [ "$workspace_type" = "master" ] || [ "$workspace_type" = "develop" ]; then
        echo "$workspace_type"
        return 0
    fi
    
    # Para features, buscar coincidencias parciales
    if [ "$workspace_type" = "feature" ]; then
        local features_dir="$workspaces_dir/features"
        
        if [ ! -d "$features_dir" ]; then
            echo "❌ No hay features disponibles" >&2
            return 1
        fi
        
        # Buscar todas las features que contengan el patrón
        local matches=()
        while IFS= read -r feature_dir; do
            if [ -d "$feature_dir" ]; then
                local feature_name=$(basename "$feature_dir")
                # Búsqueda case-insensitive
                if [[ "$feature_name" == *"$pattern"* ]] || [[ "${feature_name,,}" == *"${pattern,,}"* ]]; then
                    matches+=("$feature_name")
                fi
            fi
        done < <(find "$features_dir" -maxdepth 1 -type d -not -path "$features_dir")
        
        # Analizar resultados
        local num_matches=${#matches[@]}
        
        if [ $num_matches -eq 0 ]; then
            echo "❌ No se encontró ninguna feature que coincida con: '$pattern'" >&2
            echo "" >&2
            echo "Features disponibles:" >&2
            if [ -d "$features_dir" ]; then
                for feature_dir in "$features_dir"/*; do
                    if [ -d "$feature_dir" ]; then
                        echo "  • $(basename "$feature_dir")" >&2
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
            echo "Se encontraron $num_matches features que coinciden con '$pattern':" >&2
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
            
            # Retornar la feature seleccionada (índice es 1-based, array es 0-based)
            echo "${matches[$((selection-1))]}"
            return 0
        fi
    fi
    
    echo "❌ Tipo de workspace no soportado: $workspace_type" >&2
    return 1
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
