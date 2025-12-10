#!/bin/bash
# =============================================================================
# ws-git-utils.sh - Funciones de utilidad Git para workspace-tools
# =============================================================================
#
# Centraliza la lógica de verificación de estado Git que se repite en
# varios scripts (ws-list, ws-remove, ws-rename, ws-switch, ws-clean).
#
# Uso:
#   source "$SCRIPT_DIR/ws-git-utils.sh"
#
# Funciones disponibles:
#   - git_has_uncommitted_changes [path]
#   - git_count_uncommitted_changes [path]
#   - git_has_unpushed_commits [path]
#   - git_count_unpushed_commits [path]
#   - git_has_unpulled_commits [path]
#   - git_count_unpulled_commits [path]
#   - git_get_base_branch [path]
#   - git_get_current_branch [path]
#   - git_has_upstream [path]
#   - git_get_upstream_branch [path]
#   - git_repo_status [path] - Retorna estado completo en formato parseable
#
# =============================================================================

# Evitar doble carga
[[ -n "$_WS_GIT_UTILS_LOADED" ]] && return 0
_WS_GIT_UTILS_LOADED=1

# -----------------------------------------------------------------------------
# Detección de conectividad remota
# -----------------------------------------------------------------------------

# Cache del estado de conectividad (se evalúa una vez por ejecución)
_GIT_REMOTE_REACHABLE=""

# Archivo de modo persistente
_WS_MODE_FILE="${WS_TOOLS:-.}/.ws-mode"

# Verifica si estamos en modo offline forzado
# Uso: ws_is_offline_mode
# Retorna: 0 si modo offline, 1 si modo online
ws_is_offline_mode() {
    # Variable de entorno tiene prioridad
    if [ "$WS_OFFLINE" = "1" ] || [ "$WS_OFFLINE" = "true" ]; then
        return 0
    fi

    # Comprobar archivo de modo
    if [ -f "$_WS_MODE_FILE" ] && [ "$(cat "$_WS_MODE_FILE" 2>/dev/null)" = "offline" ]; then
        return 0
    fi

    return 1
}

# Verifica si el remoto es alcanzable
# Uso: git_is_remote_reachable [repo_path]
# Retorna: 0 si hay conexión, 1 si no
# Nota: Cachea el resultado para evitar múltiples comprobaciones
# Nota: Respeta modo offline (forzado o por archivo)
git_is_remote_reachable() {
    local repo_path="${1:-.}"

    # Si modo offline forzado, siempre retornar no alcanzable
    if ws_is_offline_mode; then
        _GIT_REMOTE_REACHABLE="no"
        return 1
    fi

    # Si ya comprobamos, devolver resultado cacheado
    if [ -n "$_GIT_REMOTE_REACHABLE" ]; then
        [ "$_GIT_REMOTE_REACHABLE" = "yes" ]
        return $?
    fi

    # Comprobar conectividad con timeout de 2 segundos
    if (cd "$repo_path" 2>/dev/null && timeout 2 git ls-remote --exit-code origin HEAD >/dev/null 2>&1); then
        _GIT_REMOTE_REACHABLE="yes"
        return 0
    else
        _GIT_REMOTE_REACHABLE="no"
        return 1
    fi
}

# Hace fetch si hay conectividad, sino lo salta silenciosamente
# Uso: git_fetch_if_reachable [repo_path]
git_fetch_if_reachable() {
    local repo_path="${1:-.}"

    if git_is_remote_reachable "$repo_path"; then
        (cd "$repo_path" && git fetch origin --quiet 2>/dev/null) || true
    fi
}

# -----------------------------------------------------------------------------
# Funciones de verificación de estado
# -----------------------------------------------------------------------------

# Verifica si hay cambios sin commitear (staged o unstaged)
# Uso: git_has_uncommitted_changes [path]
# Retorna: 0 si hay cambios, 1 si no hay
git_has_uncommitted_changes() {
    local repo_path="${1:-.}"

    if [[ ! -d "$repo_path" ]]; then
        return 1
    fi

    local status
    status=$(cd "$repo_path" && git status --porcelain 2>/dev/null)
    [[ -n "$status" ]]
}

