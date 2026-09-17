#!/bin/bash
# Utilidades para el manifiesto de repos origen (ws origins clone)
#
# El manifiesto declara qué repositorios forman el proyecto y dónde se clonan,
# de modo que una máquina recién instalada pueda poblar WORKSPACE_ROOT antes de
# que `ws new` tenga worktrees que crear.
#
# Formato (texto plano, cinco campos separados por espacios en blanco):
#
#   <destino>  <url>  [grupos]  [flags]  [motivo]
#
#   destino  Ruta relativa a WORKSPACE_ROOT. Admite anidamiento (libs/marc4j).
#            Es un campo propio porque el destino no siempre coincide con el
#            nombre del repositorio en la URL.
#   url      Cualquier URL que entienda git clone.
#   grupos   Lista separada por comas para clonar subconjuntos. '-' si no tiene.
#   flags    Lista separada por comas. Reconocido: 'manual'. '-' si no tiene.
#   motivo   Texto libre hasta fin de línea. Se muestra junto a los 'manual'.
#
# Las líneas vacías y las que empiezan por '#' se ignoran.
#
# Se pueden componer varios manifiestos (público + privado + personal): se
# cargan en orden y, a igualdad de destino, el último gana.

[[ -n "$_WS_MANIFEST_UTILS_LOADED" ]] && return 0
_WS_MANIFEST_UTILS_LOADED=1

# Separador interno de campos. Tabulador: no puede aparecer en un campo porque
# el parseo de la línea original separa por espacios en blanco.
_WS_MF_SEP=$'\t'

# Entradas cargadas, una por línea: destino\turl\tgrupos\tflags\tmotivo
# Se usa un único array de líneas (y nunca acceso por índice) para no depender
# de si los arrays son 0-indexados (bash) o 1-indexados (zsh).
MANIFEST_ENTRIES=()

# Vacía el manifiesto en memoria
manifest_reset() {
    MANIFEST_ENTRIES=()
}

# Devuelve el número de entradas cargadas
manifest_count() {
    echo "${#MANIFEST_ENTRIES[@]}"
}

# Extrae los campos de una entrada
# Uso: manifest_field <entrada> <dest|url|groups|flags|note>
manifest_field() {
    local entry="$1" field="$2"
    local dest url groups flags note
    IFS="$_WS_MF_SEP" read -r dest url groups flags note <<< "$entry"
    case "$field" in
        dest)   echo "$dest" ;;
        url)    echo "$url" ;;
        groups) echo "$groups" ;;
        flags)  echo "$flags" ;;
        note)   echo "$note" ;;
    esac
}

# Carga (y compone) un manifiesto sobre lo ya cargado.
# A igualdad de destino, la entrada nueva sustituye a la anterior.
# Uso: manifest_load_file <ruta>
# Retorna: 0 si se pudo leer, 1 si no existe o no es legible
manifest_load_file() {
    local file="$1"
    [[ -r "$file" ]] || return 1

    local line dest url groups flags note
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Comentarios y líneas en blanco
        line="${line%%$'\r'}"
        case "$line" in
            ''|'#'*) continue ;;
        esac
        [[ -z "${line// /}" ]] && continue

        # read con cinco variables deja el resto de la línea en la última:
        # así el motivo puede llevar espacios sin necesidad de comillas.
        read -r dest url groups flags note <<< "$line"

        # Una entrada sin URL está incompleta: se avisa y se ignora, en vez de
        # generar un git clone sin origen.
        if [[ -z "$url" ]]; then
            warning "⚠️  $(basename "$file"): entrada sin URL, ignorada: $dest" >&2
            continue
        fi

        [[ "$groups" == "-" || -z "$groups" ]] && groups=""
        [[ "$flags" == "-" || -z "$flags" ]] && flags=""
        [[ "$note" == "-" ]] && note=""

        _manifest_put "$dest" "$url" "$groups" "$flags" "$note"
    done < "$file"

    return 0
}

# Inserta o sustituye una entrada por destino (uso interno)
_manifest_put() {
    local dest="$1" url="$2" groups="$3" flags="$4" note="$5"
    local kept=() entry

    for entry in "${MANIFEST_ENTRIES[@]}"; do
        if [[ "$(manifest_field "$entry" dest)" != "$dest" ]]; then
            kept+=("$entry")
        fi
    done

    kept+=("${dest}${_WS_MF_SEP}${url}${_WS_MF_SEP}${groups}${_WS_MF_SEP}${flags}${_WS_MF_SEP}${note}")
    MANIFEST_ENTRIES=("${kept[@]}")
}

# ¿La entrada lleva ese flag?
# Uso: manifest_has_flag <entrada> <flag>
manifest_has_flag() {
    local entry="$1" flag="$2"
    local flags
    flags=$(manifest_field "$entry" flags)
    [[ -z "$flags" ]] && return 1

    local f
    local IFS=','
    for f in $flags; do
        [[ "$f" == "$flag" ]] && return 0
    done
    return 1
}

# ¿La entrada pertenece a alguno de los grupos seleccionados?
# Con selección vacía, toda entrada encaja.
# Uso: manifest_in_groups <entrada> <grupos_csv_seleccionados>
manifest_in_groups() {
    local entry="$1" selected="$2"
    [[ -z "$selected" ]] && return 0

    local groups
    groups=$(manifest_field "$entry" groups)
    [[ -z "$groups" ]] && return 1

    local g s
    local IFS=','
    for g in $groups; do
        for s in $selected; do
            [[ "$g" == "$s" ]] && return 0
        done
    done
    return 1
}

