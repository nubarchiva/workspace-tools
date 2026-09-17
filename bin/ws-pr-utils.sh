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
#   - pr_list_branch <p> <r> <rama> Pull requests de la rama, uno por línea
#   - pr_build_state <commit>       Estado de la construcción: failed | running | ok
#   - pr_print_repo <ruta> <rama>   Pinta el pull request más reciente de la rama
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

# Petición autenticada al servidor que deja el cuerpo en un fichero. Si falla,
# imprime el motivo en la salida de error.
# Uso interno: _pr_get <ruta_rest> <fichero_cuerpo> [parámetro...]
# Retorna: 0 si el servidor responde 200; 1 si no
_pr_get() {
    local path="$1" body="$2"
    shift 2
    local http_code rc

    # El token llega a curl por la entrada estándar: en la línea de órdenes lo
    # vería cualquier proceso con ps
    # -L: un repositorio renombrado en el servidor responde con una redirección
    # al slug nuevo mientras el remoto local conserve el viejo. curl no arrastra
    # la cabecera de autorización si la redirección lleva a otro host
    http_code=$(printf 'header = "Authorization: Bearer %s"\n' "$WS_BITBUCKET_TOKEN" | \
        curl -sS -G -K - -L --max-redirs 3 -m "${WS_BITBUCKET_TIMEOUT:-5}" -o "$body" -w '%{http_code}' \
        -H "Accept: application/json" "$@" "${WS_BITBUCKET_URL%/}/rest/$path" 2>/dev/null)
    rc=$?

    if [ $rc -ne 0 ]; then
        case $rc in
            6) echo "no se resuelve el nombre del servidor" >&2 ;;
            7) echo "no se puede conectar con el servidor" >&2 ;;
            28) echo "sin respuesta en ${WS_BITBUCKET_TIMEOUT:-5} s" >&2 ;;
            *) echo "error de curl ($rc)" >&2 ;;
        esac
        return 1
    fi

    case "$http_code" in
        200) return 0 ;;
        401) echo "token rechazado (HTTP 401)" >&2 ;;
        403) echo "sin permiso sobre el repositorio (HTTP 403)" >&2 ;;
        404) echo "repositorio no encontrado en el servidor (HTTP 404)" >&2 ;;
        *) echo "respuesta inesperada del servidor (HTTP $http_code)" >&2 ;;
    esac
    return 1
}

# Pull requests cuyo origen es una rama, en cualquier estado y del más reciente
# al más antiguo. Si la consulta falla, imprime el motivo en la salida de error.
# Uso: pr_list_branch <proyecto> <repositorio> <rama>
# Imprime: una línea por pull request,
#          "id<TAB>estado<TAB>destino<TAB>enlace<TAB>commit"
# Retorna: 0 si la consulta termina bien (aunque no haya ninguno); 1 si no
pr_list_branch() {
    local project="$1" repo="$2" branch="$3"
    local body

    if ! command -v curl >/dev/null 2>&1; then
        echo "requiere curl" >&2
        return 1
    fi
    if ! command -v jq >/dev/null 2>&1; then
        echo "requiere jq" >&2
        return 1
    fi

    body=$(mktemp "${TMPDIR:-/tmp}/ws-pr.XXXXXX") || return 1
    if ! _pr_get "api/latest/projects/$project/repos/$repo/pull-requests" "$body" \
        --data-urlencode "at=refs/heads/$branch" \
        --data-urlencode "direction=OUTGOING" \
        --data-urlencode "state=ALL" \
        --data-urlencode "order=NEWEST" \
        --data-urlencode "limit=25"; then
        rm -f "$body"
        return 1
    fi

    if ! jq -r '.values[] | [.id, .state, .toRef.displayId, (.links.self[0].href // ""), (.fromRef.latestCommit // "")] | @tsv' "$body" 2>/dev/null; then
        rm -f "$body"
        echo "respuesta no reconocible del servidor" >&2
        return 1
    fi
    rm -f "$body"
}

# Estado de la construcción del commit en el que está el pull request. Un fallo
# de la consulta no dice nada: el estado de build es información añadida y su
# ausencia no debe tapar el pull request.
# Uso: pr_build_state <commit>
# Imprime: failed | running | ok, o nada si no hay construcciones o falla
pr_build_state() {
    local commit="$1"
    local body stats

    [ -n "$commit" ] || return 0
    body=$(mktemp "${TMPDIR:-/tmp}/ws-pr-build.XXXXXX") || return 0
    if ! _pr_get "build-status/latest/commits/stats/$commit" "$body" 2>/dev/null; then
        rm -f "$body"
        return 0
    fi

    stats=$(jq -r '[(.failed // 0), (.inProgress // 0), (.successful // 0)] | @tsv' "$body" 2>/dev/null)
    rm -f "$body"

    local failed in_progress successful
    IFS=$'\t' read -r failed in_progress successful <<< "$stats"
    if [ "${failed:-0}" -gt 0 ] 2>/dev/null; then
        echo "failed"
    elif [ "${in_progress:-0}" -gt 0 ] 2>/dev/null; then
        echo "running"
    elif [ "${successful:-0}" -gt 0 ] 2>/dev/null; then
        echo "ok"
    fi
}

# Pinta el pull request más reciente de la rama del workspace en un repositorio.
# Un fallo de conexión con el servidor se recuerda en _WS_PR_SERVER_ERROR y los
# repositorios siguientes muestran el mismo motivo sin volver a esperar.
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

    # Solo el más reciente: la consulta los pide del más reciente al más antiguo
    # y read se queda con la primera línea
    local id state target link commit color build badge
    IFS=$'\t' read -r id state target link commit <<< "$lines"
    case "$state" in
        OPEN) color="$COLOR_CYAN" ;;
        MERGED) color="$COLOR_GREEN" ;;
        *) color="$COLOR_DIM" ;;
    esac

    build=$(pr_build_state "$commit")
    case "$build" in
        failed) badge=" ${COLOR_RED}❌${COLOR_RESET}" ;;
        running) badge=" ${COLOR_YELLOW}⏳${COLOR_RESET}" ;;
        ok) badge=" ${COLOR_GREEN}✅${COLOR_RESET}" ;;
        *) badge="" ;;
    esac

    echo "   🔀 PR #$id ${color}$state${COLOR_RESET}$badge → $target ${COLOR_DIM}$link${COLOR_RESET}"
}
