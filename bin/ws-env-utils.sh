#!/bin/bash
# =============================================================================
# ws-env-utils.sh - Repositorios de entorno (ws env)
# =============================================================================
#
# Los repositorios de entorno son los que el workspace consume pero no desarrolla:
# configuración de asistentes, directrices, tooling o gestión compartidos. Cada
# usuario los declara en ~/.wsrc; la herramienta no presupone ninguno.
#
#   WS_ENV_REPOS           Rutas separadas por ':'. Absolutas, con ~ o relativas
#                          a WORKSPACE_ROOT
#   WS_ENV_FETCH_TTL       Segundos durante los que un fetch se da por vigente en
#                          los avisos automáticos (por defecto 300)
#   WS_ENV_FETCH_TIMEOUT   Tiempo de espera de cada fetch, en segundos (por
#                          defecto 5)
#   WS_ENV_BUSY_CMD        Orden que imprime los PID de las sesiones que usan
#                          esos repositorios, uno por línea al principio
#
# Funciones disponibles:
#   - env_repo_entries          Entradas declaradas: "etiqueta<TAB>ruta"
#   - env_collect <modo>        Estado de cada entrada (modo: always|ttl|never)
#   - env_render_status         Pinta el estado leído de env_collect
#   - env_print_status <modo>   env_collect + env_render_status
#   - env_drift_warning         Aviso breve de desfase y de lo no comprobado
#   - env_repo_head <ruta>      Hash corto y fecha del último commit
#   - env_live_sessions         PID de sesiones vivas ajenas a quien pregunta
#   - env_confirm               Lee una respuesta s/N
#
# =============================================================================

[[ -n "$_WS_ENV_UTILS_LOADED" ]] && return 0
_WS_ENV_UTILS_LOADED=1