# Cuenta los archivos con cambios sin commitear
# Uso: git_count_uncommitted_changes [path]
# Retorna: número de archivos (0 si no hay cambios o error)
git_count_uncommitted_changes() {
    local repo_path="${1:-.}"

    if [[ ! -d "$repo_path" ]]; then
        echo "0"
        return
    fi

    local count
    count=$(cd "$repo_path" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    echo "${count:-0}"
}

# Verifica si la branch actual tiene upstream configurado
# Uso: git_has_upstream [path]
# Retorna: 0 si tiene upstream, 1 si no
git_has_upstream() {
    local repo_path="${1:-.}"

    (cd "$repo_path" && git rev-parse --abbrev-ref @{u} >/dev/null 2>&1)
}

# Obtiene el nombre de la branch upstream
# Uso: git_get_upstream_branch [path]
# Retorna: nombre de la branch upstream o cadena vacía
git_get_upstream_branch() {
    local repo_path="${1:-.}"

    cd "$repo_path" && git rev-parse --abbrev-ref @{u} 2>/dev/null
}

# Obtiene la branch actual
# Uso: git_get_current_branch [path]
# Retorna: nombre de la branch actual o cadena vacía
git_get_current_branch() {
    local repo_path="${1:-.}"

    cd "$repo_path" && git branch --show-current 2>/dev/null
}

# Encuentra la branch base para comparar (origin/develop, origin/master, etc.)
# Uso: git_get_base_branch [path]
# Retorna: nombre de la branch base encontrada o cadena vacía
git_get_base_branch() {
    local repo_path="${1:-.}"

    local branch
    for branch in origin/develop origin/master develop master; do
        if (cd "$repo_path" && git rev-parse --verify "$branch" >/dev/null 2>&1); then
            echo "$branch"
            return 0
        fi
    done

    return 1
}

# Verifica si hay commits sin pushear
# Uso: git_has_unpushed_commits [path]
# Retorna: 0 si hay commits sin pushear, 1 si no
git_has_unpushed_commits() {
    local repo_path="${1:-.}"
    local count
    count=$(git_count_unpushed_commits "$repo_path")
    [[ "$count" -gt 0 ]]
}

# Cuenta commits sin pushear
# Uso: git_count_unpushed_commits [path]
# Retorna: número de commits (0 si no hay o error)
# Nota: Usa --first-parent para no contar commits que llegaron via merge
git_count_unpushed_commits() {
    local repo_path="${1:-.}"

    if [[ ! -d "$repo_path" ]]; then
        echo "0"
        return
    fi

    local count=0

    if git_has_upstream "$repo_path"; then
        # Tiene upstream: contar commits pendientes (--first-parent para no contar merges)
        count=$(cd "$repo_path" && git rev-list --first-parent @{u}..HEAD 2>/dev/null | wc -l | tr -d ' ')
    else
        # Sin upstream: comparar con branch base
        local base_branch
        base_branch=$(git_get_base_branch "$repo_path")
        if [[ -n "$base_branch" ]]; then
            count=$(cd "$repo_path" && git rev-list --first-parent "${base_branch}..HEAD" 2>/dev/null | wc -l | tr -d ' ')
        fi
    fi

    echo "${count:-0}"
}

# Verifica si hay commits sin pullear (en upstream pero no en local)
# Uso: git_has_unpulled_commits [path]
# Retorna: 0 si hay commits sin pullear, 1 si no
git_has_unpulled_commits() {
    local repo_path="${1:-.}"
    local count
    count=$(git_count_unpulled_commits "$repo_path")
    [[ "$count" -gt 0 ]]
}

# Cuenta commits sin pullear (commits en upstream que no están en local)
# Uso: git_count_unpulled_commits [path]
# Retorna: número de commits (0 si no hay o error)
git_count_unpulled_commits() {
    local repo_path="${1:-.}"

    if [[ ! -d "$repo_path" ]]; then
        echo "0"
        return
    fi

    local count=0

    if git_has_upstream "$repo_path"; then
        # Tiene upstream: contar commits pendientes de pull (HEAD..@{u})
        count=$(cd "$repo_path" && git rev-list HEAD..@{u} 2>/dev/null | wc -l | tr -d ' ')
    fi

    echo "${count:-0}"
}

# -----------------------------------------------------------------------------
# Función de estado completo (para evitar múltiples llamadas)
# -----------------------------------------------------------------------------

# Obtiene el estado completo de un repo en formato parseable
# Uso: git_repo_status [path]
# Retorna: línea con formato "uncommitted_count:unpushed_count:unpulled_count:has_upstream:current_branch:upstream_branch"
# Ejemplo: "3:5:2:1:feature/test:origin/feature/test"
git_repo_status() {
    local repo_path="${1:-.}"

    if [[ ! -d "$repo_path" ]]; then
        echo "0:0:0:0::"
        return 1
    fi

    local uncommitted_count unpushed_count unpulled_count has_upstream current_branch upstream_branch

    # Cambiar al directorio del repo
    cd "$repo_path" || return 1

    # Cambios sin commitear
    uncommitted_count=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    uncommitted_count="${uncommitted_count:-0}"

    # Branch actual
    current_branch=$(git branch --show-current 2>/dev/null)

    # Upstream, commits sin pushear y commits sin pullear
    # Nota: unpushed usa --first-parent para no contar commits de merges
    if git rev-parse --abbrev-ref @{u} >/dev/null 2>&1; then
        has_upstream=1
        upstream_branch=$(git rev-parse --abbrev-ref @{u} 2>/dev/null)
        unpushed_count=$(git rev-list --first-parent @{u}..HEAD 2>/dev/null | wc -l | tr -d ' ')
        unpulled_count=$(git rev-list HEAD..@{u} 2>/dev/null | wc -l | tr -d ' ')
    else
        has_upstream=0
        upstream_branch=""
        unpulled_count=0
        # Sin upstream: comparar con branch base
        local base_branch=""
        for branch in origin/develop origin/master develop master; do
            if git rev-parse --verify "$branch" >/dev/null 2>&1; then
                base_branch="$branch"
                break
            fi
        done
        if [[ -n "$base_branch" ]]; then
            unpushed_count=$(git rev-list --first-parent "${base_branch}..HEAD" 2>/dev/null | wc -l | tr -d ' ')
        else
            unpushed_count=0
        fi
    fi
    unpushed_count="${unpushed_count:-0}"
    unpulled_count="${unpulled_count:-0}"

    echo "${uncommitted_count}:${unpushed_count}:${unpulled_count}:${has_upstream}:${current_branch}:${upstream_branch}"
}

# -----------------------------------------------------------------------------
# Funciones de conveniencia para mostrar estado
# -----------------------------------------------------------------------------

# Muestra advertencia de cambios sin commitear si los hay
# Uso: git_warn_uncommitted <repo_name> [path]
git_warn_uncommitted() {
    local repo_name="$1"
    local repo_path="${2:-.}"

    local count
    count=$(git_count_uncommitted_changes "$repo_path")

    if [[ "$count" -gt 0 ]]; then
        echo "  ${COLOR_YELLOW}⚠️  $repo_name: $count archivo(s) sin commitear${COLOR_RESET}"
        return 0
    fi
    return 1
}

# Muestra advertencia de commits sin pushear si los hay
# Uso: git_warn_unpushed <repo_name> [path]
git_warn_unpushed() {
    local repo_name="$1"
    local repo_path="${2:-.}"

    local count
    count=$(git_count_unpushed_commits "$repo_path")

    if [[ "$count" -gt 0 ]]; then
        if git_has_upstream "$repo_path"; then
            echo "  ${COLOR_YELLOW}📤 $repo_name: $count commit(s) sin push${COLOR_RESET}"
        else
            echo "  ${COLOR_YELLOW}📤 $repo_name: $count commit(s) sin remoto${COLOR_RESET}"
        fi
        return 0
    fi
    return 1
}

# Muestra advertencia de commits sin pullear si los hay
# Uso: git_warn_unpulled <repo_name> [path]
git_warn_unpulled() {
    local repo_name="$1"
    local repo_path="${2:-.}"

    local count
    count=$(git_count_unpulled_commits "$repo_path")

    if [[ "$count" -gt 0 ]]; then
        echo "  ${COLOR_YELLOW}📥 $repo_name: $count commit(s) sin pull${COLOR_RESET}"
        return 0
    fi
    return 1
}
