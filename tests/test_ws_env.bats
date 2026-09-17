#!/usr/bin/env bats
# Tests para los repositorios de entorno (ws-env-utils.sh y ws env)
#
# Los remotos son repositorios locales: las pruebas no tocan la red.

load 'test_helper'

setup() {
    setup_test_environment
    unset WS_ENV_REPOS WS_ENV_BUSY_CMD WS_ENV_FETCH_TTL WS_ENV_FETCH_TIMEOUT WS_OFFLINE
    REMOTES="$TEST_TEMP_DIR/remotes"
    mkdir -p "$REMOTES"
    source "$WS_TOOLS_ROOT/bin/ws-colors.sh"
    source "$WS_TOOLS_ROOT/bin/ws-common.sh"
    source "$WS_TOOLS_ROOT/bin/ws-git-utils.sh"
    source "$WS_TOOLS_ROOT/bin/ws-manifest-utils.sh"
    source "$WS_TOOLS_ROOT/bin/ws-env-utils.sh"
}

teardown() {
    stop_foreign_workers
    teardown_test_environment
}

# Crea un remoto con un commit y lo clona en WORKSPACE_ROOT/<nombre>
# Uso: create_env_repo <nombre>
create_env_repo() {
    local name="$1"
    local remote="$REMOTES/$name.git"
    local publisher="$TEST_TEMP_DIR/pub-$name"

    git init --quiet --bare --initial-branch=main "$remote"
    git init --quiet --initial-branch=main "$publisher"
    git -C "$publisher" config user.email "test@test.com"
    git -C "$publisher" config user.name "Test User"
    echo "# $name" > "$publisher/README.md"
    git -C "$publisher" add README.md
    git -C "$publisher" commit --quiet -m "Initial commit"
    git -C "$publisher" remote add origin "$remote"
    git -C "$publisher" push --quiet -u origin main

    git clone --quiet "$remote" "$TEST_WORKSPACE_ROOT/$name"
    git -C "$TEST_WORKSPACE_ROOT/$name" config user.email "test@test.com"
    git -C "$TEST_WORKSPACE_ROOT/$name" config user.name "Test User"
}

# Publica un commit nuevo en el remoto de un repositorio de entorno
# Uso: publish_commit <nombre> <fichero>
publish_commit() {
    local publisher="$TEST_TEMP_DIR/pub-$1"
    echo "$RANDOM" > "$publisher/$2"
    git -C "$publisher" add "$2"
    git -C "$publisher" commit --quiet -m "Cambia $2"
    git -C "$publisher" push --quiet origin main
}

# Crea un commit local sin publicar en el clon de un repositorio de entorno
local_commit() {
    local clone="$TEST_WORKSPACE_ROOT/$1"
    echo "$RANDOM" > "$clone/local.txt"
    git -C "$clone" add local.txt
    git -C "$clone" commit --quiet -m "Commit local"
}

head_of() {
    git -C "$1" rev-parse HEAD
}

run_env() {
    env WS_CONFIG_FILE=/dev/null \
        WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT" \
        WORKSPACES_DIR="$TEST_WORKSPACES_DIR" \
        WS_TOOLS="$WS_TOOLS_ROOT" \
        "$WS_TOOLS_ROOT/bin/ws-env" "$@" </dev/null
}

# Arranca un proceso ajeno al test (reparentado a init) y deja su PID en un fichero
# Uso: start_foreign_worker; imprime la ruta del fichero con el PID
start_foreign_worker() {
    local pidfile="$TEST_TEMP_DIR/foreign.$RANDOM.pid"
    ( ( exec nohup sh -c 'echo $$ > "$0"; exec sleep 30' "$pidfile" >/dev/null 2>&1 ) & ) &

    local waited=0
    while [ ! -s "$pidfile" ] && [ $waited -lt 50 ]; do
        sleep 0.1
        waited=$((waited + 1))
    done
    echo "$pidfile"
}

stop_foreign_workers() {
    local pidfile pid
    for pidfile in "$TEST_TEMP_DIR"/foreign.*.pid; do
        [ -f "$pidfile" ] || continue
        pid=$(cat "$pidfile" 2>/dev/null)
        [ -n "$pid" ] && kill "$pid" 2>/dev/null
    done
    return 0
}