# Lista los grupos declarados en el manifiesto, sin repetir y ordenados
manifest_groups_list() {
    local entry groups
    for entry in "${MANIFEST_ENTRIES[@]}"; do
        groups=$(manifest_field "$entry" groups)
        [[ -z "$groups" ]] && continue
        echo "$groups" | tr ',' '\n'
    done | sort -u | grep -v '^$'
}

# Extrae el host de una URL de git (ssh://, https://, git://, o scp-like)
# Uso: manifest_url_host <url>
manifest_url_host() {
    local url="$1" rest
    case "$url" in
        *://*)
            rest="${url#*://}"
            rest="${rest#*@}"
            rest="${rest%%/*}"
            echo "${rest%%:*}"
            ;;
        *@*:*)
            rest="${url#*@}"
            echo "${rest%%:*}"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Extrae el puerto de una URL de git. Si no lo lleva explícito, devuelve el que
# corresponda al esquema: un https:// sin puerto es 443, no 22.
# Uso: manifest_url_port <url>
manifest_url_port() {
    local url="$1" rest hostport
    case "$url" in
        *://*)
            rest="${url#*://}"
            rest="${rest#*@}"
            hostport="${rest%%/*}"
            if [[ "$hostport" == *:* ]]; then
                echo "${hostport##*:}"
                return 0
            fi
            ;;
    esac

    case "$url" in
        https://*) echo "443" ;;
        http://*)  echo "80" ;;
        git://*)   echo "9418" ;;
        *)         echo "22" ;;
    esac
}

# Lista los hosts distintos de las entradas indicadas (una entrada por línea en
# stdin), con una URL representativa de cada uno: "host<TAB>url"
manifest_distinct_hosts() {
    local entry host url seen=""
    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        url=$(manifest_field "$entry" url)
        host=$(manifest_url_host "$url")
        [[ -z "$host" ]] && continue
        case "$seen" in
            *"|$host|"*) continue ;;
        esac
        seen="$seen|$host|"
        printf '%s\t%s\n' "$host" "$url"
    done
}

# Traduce el error de un git ls-remote / git clone a una causa accionable.
# Uso: manifest_diagnose <url> <texto_de_error>
# Imprime una explicación de varias líneas; siempre dice qué hacer.
manifest_diagnose() {
    local url="$1" err="$2"
    local host port
    host=$(manifest_url_host "$url")
    port=$(manifest_url_port "$url")
    # Una URL local (file://, ruta suelta) no tiene host que nombrar
    [[ -z "$host" ]] && host="$url"

    case "$(git_error_cause "$err")" in
        agent)
            echo "El agente SSH no ha firmado con la clave para '$host'."
            echo "Si el agente pide aprobación manual (Touch ID, confirmación), no puede hacerlo sin"
            echo "terminal; desbloquéalo o apruébalo y reintenta. Claves que ofrece el agente:"
            echo "    ssh-add -l"
            ;;
        dns)
            echo "El nombre '$host' no resuelve en esta máquina."
            echo "Comprueba el DNS de la red, o usa el nombre completo (FQDN) en el manifiesto"
            echo "en lugar de un alias que dependa de /etc/hosts."
            ;;
        hostkey)
            echo "La clave del host '$host' no está en ~/.ssh/known_hosts."
            echo "Regístrala y reintenta:"
            echo "    ssh-keyscan -p $port $host >> ~/.ssh/known_hosts"
            ;;
        publickey)
            echo "El servidor '$host' rechaza la clave de este usuario."
            echo "Comprueba que tu clave pública está dada de alta en '$host' y que el agente la ofrece:"
            echo "    ssh-add -l"
            ;;
        https-auth)
            echo "'$host' pide credenciales por HTTPS y no hay ninguna configurada."
            echo "Configura un credential helper, o usa la URL SSH de ese repositorio."
            ;;
        tls)
            echo "'$host' exige certificado de cliente o no valida su cadena TLS."
            echo "Este repositorio necesita configuración adicional: márcalo como 'manual' en el"
            echo "manifiesto para que quede fuera del clonado por defecto."
            ;;
        network)
            echo "No hay conexión con '$host' en el puerto $port."
            case "$url" in
                http://*|https://*)
                    echo "Si tu red exige proxy para salir a Internet, comprueba que"
                    echo "'http_proxy' y 'https_proxy' están definidas en este entorno."
                    ;;
                *)
                    echo "Comprueba que la red permite la salida a ese host y puerto (cortafuegos o proxy)."
                    ;;
            esac
            ;;
        *)
            echo "No se ha podido acceder a '$host'."
            [[ -n "$err" ]] && echo "Git respondió: $(echo "$err" | tail -n 3 | tr '\n' ' ')"
            ;;
    esac
}

# Comprueba el acceso a un remoto sin escribir nada ni pedir interacción.
# Uso: manifest_probe_remote <url>
# Retorna: 0 si el remoto responde; 1 si no (el error queda en MANIFEST_PROBE_ERR)
manifest_probe_remote() {
    local url="$1"
    MANIFEST_PROBE_ERR=""

    local err
    if err=$(GIT_TERMINAL_PROMPT=0 \
             GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=${WS_CLONE_TIMEOUT:-10}" \
             git ls-remote "$url" 2>&1 >/dev/null); then
        return 0
    fi

    MANIFEST_PROBE_ERR="$err"
    return 1
}