# Entradas declaradas en WS_ENV_REPOS, una por línea: "etiqueta<TAB>ruta absoluta"
# Uso: env_repo_entries
env_repo_entries() {
    local entry
    local old_ifs="$IFS"
    IFS=':'
    set -f
    local entries=($WS_ENV_REPOS)
    set +f
    IFS="$old_ifs"

    for entry in "${entries[@]}"; do
        entry="${entry#"${entry%%[![:space:]]*}"}"
        entry="${entry%"${entry##*[![:space:]]}"}"
        [ -n "$entry" ] || continue

        case "$entry" in
            "~") printf '%s\t%s\n' "$entry" "$HOME" ;;
            "~/"*) printf '%s\t%s\n' "$entry" "$HOME/${entry#\~/}" ;;
            /*) printf '%s\t%s\n' "$entry" "$entry" ;;
            *) printf '%s\t%s\n' "$entry" "$WORKSPACE_ROOT/$entry" ;;
        esac
    done
}

# Motivo por el que una ruta no se puede comprobar, o nada si se puede
# Uso interno: _env_precheck <ruta>
_env_precheck() {
    local path="$1"
    local top

    if [ ! -e "$path" ]; then
        echo "no existe"
        return
    fi

    if ! top=$(git -C "$path" rev-parse --show-toplevel 2>/dev/null); then
        echo "no es un repositorio git"
        return
    fi

    if [ "$(cd "$path" && pwd -P)" != "$(cd "$top" && pwd -P)" ]; then
        echo "no es la raíz de un repositorio git"
        return
    fi

    if ! git -C "$path" rev-parse --verify --quiet '@{u}' >/dev/null 2>&1; then
        echo "sin rama de seguimiento"
    fi
}

# Marca del último fetch correcto, dentro del directorio git del repositorio.
# FETCH_HEAD no sirve: git lo reescribe al empezar un fetch aunque después falle.
# Uso interno: _env_fetch_mark <ruta>
_env_fetch_mark() {
    local git_dir
    git_dir=$(git -C "$1" rev-parse --absolute-git-dir 2>/dev/null) || return 1
    echo "$git_dir/ws-env-last-fetch"
}

# Indica si el último fetch correcto de un repositorio es más antiguo que WS_ENV_FETCH_TTL
# Uso interno: _env_fetch_is_stale <ruta>
_env_fetch_is_stale() {
    local ttl="${WS_ENV_FETCH_TTL:-300}"
    local mark mtime

    mark=$(_env_fetch_mark "$1") || return 0
    [ -f "$mark" ] || return 0

    mtime=$(stat -c %Y "$mark" 2>/dev/null || stat -f %m "$mark" 2>/dev/null) || return 0
    [ $(( $(date +%s) - mtime )) -ge "$ttl" ]
}

# Fetch no interactivo y con tiempo de espera propio. Si falla, imprime el motivo.
# Uso interno: _env_fetch <ruta>
# Retorna: 0 si el fetch termina bien; 1 si no
_env_fetch() {
    local wait_seconds="${WS_ENV_FETCH_TIMEOUT:-5}"
    local runner=()
    local rc

    if command -v timeout >/dev/null 2>&1; then
        runner=(timeout "$wait_seconds")
    fi

    local err
    err=$(GIT_TERMINAL_PROMPT=0 \
          GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=$wait_seconds" \
          "${runner[@]}" git -C "$1" fetch --quiet 2>&1 >/dev/null)
    rc=$?

    if [ $rc -eq 0 ]; then
        touch "$(_env_fetch_mark "$1")"
        return 0
    fi

    if [ $rc -eq 124 ] && [ ${#runner[@]} -gt 0 ]; then
        echo "sin respuesta del remoto en $wait_seconds s"
        return 1
    fi

    case "$(git_error_cause "$err")" in
        agent) echo "el agente SSH no ha firmado" ;;
        dns) echo "el nombre del servidor no resuelve" ;;
        hostkey) echo "clave de host desconocida" ;;
        publickey) echo "el servidor rechaza la clave SSH" ;;
        https-auth) echo "faltan credenciales HTTPS" ;;
        tls) echo "problema con el certificado TLS" ;;
        network) echo "sin conexión con el servidor" ;;
        *) echo "fetch fallido" ;;
    esac
    return 1
}

# Estado de cada repositorio declarado, una línea por entrada:
#   etiqueta<TAB>ruta<TAB>estado<TAB>por_detrás<TAB>por_delante<TAB>pendientes<TAB>detalle
# Estados: ok | ahead | behind | diverged | unchecked (el detalle dice por qué)
# por_delante cuenta commits; pendientes, los que aportan un cambio que el remoto no
# tiene: un cherry-pick publicado con otro hash no cuenta. Si solo va por delante, se
# compara el árbol con el remoto; si ha divergido, cada commit por patch-id (git cherry)
# Los fetch necesarios se lanzan en paralelo, cada uno con su tiempo de espera.
# Uso: env_collect <always|ttl|never>
env_collect() {
    local mode="${1:-ttl}"
    local labels=() paths=() details=() fetch_pids=()
    local label path i n

    n=0
    while IFS=$'\t' read -r label path; do
        labels[n]="$label"
        paths[n]="$path"
        details[n]=$(_env_precheck "$path")
        n=$((n + 1))
    done < <(env_repo_entries)

    [ "$n" -gt 0 ] || return 0

    local results
    results=$(mktemp -d "${TMPDIR:-/tmp}/ws-env.XXXXXX") || return 1

    for ((i = 0; i < n; i++)); do
        [ -z "${details[i]}" ] || continue
        [ "$mode" != "never" ] || continue
        if [ "$mode" = "ttl" ] && ! _env_fetch_is_stale "${paths[i]}"; then
            continue
        fi
        if ws_is_offline_mode; then
            echo "modo offline" > "$results/$i"
            continue
        fi
        ( _env_fetch "${paths[i]}" > "$results/$i" || true ) &
        fetch_pids+=($!)
    done

    for i in "${fetch_pids[@]}"; do
        wait "$i"
    done

    local behind ahead pending counts note state
    for ((i = 0; i < n; i++)); do
        behind=0
        ahead=0
        pending=0
        note="${details[i]}"
        state="unchecked"

        if [ -z "$note" ]; then
            counts=$(git -C "${paths[i]}" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null)
            behind=$(echo "$counts" | awk '{print $1+0}')
            ahead=$(echo "$counts" | awk '{print $2+0}')
            if [ "$ahead" -gt 0 ] && [ "$behind" -eq 0 ] && git -C "${paths[i]}" diff --quiet '@{u}' HEAD 2>/dev/null; then
                # Por delante sin cambiar nada: los commits locales ya están publicados con otro hash
                pending=0
            elif [ "$ahead" -gt 0 ]; then
                pending=$(git -C "${paths[i]}" cherry '@{u}' HEAD 2>/dev/null | grep -c '^+')
            fi
            [ -s "$results/$i" ] && note=$(cat "$results/$i")

            # Un desfase ya conocido es cierto aunque el fetch de ahora no llegue
            if [ "$behind" -gt 0 ] && [ "$ahead" -gt 0 ]; then
                state="diverged"
            elif [ "$behind" -gt 0 ]; then
                state="behind"
            elif [ -n "$note" ]; then
                state="unchecked"
            elif [ "$ahead" -gt 0 ]; then
                state="ahead"
            else
                state="ok"
            fi
        fi

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "${labels[i]}" "${paths[i]}" "$state" "$behind" "$ahead" "$pending" "$note"
    done

    rm -rf "$results"
}

# Hash corto y fecha del último commit de un repositorio (vacío si no es git)
# Uso: env_repo_head <ruta>
env_repo_head() {
    git -C "$1" log -1 --format='%h %cd' --date=format:'%Y-%m-%d %H:%M' 2>/dev/null
}

# Pinta el estado que produce env_collect, leído por stdin
# Uso: env_collect <modo> | env_render_status
# Retorna: 0 si todo está al día; 1 si alguno va por detrás, ha divergido o no se ha podido comprobar
env_render_status() {
    local label path state behind ahead pending note head suffix
    local rc=0

    while IFS=$'\t' read -r label path state behind ahead pending note; do
        head=$(env_repo_head "$path")
        suffix=""
        [ -n "$head" ] && suffix="  ${COLOR_DIM}$head${COLOR_RESET}"

        case "$state" in
            ok)
                echo "  ✅ ${COLOR_CYAN}$label${COLOR_RESET}  al día$suffix"
                ;;
            ahead)
                if [ "$pending" -gt 0 ]; then
                    echo "  ✅ ${COLOR_CYAN}$label${COLOR_RESET}  al día, ${COLOR_YELLOW}↑$pending sin publicar${COLOR_RESET}$suffix"
                else
                    echo "  ✅ ${COLOR_CYAN}$label${COLOR_RESET}  al día, sin contenido local pendiente$suffix"
                fi
                ;;
            behind)
                echo "  ⚠️  ${COLOR_CYAN}$label${COLOR_RESET}  ${COLOR_MAGENTA}↓$behind por detrás del remoto${COLOR_RESET}$suffix"
                rc=1
                ;;
            diverged)
                echo "  ❌ ${COLOR_CYAN}$label${COLOR_RESET}  ${COLOR_RED}divergido ($(_env_divergence "$ahead" "$behind" "$pending"))${COLOR_RESET}$suffix"
                rc=1
                ;;
            *)
                echo "  ℹ️  ${COLOR_CYAN}$label${COLOR_RESET}  ${COLOR_YELLOW}sin comprobar: $note${COLOR_RESET}$suffix"
                rc=1
                ;;
        esac
    done

    return $rc
}

# Uso: env_print_status <always|ttl|never>
env_print_status() {
    env_collect "$1" | env_render_status
}

# Detalle de una divergencia: contadores y, si ningún commit local aporta un cambio
# que el remoto no tenga, que no hay contenido local pendiente
# Uso interno: _env_divergence <por_delante> <por_detrás> <pendientes>
_env_divergence() {
    if [ "$3" -gt 0 ]; then
        echo "↑$1 ↓$2"
    else
        echo "↑$1 ↓$2, sin contenido local pendiente"
    fi
}

# Une los argumentos con ", "
# Uso interno: _env_join <elemento>...
_env_join() {
    local result="$1"
    shift
    local item
    for item in "$@"; do
        result="$result, $item"
    done
    echo "$result"
}

# Aviso breve para los comandos de uso diario: una línea con los repositorios que
# van por detrás o han divergido y otra con los que no se han podido comprobar.
# Calla si no hay nada que decir o no hay repositorios declarados.
# Uso: env_drift_warning
env_drift_warning() {
    [ -n "$WS_ENV_REPOS" ] || return 0

    local stale=() unknown=()
    local label path state behind ahead note

    while IFS=$'\t' read -r label path state behind ahead pending note; do
        case "$state" in
            behind) stale+=("$label ↓$behind") ;;
            diverged) stale+=("$label divergido ($(_env_divergence "$ahead" "$behind" "$pending"))") ;;
            unchecked) unknown+=("$label ($note)") ;;
        esac
    done < <(env_collect ttl)

    if [ ${#stale[@]} -gt 0 ]; then
        warning "⚠️  Entorno desactualizado: $(_env_join "${stale[@]}") → ws env sync"
    fi
    if [ ${#unknown[@]} -gt 0 ]; then
        info "ℹ️  Entorno sin comprobar: $(_env_join "${unknown[@]}")"
    fi
    return 0
}

# PID de las sesiones vivas que declara WS_ENV_BUSY_CMD, sin el proceso que
# pregunta, sus antepasados ni sus descendientes
# Uso: env_live_sessions
# Retorna: 0 con los PID por stdout; 2 si WS_ENV_BUSY_CMD no está definida
env_live_sessions() {
    [ -n "$WS_ENV_BUSY_CMD" ] || return 2

    {
        sh -c "$WS_ENV_BUSY_CMD" 2>/dev/null | awk '$1 ~ /^[0-9]+$/ { print $1 }'
        echo "@@@"
        ps -eo pid=,ppid=
    } | exclude_own_process_tree
}

# Lee una respuesta y confirma solo con s o S
# Uso: env_confirm
env_confirm() {
    local answer
    read -r answer
    [ "$answer" = "s" ] || [ "$answer" = "S" ]
}
