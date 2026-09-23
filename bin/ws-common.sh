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

    # Si el patrón designa una rama de integración, retornarlo directamente
    if is_branch_workspace "$pattern"; then
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

# Indica si el nombre de un workspace designa una rama de integración en lugar
# de una feature. Es el criterio único: quien lo cambie aquí lo cambia en todos
# los comandos que distinguen ambos casos.
# Uso: if is_branch_workspace "$nombre"; then ...
# Retorna: 0 si es rama de integración, 1 si no
is_branch_workspace() {
    case "$1" in
        master|main|develop) return 0 ;;
        *) return 1 ;;
    esac
}

# Función para determinar el nombre de la branch según el workspace
# Uso: get_branch_name <workspace_name>
# Retorna: nombre de la branch (master, main, develop, o feature/nombre)
get_branch_name() {
    local workspace_name=$1

    if is_branch_workspace "$workspace_name"; then
        echo "$workspace_name"
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
    local workspace_name=$(basename "$workspace_dir")

    # Evaluar en tiempo de ejecución para asegurar que WORKSPACE_ROOT está definida
    local config_source="${CONFIG_REFERENCE_DIR}"
    if [ -z "$config_source" ]; then
        config_source="$WORKSPACE_ROOT"
    fi

    echo ""
    echo "📋 Configurando workspace desde $config_source..."

    # Crear .claude/CLAUDE.md REAL (no symlink) para evitar confusión de working directory
    # Claude Code infiere el proyecto desde la ruta de CLAUDE.md, por eso debe ser archivo real
    mkdir -p "$workspace_dir/.claude"
    _generate_claude_md "$workspace_dir" "$workspace_name" "$config_source"
    echo "  • Creando .claude/CLAUDE.md (archivo real, no symlink)"

    # Crear symlink a AI.md para referencia (pero Claude usará .claude/CLAUDE.md primero)
    if [ -f "$config_source/AI.md" ]; then
        echo "  • Enlazando AI.md (documentación compartida)"
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

    # Dar acceso a nuba-management (gestión de evolutivos, SSOT fuera de producto)
    # con árbol propio; ver "Acceso a nuba-management" al final de este fichero
    setup_management_access "$workspace_dir" "$config_source"

    # Permisos del flujo desatendido: /jira-batch-impl commitea y publica por issue y su preflight (§1.5)
    # exige estas reglas en el worktree. Se crean al montar el workspace, acotadas a él, y solo si no existe
    # ya un settings.local.json (proceso de desarrollo autónomo de evolutivos, hallazgo H33).
    local local_settings="$workspace_dir/.claude/settings.local.json"
    if [ ! -f "$local_settings" ]; then
        echo "  • Creando .claude/settings.local.json (permisos de commit y push para las fases desatendidas)"
        cat > "$local_settings" <<'JSON'
{
  "permissions": {
    "allow": [
      "Bash(git commit:*)",
      "Bash(git push:*)"
    ]
  }
}
JSON
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

# Genera el archivo .claude/CLAUDE.md con contenido real para el worktree
# Uso interno: _generate_claude_md <workspace_dir> <workspace_name> <config_source>
_generate_claude_md() {
    local workspace_dir=$1
    local workspace_name=$2
    local config_source=$3
    local claude_md_path="$workspace_dir/.claude/CLAUDE.md"

    cat > "$claude_md_path" << EOF
# Worktree: $workspace_name

## Working Directory

**IMPORTANTE**: Este es un worktree independiente.
- Ruta: \`$workspace_dir\`
- Buscar código SOLO dentro de este directorio
- NO buscar en la raíz del workspace (\`$config_source\`)

## Documentación Compartida

La documentación AI está disponible via symlinks (SSOT - Single Source of Truth):
- \`AI.md\` → Guidelines principales del proyecto
- \`.ai/\` → Documentación técnica detallada
- \`docs/\` → Documentación general

Para contexto completo del proyecto, consultar:
- \`.ai/context.md\` - Contexto global del ecosistema
- \`.ai/coding-standards.md\` - DDD, Clean Architecture, convenciones

## Repos en este Worktree

Los repositorios de código están en subdirectorios de este worktree.
Usar \`ws info\` o \`ws status\` para ver los repos incluidos.

---
*Generado automáticamente por workspace-tools*
EOF
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
        workspaces_dir=~/projects/workspaces
    fi

    # Los workspaces están en $workspaces_dir/<nombre>/...
    # Se compara primero la ruta tal como se ha escrito y después la física, de
    # modo que se detecta el workspace tanto si se entra por un symlink a la raíz
    # como si el propio workspace es un symlink
    _workspace_name_under "$current_dir" "$workspaces_dir" && return 0

    local physical_workspaces_dir
    physical_workspaces_dir=$(_physical_path "$workspaces_dir") || return 1
    _workspace_name_under "$(pwd -P)" "$physical_workspaces_dir"
}

# Nombre del workspace que contiene un directorio: el primer nivel bajo el
# directorio de workspaces
# Uso interno: _workspace_name_under <dir> <workspaces_dir>
_workspace_name_under() {
    local dir="$1" workspaces_dir="$2"

    [[ "$dir" == "$workspaces_dir"/* ]] || return 1

    local workspace_name="${dir#"$workspaces_dir"/}"
    echo "${workspace_name%%/*}"
}

# =============================================================================
# Acceso a nuba-management
# =============================================================================
# Un workspace llega al repositorio de gestión `nuba-management` en uno de dos
# regímenes:
#
#   • propio      worktree de git en la rama `wt/<workspace>`: árbol e índice
#                 solo suyos, y por tanto git normal para commitear y publicar
#   • compartido  symlink al clon principal: árbol e índice únicos para todos
#                 los workspaces, de donde salían los commits que se llevaban
#                 ficheros ajenos (hallazgo H173 del evolutivo
#                 autonomous-development-process)
#
# El propio es el régimen actual; el symlink queda como salida cuando no hay un
# clon del que colgar el worktree. Se reconoce en un comando:
#
#     [ -L nuba-management ] && echo compartido || echo propio
#
# El worktree se crea en la MISMA ruta que ocupaba el symlink, así que las rutas
# relativas `nuba-management/...` siguen valiendo sin tocar nada.

MANAGEMENT_DIR_NAME="nuba-management"

# Ruta física de un directorio (sin symlinks intermedios): las rutas que da lsof
# lo son, y el registro de worktrees de git debe apuntar a la misma
# Uso interno: _physical_path <dir>
_physical_path() {
    (cd "$1" 2>/dev/null && pwd -P)
}

# Rama del worktree de gestión de un workspace
# Uso: management_branch <workspace_name>
management_branch() {
    echo "wt/$1"
}

# Régimen de acceso a nuba-management de un workspace
# Uso: management_regime <workspace_dir>
# Retorna por stdout: propio | compartido | ninguno
management_regime() {
    local link="${1%/}/$MANAGEMENT_DIR_NAME"

    if [ -L "$link" ]; then
        echo "compartido"
    elif [ -d "$link" ]; then
        echo "propio"
    else
        echo "ninguno"
    fi
}

# Comprueba si un clon de nuba-management admite worktrees
# Uso: if blocker=$(management_worktree_blocker <repo>); then ... fi
# Retorna: 0 si admite; 1 con el motivo por stdout si no
management_worktree_blocker() {
    local repo=$1

    if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
        echo "no es un repositorio git"
        return 1
    fi

    if ! git -C "$repo" show-ref --verify --quiet refs/remotes/origin/main; then
        echo "no tiene origin/main"
        return 1
    fi

    return 0
}

# Crea el worktree de gestión en una ruta libre
# Uso interno: _management_add_worktree <repo> <destino> <branch>
# Retorna: 0 y silencio si lo crea; 1 con la salida de git por stdout si no
# Nota: el destino no puede llamarse `path`, que en zsh es la variable especial
# ligada a PATH y dejaría a la función sin comandos
_management_add_worktree() {
    local repo=$1
    local target=$2
    local branch=$3

    if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
        git -C "$repo" worktree add "$target" "$branch" 2>&1
    else
        git -C "$repo" worktree add -b "$branch" "$target" origin/main 2>&1
    fi
}

# Lista los PID con directorio de trabajo dentro de un workspace, excluyendo el
# proceso que pregunta, sus antepasados y sus descendientes: un filtro que no se
# excluya a sí mismo se encuentra siempre, porque el propio comando corre ahí.
# Uso: workspace_live_pids <workspace_dir>
# Retorna: 0 con los PID por stdout (vacío si no hay ninguno); 2 si no se puede medir
workspace_live_pids() {
    local dir
    dir=$(_physical_path "${1%/}") || return 2
    [ -n "$dir" ] || return 2

    if ! command -v lsof >/dev/null 2>&1; then
        return 2
    fi

    # El orden importa: primero lsof y después la tabla de procesos, porque lo que
    # ya no está en esa tabla o ha parado o es la propia medición, que también
    # trabaja aquí dentro y se ve a sí misma en el listado de lsof
    {
        lsof -a -d cwd -Fpn 2>/dev/null | awk -v dir="$dir" '
            substr($0, 1, 1) == "p" { pid = substr($0, 2); next }
            substr($0, 1, 1) == "n" {
                path = substr($0, 2)
                if (path == dir || index(path, dir "/") == 1) print pid
            }
        '
        echo "@@@"
        ps -eo pid=,ppid=
    } | exclude_own_process_tree
}

# Filtra una lista de PID candidatos: deja los que siguen vivos y no son el
# proceso que pregunta, ni sus antepasados, ni sus descendientes.
# Entrada por stdin: un PID por línea, una línea "@@@" y la tabla `ps -eo pid=,ppid=`
# tomada DESPUÉS de obtener los candidatos
# Uso: { candidatos; echo "@@@"; ps -eo pid=,ppid=; } | exclude_own_process_tree
exclude_own_process_tree() {
    awk -v self="$$" '
        function is_mine(pid,   p, hops) {
            if (pid in ancestors) return 1
            for (p = pid; p != "" && p != "0" && hops++ < 200; p = parent[p]) {
                if (p == self) return 1
            }
            return 0
        }
        $1 == "@@@" { ps_section = 1; next }
        !ps_section { if ($1 != "") candidate[$1] = 1; next }
        { parent[$1] = $2 }
        END {
            hops = 0
            for (p = self; p != "" && p != "0" && hops++ < 200; p = parent[p]) ancestors[p] = 1
            for (pid in candidate) {
                if ((pid in parent) && !is_mine(pid)) print pid
            }
        }
    '
}

# Da acceso a nuba-management a un workspace recién montado: worktree si se
# puede, symlink al clon compartido si no, diciendo por qué.
# Uso: setup_management_access <workspace_dir> <config_source>
setup_management_access() {
    local workspace_dir
    local config_source
    workspace_dir=$(_physical_path "${1%/}") || return 0
    config_source=$(_physical_path "${2%/}") || return 0
    local repo="$config_source/$MANAGEMENT_DIR_NAME"
    local link="$workspace_dir/$MANAGEMENT_DIR_NAME"
    local branch="$(management_branch "$(basename "$workspace_dir")")"

    [ -d "$repo" ] || return 0

    # Acceso ya resuelto (worktree o symlink de un montaje anterior): no se toca
    if [ -e "$link" ] || [ -L "$link" ]; then
        return 0
    fi

    local blocker
    if blocker=$(management_worktree_blocker "$repo"); then
        local output
        if output=$(_management_add_worktree "$repo" "$link" "$branch"); then
            echo "  • Creando worktree de nuba-management/ (rama $branch, árbol propio)"
            return 0
        fi
        echo "  ⚠️  No se pudo crear el worktree de nuba-management: $output"
        blocker="falló git worktree add"
    fi

    echo "  • Enlazando nuba-management/ (árbol compartido: el clon $blocker)"
    ln -s "$repo" "$link"
}

# Convierte el acceso compartido de un workspace en árbol propio, en la misma
# ruta. No toca un workspace con procesos trabajando dentro: cambiarle el
# symlink bajo los pies le rompe el trabajo en curso.
# Uso: management_switch_to_worktree <workspace_dir> [<config_source>]
# Retorna: 0 migrado; 1 nada que migrar o no se pudo; 2 hay procesos vivos
management_switch_to_worktree() {
    local workspace_dir
    local config_source
    workspace_dir=$(_physical_path "${1%/}") || return 1
    config_source=$(_physical_path "${2:-$WORKSPACE_ROOT}") || return 1
    local repo="$config_source/$MANAGEMENT_DIR_NAME"
    local link="$workspace_dir/$MANAGEMENT_DIR_NAME"
    local branch="$(management_branch "$(basename "$workspace_dir")")"

    # Solo el régimen compartido se migra: el propio ya lo está, y un workspace
    # sin acceso no lo pide
    [ -L "$link" ] || return 1
    [ -d "$repo" ] || return 1
    management_worktree_blocker "$repo" >/dev/null || return 1

    local live
    live=$(workspace_live_pids "$workspace_dir")
    if [ $? -ne 0 ] || [ -n "$live" ]; then
        return 2
    fi

    rm -f "$link"

    local output
    if output=$(_management_add_worktree "$repo" "$link" "$branch"); then
        return 0
    fi

    # El worktree no salió: el workspace se queda como estaba
    ln -s "$repo" "$link"
    echo "  ⚠️  No se pudo migrar nuba-management a árbol propio: $output"
    return 1
}

# Vuelta atrás: deshace el árbol propio y restituye el symlink al clon
# compartido. Elimina el worktree con lo que contenga, así que quien lo llama se
# encarga de avisar de lo que no esté commiteado.
# Uso: management_switch_to_shared <workspace_dir> [<config_source>]
# Retorna: 0 restituido o ya compartido; 1 no hay nada que deshacer
management_switch_to_shared() {
    local workspace_dir
    local config_source
    workspace_dir=$(_physical_path "${1%/}") || return 1
    config_source=$(_physical_path "${2:-$WORKSPACE_ROOT}") || return 1
    local repo="$config_source/$MANAGEMENT_DIR_NAME"
    local link="$workspace_dir/$MANAGEMENT_DIR_NAME"

    [ -d "$repo" ] || return 1
    [ -L "$link" ] && return 0
    [ -d "$link" ] || return 1

    rm -rf "$link"
    git -C "$repo" worktree prune
    ln -s "$repo" "$link"
}

# Migración perezosa en el arranque de un workspace: el que aún llega por
# symlink pasa a árbol propio la próxima vez que se usa, y solo si no hay nadie
# trabajando dentro. Imprime lo que ha hecho; calla cuando no hay nada que hacer.
# Uso: management_migrate_on_start <workspace_dir>
management_migrate_on_start() {
    local workspace_dir="${1%/}"

    management_switch_to_worktree "$workspace_dir"
    case $? in
        0)
            echo "🌳 nuba-management migrado a árbol propio (rama $(management_branch "$(basename "$workspace_dir")"))"
            ;;
        2)
            echo "🔗 nuba-management sigue compartido: hay procesos trabajando en este workspace"
            ;;
    esac
}
