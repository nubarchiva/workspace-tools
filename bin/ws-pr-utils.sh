#!/bin/bash
# =============================================================================
# ws-pr-utils.sh - Pull requests de la rama de un workspace (Bitbucket Server)
# =============================================================================
#
# ws status muestra, por cada repositorio del workspace, los pull requests cuyo
# origen es la rama que gestiona el workspace. Los datos salen de la API REST de
# Bitbucket Server / Data Center. Cada usuario declara el servidor en ~/.wsrc;
# sin token no se consulta nada.
#
#   WS_BITBUCKET_URL       URL base del servidor (p. ej. https://bitbucket.example.com)
#   WS_BITBUCKET_TOKEN     Token de acceso HTTP con permiso de lectura
#   WS_BITBUCKET_HOSTS     Nombres de host de los remotos git que pertenecen a
#                          ese servidor, separados por espacios (por defecto,
#                          el host de WS_BITBUCKET_URL)
#   WS_BITBUCKET_TIMEOUT   Tiempo de espera de cada consulta, en segundos (por
#                          defecto 5)
#
# Requiere curl y jq.
#
# Funciones disponibles:
#   - pr_is_configured              0 si hay servidor y token declarados
#   - pr_repo_coordinates <url>     "proyecto<TAB>repositorio" de un remoto del servidor
#   - pr_list_branch <p> <r> <rama> Pull requests de la rama: "id<TAB>estado<TAB>destino<TAB>enlace"
#   - pr_print_repo <ruta> <rama>   Pinta los pull requests de la rama en un repositorio
#
# =============================================================================

[[ -n "$_WS_PR_UTILS_LOADED" ]] && return 0
_WS_PR_UTILS_LOADED=1

# Uso: pr_is_configured
# Retorna: 0 si WS_BITBUCKET_URL y WS_BITBUCKET_TOKEN están definidos; 1 si no
pr_is_configured() {
    [ -n "$WS_BITBUCKET_URL" ] && [ -n "$WS_BITBUCKET_TOKEN" ]
}

# Host de una URL http(s), sin usuario ni puerto
# Uso interno: _pr_url_host <url>
_pr_url_host() {
    local rest="${1#*://}"
    rest="${rest%%/*}"
    rest="${rest##*@}"
    echo "${rest%%:*}"
}