# =============================================================================
# Declaración de los repositorios
# =============================================================================

@test "env_repo_entries: resuelve rutas relativas, absolutas y con ~" {
    WS_ENV_REPOS="uno:/opt/dos: ~/tres :~"

    run env_repo_entries

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "uno	$TEST_WORKSPACE_ROOT/uno" ]
    [ "${lines[1]}" = "/opt/dos	/opt/dos" ]
    [ "${lines[2]}" = "~/tres	$HOME/tres" ]
    [ "${lines[3]}" = "~	$HOME" ]
}

@test "env_drift_warning: sin WS_ENV_REPOS no dice nada" {
    run env_drift_warning

    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# =============================================================================
# Aviso de desfase
# =============================================================================

@test "env_drift_warning: repositorio al día no dice nada" {
    create_env_repo skills
    WS_ENV_REPOS="skills"

    run env_drift_warning

    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "env_drift_warning: repositorio por detrás avisa con los commits que faltan" {
    create_env_repo skills
    publish_commit skills a.txt
    publish_commit skills b.txt
    WS_ENV_REPOS="skills"

    run env_drift_warning

    [[ "$output" == *"Entorno desactualizado"* ]]
    [[ "$output" == *"skills ↓2"* ]]
    [[ "$output" == *"ws env sync"* ]]
}

@test "env_drift_warning: repositorio divergido avisa" {
    create_env_repo skills
    publish_commit skills a.txt
    local_commit skills
    WS_ENV_REPOS="skills"

    run env_drift_warning

    [[ "$output" == *"skills divergido"* ]]
}

@test "env_drift_warning: divergido sin contenido local pendiente lo dice" {
    create_env_repo skills
    local_commit skills
    # El mismo cambio llega al remoto con otro hash (un cherry-pick ya publicado)
    cp "$TEST_WORKSPACE_ROOT/skills/local.txt" "$TEST_TEMP_DIR/pub-skills/local.txt"
    git -C "$TEST_TEMP_DIR/pub-skills" add local.txt
    git -C "$TEST_TEMP_DIR/pub-skills" commit --quiet -m "Mismo cambio, otro commit"
    git -C "$TEST_TEMP_DIR/pub-skills" push --quiet origin main
    WS_ENV_REPOS="skills"

    run env_drift_warning

    [[ "$output" == *"skills divergido (↑1 ↓1, sin contenido local pendiente)"* ]]
}

@test "env_drift_warning: divergido con contenido local pendiente no lo oculta" {
    create_env_repo skills
    publish_commit skills a.txt
    local_commit skills
    WS_ENV_REPOS="skills"

    run env_drift_warning

    [[ "$output" == *"skills divergido (↑1 ↓1)"* ]]
    [[ "$output" != *"sin contenido local pendiente"* ]]
}

@test "ws env status: commits locales ya publicados con otro hash no cuentan como sin publicar" {
    create_env_repo skills
    local_commit skills
    cp "$TEST_WORKSPACE_ROOT/skills/local.txt" "$TEST_TEMP_DIR/pub-skills/local.txt"
    git -C "$TEST_TEMP_DIR/pub-skills" add local.txt
    git -C "$TEST_TEMP_DIR/pub-skills" commit --quiet -m "Mismo cambio, otro commit"
    git -C "$TEST_TEMP_DIR/pub-skills" push --quiet origin main
    # Tras mergear el remoto, el commit original queda por delante aunque su cambio ya esté publicado
    git -C "$TEST_WORKSPACE_ROOT/skills" pull --quiet --no-rebase --no-edit
    [ "$(git -C "$TEST_WORKSPACE_ROOT/skills" rev-list --count '@{u}..HEAD')" -gt 0 ]

    WS_ENV_REPOS="skills" run run_env status

    [ "$status" -eq 0 ]
    [[ "$output" == *"al día, sin contenido local pendiente"* ]]
    [[ "$output" != *"sin publicar"* ]]
}

@test "env_drift_warning: commits locales sin publicar no son desfase" {
    create_env_repo skills
    local_commit skills
    WS_ENV_REPOS="skills"

    run env_drift_warning

    [ -z "$output" ]
}

@test "env_drift_warning: ruta inexistente se informa como sin comprobar" {
    WS_ENV_REPOS="fantasma"

    run env_drift_warning

    [[ "$output" == *"Entorno sin comprobar"* ]]
    [[ "$output" == *"fantasma (no existe)"* ]]
}

@test "env_drift_warning: directorio que no es git se informa como sin comprobar" {
    mkdir -p "$TEST_WORKSPACE_ROOT/plano"
    WS_ENV_REPOS="plano"

    run env_drift_warning

    [[ "$output" == *"plano (no es un repositorio git)"* ]]
}

@test "env_drift_warning: subdirectorio de un repositorio no se trata como repositorio" {
    create_env_repo claude
    mkdir -p "$TEST_WORKSPACE_ROOT/claude/skills"
    WS_ENV_REPOS="claude/skills"

    run env_drift_warning

    [[ "$output" == *"claude/skills (no es la raíz de un repositorio git)"* ]]
}

@test "env_drift_warning: rama sin seguimiento se informa como sin comprobar" {
    create_env_repo skills
    git -C "$TEST_WORKSPACE_ROOT/skills" checkout --quiet -b suelta
    WS_ENV_REPOS="skills"

    run env_drift_warning

    [[ "$output" == *"skills (sin rama de seguimiento)"* ]]
}

@test "env_drift_warning: modo offline se informa como sin comprobar" {
    create_env_repo skills
    publish_commit skills a.txt
    WS_ENV_REPOS="skills"
    WS_OFFLINE=1

    run env_drift_warning

    [[ "$output" == *"skills (modo offline)"* ]]
    [[ "$output" != *"desactualizado"* ]]
}

@test "env_drift_warning: remoto inalcanzable se informa como sin comprobar" {
    create_env_repo skills
    git -C "$TEST_WORKSPACE_ROOT/skills" remote set-url origin "$TEST_TEMP_DIR/no-existe.git"
    WS_ENV_REPOS="skills"

    run env_drift_warning

    [[ "$output" == *"skills (fetch fallido)"* ]]
}

# Hace que el fetch de un repositorio falle con el error indicado en stderr
# Uso: fail_fetch_with <nombre> <mensaje>
fail_fetch_with() {
    local fake="$TEST_TEMP_DIR/upload-pack-$1"
    printf '#!/bin/sh\ncat >&2 <<"ERR"\n%s\nERR\nexit 1\n' "$2" > "$fake"
    chmod +x "$fake"
    git -C "$TEST_WORKSPACE_ROOT/$1" config remote.origin.uploadpack "$fake"
}

@test "env_drift_warning: distingue el agente SSH que no firma" {
    create_env_repo skills
    fail_fetch_with skills 'sign_and_send_pubkey: signing failed for ECDSA "id" from agent: agent refused operation
git@github.com: Permission denied (publickey).'
    WS_ENV_REPOS="skills"

    run env_drift_warning

    [[ "$output" == *"skills (el agente SSH no ha firmado)"* ]]
}

@test "env_drift_warning: distingue el nombre de servidor que no resuelve" {
    create_env_repo skills
    fail_fetch_with skills 'ssh: Could not resolve hostname srv: nodename nor servname provided, or not known'
    WS_ENV_REPOS="skills"

    run env_drift_warning

    [[ "$output" == *"skills (el nombre del servidor no resuelve)"* ]]
}

@test "env_drift_warning: un fetch fallido no cuenta como reciente para el TTL" {
    create_env_repo skills
    git -C "$TEST_WORKSPACE_ROOT/skills" remote set-url origin "$TEST_TEMP_DIR/no-existe.git"
    # git refresca FETCH_HEAD al empezar un fetch aunque después falle
    touch "$TEST_WORKSPACE_ROOT/skills/.git/FETCH_HEAD"
    WS_ENV_REPOS="skills"
    WS_ENV_FETCH_TTL=3600

    run env_drift_warning

    [[ "$output" == *"skills (fetch fallido)"* ]]
}

@test "env_drift_warning: un fetch que agota el tiempo de espera lo dice" {
    command -v timeout >/dev/null 2>&1 || skip "sin la orden timeout"
    create_env_repo skills
    local slow="$TEST_TEMP_DIR/git-lento"
    mkdir -p "$slow"
    printf '#!/bin/sh\nsleep 5\n' > "$slow/git-upload-pack"
    chmod +x "$slow/git-upload-pack"
    git -C "$TEST_WORKSPACE_ROOT/skills" config remote.origin.uploadpack "$slow/git-upload-pack"
    WS_ENV_REPOS="skills"
    WS_ENV_FETCH_TIMEOUT=1

    run env_drift_warning

    [[ "$output" == *"skills (sin respuesta del remoto en 1 s)"* ]]
}

@test "env_drift_warning: desfase ya conocido se avisa aunque el fetch falle" {
    create_env_repo skills
    publish_commit skills a.txt
    git -C "$TEST_WORKSPACE_ROOT/skills" fetch --quiet
    git -C "$TEST_WORKSPACE_ROOT/skills" remote set-url origin "$TEST_TEMP_DIR/no-existe.git"
    WS_ENV_REPOS="skills"
    WS_ENV_FETCH_TTL=0

    run env_drift_warning

    [[ "$output" == *"skills ↓1"* ]]
    [[ "$output" != *"sin comprobar"* ]]
}

@test "env_drift_warning: dentro del TTL no repite el fetch" {
    create_env_repo skills
    WS_ENV_REPOS="skills"
    WS_ENV_FETCH_TTL=3600
    run env_drift_warning
    publish_commit skills a.txt

    run env_drift_warning
    [ -z "$output" ]

    WS_ENV_FETCH_TTL=0
    run env_drift_warning
    [[ "$output" == *"skills ↓1"* ]]
}

@test "env_drift_warning: nombra todos los repositorios afectados en una línea" {
    create_env_repo skills
    create_env_repo gestion
    publish_commit skills a.txt
    publish_commit gestion b.txt
    WS_ENV_REPOS="skills:gestion"

    run env_drift_warning

    [ "${#lines[@]}" -eq 1 ]
    [[ "$output" == *"skills ↓1, gestion ↓1"* ]]
}

# =============================================================================
# ws env status
# =============================================================================

@test "ws env: sin WS_ENV_REPOS explica cómo declararlos" {
    run run_env

    [ "$status" -eq 0 ]
    [[ "$output" == *"WS_ENV_REPOS"* ]]
}

@test "ws env status: muestra hash y fecha del último commit y sale con 0 si todo está al día" {
    create_env_repo skills
    WS_ENV_REPOS="skills"
    local hash=$(git -C "$TEST_WORKSPACE_ROOT/skills" log -1 --format=%h)
    local date=$(git -C "$TEST_WORKSPACE_ROOT/skills" log -1 --format=%cd --date=format:%Y-%m-%d)

    WS_ENV_REPOS="skills" run run_env status

    [ "$status" -eq 0 ]
    [[ "$output" == *"skills"*"al día"* ]]
    [[ "$output" == *"$hash $date"* ]]
}

@test "ws env status: sale con 1 si alguno va por detrás" {
    create_env_repo skills
    publish_commit skills a.txt

    WS_ENV_REPOS="skills" run run_env status

    [ "$status" -eq 1 ]
    [[ "$output" == *"↓1"* ]]
}

@test "ws env status: sale con 1 si alguno no se ha podido comprobar" {
    WS_ENV_REPOS="fantasma" run run_env status

    [ "$status" -eq 1 ]
    [[ "$output" == *"sin comprobar: no existe"* ]]
}

@test "ws env status --no-fetch: no consulta el remoto" {
    create_env_repo skills
    publish_commit skills a.txt

    WS_ENV_REPOS="skills" run run_env status --no-fetch

    [ "$status" -eq 0 ]
    [[ "$output" == *"al día"* ]]
}

@test "ws env status: no escribe en el árbol de trabajo" {
    create_env_repo skills
    publish_commit skills a.txt
    local before=$(head_of "$TEST_WORKSPACE_ROOT/skills")

    WS_ENV_REPOS="skills" run run_env status

    [ "$(head_of "$TEST_WORKSPACE_ROOT/skills")" = "$before" ]
}

# =============================================================================
# ws env sync
# =============================================================================

@test "ws env sync: avanza por fast-forward e informa de commits y ficheros" {
    create_env_repo skills
    local before=$(git -C "$TEST_WORKSPACE_ROOT/skills" rev-parse --short HEAD)
    publish_commit skills uno.md
    publish_commit skills dos.md

    WS_ENV_REPOS="skills" run run_env sync

    [ "$status" -eq 0 ]
    [ "$(head_of "$TEST_WORKSPACE_ROOT/skills")" = "$(git -C "$REMOTES/skills.git" rev-parse main)" ]
    local after=$(git -C "$TEST_WORKSPACE_ROOT/skills" rev-parse --short HEAD)
    [[ "$output" == *"$before..$after"* ]]
    [[ "$output" == *"2 commit(s)"* ]]
    [[ "$output" == *"uno.md"* ]]
    [[ "$output" == *"dos.md"* ]]
}

@test "ws env sync: termina con el hash y la fecha de cada repositorio" {
    create_env_repo skills
    publish_commit skills uno.md

    WS_ENV_REPOS="skills" run run_env sync

    local hash=$(git -C "$REMOTES/skills.git" log -1 --format=%h main)
    [[ "${lines[${#lines[@]}-1]}" == *"skills"*"$hash"* ]]
}

@test "ws env sync: repositorio divergido falla sin mezclar" {
    create_env_repo skills
    publish_commit skills a.txt
    local_commit skills
    local before=$(head_of "$TEST_WORKSPACE_ROOT/skills")

    WS_ENV_REPOS="skills" run run_env sync

    [ "$status" -eq 1 ]
    [ "$(head_of "$TEST_WORKSPACE_ROOT/skills")" = "$before" ]
    [[ "$output" == *"divergido"* ]]
}

@test "ws env sync: un repositorio que no es git no impide sincronizar los demás" {
    mkdir -p "$TEST_WORKSPACE_ROOT/plano"
    create_env_repo skills
    publish_commit skills a.txt

    WS_ENV_REPOS="plano:skills" run run_env sync

    [ "$status" -eq 1 ]
    [ "$(head_of "$TEST_WORKSPACE_ROOT/skills")" = "$(git -C "$REMOTES/skills.git" rev-parse main)" ]
    [[ "$output" == *"no es un repositorio git"* ]]
}

@test "ws env sync: sin nada que actualizar lo dice" {
    create_env_repo skills

    WS_ENV_REPOS="skills" run run_env sync

    [ "$status" -eq 0 ]
    [[ "$output" == *"Nada que actualizar"* ]]
}

@test "ws env sync: sin WS_ENV_BUSY_CMD avisa de que no puede detectar sesiones vivas" {
    create_env_repo skills
    publish_commit skills a.txt

    WS_ENV_REPOS="skills" run run_env sync

    [[ "$output" == *"WS_ENV_BUSY_CMD"* ]]
}

@test "ws env sync: con sesiones vivas y sin terminal cancela salvo --yes" {
    create_env_repo skills
    publish_commit skills a.txt
    local pidfile=$(start_foreign_worker)
    local before=$(head_of "$TEST_WORKSPACE_ROOT/skills")

    WS_ENV_REPOS="skills" WS_ENV_BUSY_CMD="cat $pidfile" run run_env sync

    [ "$status" -eq 1 ]
    [ "$(head_of "$TEST_WORKSPACE_ROOT/skills")" = "$before" ]
    [[ "$output" == *"1 sesión(es) viva(s)"* ]]
    [[ "$output" == *"--yes"* ]]
}

@test "ws env sync --yes: con sesiones vivas avisa y actualiza" {
    create_env_repo skills
    publish_commit skills a.txt
    local pidfile=$(start_foreign_worker)

    WS_ENV_REPOS="skills" WS_ENV_BUSY_CMD="cat $pidfile" run run_env sync --yes

    [ "$status" -eq 0 ]
    [ "$(head_of "$TEST_WORKSPACE_ROOT/skills")" = "$(git -C "$REMOTES/skills.git" rev-parse main)" ]
    [[ "$output" == *"1 sesión(es) viva(s)"* ]]
}

@test "ws env sync --sessions: lista las sesiones vivas" {
    create_env_repo skills
    publish_commit skills a.txt
    local pidfile=$(start_foreign_worker)
    local pid=$(cat "$pidfile")

    WS_ENV_REPOS="skills" WS_ENV_BUSY_CMD="cat $pidfile" run run_env sync --sessions

    [[ "$output" == *"$pid"*"sleep 30"* ]]
}

@test "ws env sync: la sesión que lanza la orden no cuenta como viva" {
    create_env_repo skills
    publish_commit skills a.txt

    # sh -c imprime su propio PID: un descendiente de quien lanza la orden
    WS_ENV_REPOS="skills" WS_ENV_BUSY_CMD='echo $$; echo $PPID' run run_env sync

    [ "$status" -eq 0 ]
    [[ "$output" != *"sesión(es) viva(s)"* ]]
}

@test "ws env sync: los antepasados de quien lanza la orden no cuentan como vivos" {
    create_env_repo skills
    publish_commit skills a.txt

    # $$ es el shell de este test, antepasado del ws env que se ejecuta
    WS_ENV_REPOS="skills" WS_ENV_BUSY_CMD="echo $$" run run_env sync

    [ "$status" -eq 0 ]
    [[ "$output" != *"sesión(es) viva(s)"* ]]
}

@test "ws env sync: con sesiones vivas pero nada que actualizar no pregunta" {
    create_env_repo skills
    local pidfile=$(start_foreign_worker)

    WS_ENV_REPOS="skills" WS_ENV_BUSY_CMD="cat $pidfile" run run_env sync

    [ "$status" -eq 0 ]
    [[ "$output" != *"sesión(es) viva(s)"* ]]
}

@test "env_confirm: solo una s confirma" {
    run env_confirm <<< "s"
    [ "$status" -eq 0 ]

    run env_confirm <<< "S"
    [ "$status" -eq 0 ]

    run env_confirm <<< ""
    [ "$status" -eq 1 ]

    run env_confirm <<< "n"
    [ "$status" -eq 1 ]

    run env_confirm <<< "si"
    [ "$status" -eq 1 ]
}

@test "ws env: opción desconocida falla" {
    run run_env status --que-es-esto

    [ "$status" -eq 1 ]
    [[ "$output" == *"desconocida"* ]]
}

# =============================================================================
# Integración con ws status, ws switch y el dispatcher
# =============================================================================

@test "ws status: muestra el apartado Entorno con el estado de cada repositorio" {
    create_env_repo skills
    publish_commit skills a.txt
    mkdir -p "$TEST_WORKSPACES_DIR/feat"

    WS_ENV_REPOS="skills" run run_ws status feat

    [[ "$output" == *"Entorno"* ]]
    [[ "$output" == *"skills"*"↓1"* ]]
}

@test "ws switch: avisa en una línea del desfase" {
    create_env_repo skills
    publish_commit skills a.txt
    mkdir -p "$TEST_WORKSPACES_DIR/feat"

    WS_ENV_REPOS="skills" run run_ws switch feat

    [[ "$output" == *"Entorno desactualizado: skills ↓1"* ]]
}

@test "ws switch: con WS_ENV_NO_WARN no calcula el aviso" {
    create_env_repo skills
    publish_commit skills a.txt
    mkdir -p "$TEST_WORKSPACES_DIR/feat"

    WS_ENV_REPOS="skills" WS_ENV_NO_WARN=1 run run_ws switch feat

    [[ "$output" != *"Entorno"* ]]
}

@test "ws env --warn: imprime solo el aviso" {
    create_env_repo skills
    publish_commit skills a.txt

    WS_ENV_REPOS="skills" run run_env --warn

    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [[ "$output" == *"Entorno desactualizado: skills ↓1"* ]]
}

@test "ws: el dispatcher resuelve env e i sigue siendo info" {
    WS_ENV_REPOS="" run run_ws env

    [ "$status" -eq 0 ]
    [[ "$output" == *"WS_ENV_REPOS"* ]]

    run run_ws i --help
    [[ "$output" == *"Uso: ws info"* ]]
}