# Proyecto y repositorio de un remoto git que pertenece al servidor declarado.
# Admite ssh://git@host:puerto/proyecto/repo.git, git@host:proyecto/repo.git y
# http(s)://host/scm/proyecto/repo.git. La clave de proyecto se pasa a mayúsculas
# salvo en los repositorios personales (~usuario).
# Uso: pr_repo_coordinates <url_remoto>
# Imprime: "proyecto<TAB>repositorio"
# Retorna: 1 si el remoto no es del servidor o no tiene una forma reconocible
pr_repo_coordinates() {
    local url="$1"
    local host path

    case "$url" in
        *://*)
            host=$(_pr_url_host "$url")
            path="${url#*://}"
            path="/${path#*/}"
            path="${path#/scm}"
            ;;
        *@*:*)
            host="${url#*@}"
            host="${host%%:*}"
            path="/${url#*:}"
            ;;
        *)
            return 1
            ;;
    esac

    local hosts="${WS_BITBUCKET_HOSTS:-$(_pr_url_host "$WS_BITBUCKET_URL")}"
    case " $hosts " in
        *" $host "*) ;;
        *) return 1 ;;
    esac

    path="${path#/}"
    path="${path%/}"
    path="${path%.git}"

    local project="${path%%/*}"
    local repo="${path#*/}"
    [ -n "$project" ] && [ -n "$repo" ] && [ "$project" != "$path" ] || return 1
    [[ "$repo" == */* ]] && return 1

    case "$project" in
        "~"*) ;;
        *) project=$(printf '%s' "$project" | tr '[:lower:]' '[:upper:]') ;;
    esac

    printf '%s\t%s\n' "$project" "$repo"
}

# Pull requests cuyo origen es una rama, en cualquier estado y del más reciente
# al más antiguo. Si la consulta falla, imprime el motivo en la salida de error.
# Uso: pr_list_branch <proyecto> <repositorio> <rama>
# Imprime: una línea por pull request, "id<TAB>estado<TAB>destino<TAB>enlace"
# Retorna: 0 si la consulta termina bien (aunque no haya ninguno); 1 si no
pr_list_branch() {
    local project="$1" repo="$2" branch="$3"
    local base="${WS_BITBUCKET_URL%/}"
    local body http_code rc

    if ! command -v curl >/dev/null 2>&1; then
        echo "requiere curl" >&2
        return 1
    fi
    if ! command -v jq >/dev/null 2>&1; then
        echo "requiere jq" >&2
        return 1
    fi

    # El token llega a curl por la entrada estándar: en la línea de órdenes lo
    # vería cualquier proceso con ps
    body=$(mktemp "${TMPDIR:-/tmp}/ws-pr.XXXXXX") || return 1
    # -L: un repositorio renombrado en el servidor responde con una redirección
    # al slug nuevo mientras el remoto local conserve el viejo. curl no arrastra
    # la cabecera de autorización si la redirección lleva a otro host
    http_code=$(printf 'header = "Authorization: Bearer %s"\n' "$WS_BITBUCKET_TOKEN" | \
        curl -sS -G -K - -L --max-redirs 3 -m "${WS_BITBUCKET_TIMEOUT:-5}" -o "$body" -w '%{http_code}' \
        -H "Accept: application/json" \
        --data-urlencode "at=refs/heads/$branch" \
        --data-urlencode "direction=OUTGOING" \
        --data-urlencode "state=ALL" \
        --data-urlencode "order=NEWEST" \
        --data-urlencode "limit=25" \
        "$base/rest/api/latest/projects/$project/repos/$repo/pull-requests" 2>/dev/null)
    rc=$?

    if [ $rc -ne 0 ]; then
        rm -f "$body"
        case $rc in
            6) echo "no se resuelve el nombre del servidor" >&2 ;;
            7) echo "no se puede conectar con el servidor" >&2 ;;
            28) echo "sin respuesta en ${WS_BITBUCKET_TIMEOUT:-5} s" >&2 ;;
            *) echo "error de curl ($rc)" >&2 ;;
        esac
        return 1
    fi

    case "$http_code" in
        200) ;;
        401) rm -f "$body"; echo "token rechazado (HTTP 401)" >&2; return 1 ;;
        403) rm -f "$body"; echo "sin permiso sobre el repositorio (HTTP 403)" >&2; return 1 ;;
        404) rm -f "$body"; echo "repositorio no encontrado en el servidor (HTTP 404)" >&2; return 1 ;;
        *) rm -f "$body"; echo "respuesta inesperada del servidor (HTTP $http_code)" >&2; return 1 ;;
    esac

    if ! jq -r '.values[] | [.id, .state, .toRef.displayId, (.links.self[0].href // "")] | @tsv' "$body" 2>/dev/null; then
        rm -f "$body"
        echo "respuesta no reconocible del servidor" >&2
        return 1
    fi
    rm -f "$body"
}

# Pinta los pull requests de la rama del workspace en un repositorio. Un fallo de
# conexión con el servidor se recuerda en _WS_PR_SERVER_ERROR y los repositorios
# siguientes muestran el mismo motivo sin volver a esperar.
# Uso: pr_print_repo <ruta_repo> <rama>
pr_print_repo() {
    local repo_path="$1" branch="$2"
    local remote coordinates project repo lines err

    remote=$(git -C "$repo_path" remote get-url origin 2>/dev/null) || return 0
    coordinates=$(pr_repo_coordinates "$remote") || return 0
    project="${coordinates%%$'\t'*}"
    repo="${coordinates#*$'\t'}"

    if [ -n "$_WS_PR_SERVER_ERROR" ]; then
        echo "   ${COLOR_YELLOW}🔀 Pull requests sin comprobar: $_WS_PR_SERVER_ERROR${COLOR_RESET}"
        return 0
    fi

    err=$(mktemp "${TMPDIR:-/tmp}/ws-pr-err.XXXXXX") || return 0
    if ! lines=$(pr_list_branch "$project" "$repo" "$branch" 2>"$err"); then
        local cause
        cause=$(cat "$err")
        rm -f "$err"
        case "$cause" in
            "no se resuelve"*|"no se puede conectar"*|"sin respuesta"*|"requiere"*|"token rechazado"*)
                _WS_PR_SERVER_ERROR="$cause" ;;
        esac
        echo "   ${COLOR_YELLOW}🔀 Pull requests sin comprobar: $cause${COLOR_RESET}"
        return 0
    fi
    rm -f "$err"

    if [ -z "$lines" ]; then
        echo "   ${COLOR_DIM}🔀 Sin pull requests${COLOR_RESET}"
        return 0
    fi

    local id state target link color
    while IFS=$'\t' read -r id state target link; do
        case "$state" in
            OPEN) color="$COLOR_CYAN" ;;
            MERGED) color="$COLOR_GREEN" ;;
            *) color="$COLOR_DIM" ;;
        esac
        echo "   🔀 PR #$id ${color}$state${COLOR_RESET} → $target ${COLOR_DIM}$link${COLOR_RESET}"
    done <<< "$lines"
}
