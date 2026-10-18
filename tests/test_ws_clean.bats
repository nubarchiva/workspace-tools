#!/usr/bin/env bats
# Tests para ws-clean - Eliminar workspaces
#
# NOTA: Muchos tests estan marcados como skip porque ws-clean tiene dependencias
# fijas que impiden testing aislado.

load 'test_helper'

setup() {
    setup_test_environment
}

teardown() {
    stop_foreign_workers
    teardown_test_environment
}

# Helper para ejecutar ws-clean
run_ws_clean() {
    env WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT" \
        WORKSPACES_DIR="$TEST_WORKSPACES_DIR" \
        WS_TOOLS="$WS_TOOLS_ROOT" \
        "$WS_TOOLS_ROOT/bin/ws-clean" "$@"
}

# =============================================================================
# Tests que funcionan
# =============================================================================

@test "ws-clean: no args shows help" {
    run run_ws_clean
    [ "$status" -eq 1 ]
    [[ "$output" == *"Uso:"* ]] || [[ "$output" == *"ws clean"* ]]
}

@test "ws-clean: help mentions verificaciones" {
    run run_ws_clean
    [[ "$output" == *"cambios"* ]] || [[ "$output" == *"pendientes"* ]] || [[ "$output" == *"Ejemplo"* ]]
}

# =============================================================================
# Tests de integracion (requieren refactoring)
# =============================================================================

@test "ws-clean: nonexistent workspace fails" {
    run run_ws_clean "no-existe"
    [ "$status" -ne 0 ]
    [[ "$output" == *"no existe"* ]] || [[ "$output" == *"No se encontr"* ]]
}

@test "ws-clean: removes empty workspace" {
    mkdir -p "$TEST_WORKSPACES_DIR/vacio"

    # Simular confirmacion con subshell
    result=$(
        echo 's' | \
        WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT" \
        WORKSPACES_DIR="$TEST_WORKSPACES_DIR" \
        WS_TOOLS="$WS_TOOLS_ROOT" \
        "$WS_TOOLS_ROOT/bin/ws-clean" 'vacio' 2>&1
        echo "EXIT_CODE:$?"
    )
    local exit_code=$(echo "$result" | grep "EXIT_CODE:" | cut -d: -f2)
    [ "$exit_code" -eq 0 ]
    [ ! -d "$TEST_WORKSPACES_DIR/vacio" ]
}

@test "ws-clean: partial search works" {
    mkdir -p "$TEST_WORKSPACES_DIR/NUBA-8400-feature"

    # Buscar por "8400" con confirmacion
    result=$(
        echo 's' | \
        WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT" \
        WORKSPACES_DIR="$TEST_WORKSPACES_DIR" \
        WS_TOOLS="$WS_TOOLS_ROOT" \
        "$WS_TOOLS_ROOT/bin/ws-clean" '8400' 2>&1
        echo "EXIT_CODE:$?"
    )
    local exit_code=$(echo "$result" | grep "EXIT_CODE:" | cut -d: -f2)
    [ "$exit_code" -eq 0 ]
}

@test "ws-clean: warns about uncommitted changes" {
    mkdir -p "$TEST_WORKSPACES_DIR/con-cambios/mi-repo"

    # Crear repo con cambios
    cd "$TEST_WORKSPACES_DIR/con-cambios/mi-repo"
    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "inicial" > file.txt
    git add file.txt
    git commit -m "initial" --quiet
    echo "cambio" >> file.txt  # Cambio sin commitear
    cd - > /dev/null

    # Sin --force, ws clean pide confirmación: se responde que no, porque lo que se
    # comprueba es el aviso. Sin respuesta, la prueba espera para siempre a que
    # alguien conteste
    run run_ws_clean "con-cambios" <<< "n"
    [[ "$output" == *"cambios"* ]] || [[ "$output" == *"sin commitear"* ]]
}

@test "ws-clean: removes git worktrees" {
    # Este test verifica que git worktree prune se ejecuta
    # Requiere setup mas complejo con repo principal
    # Test simplificado: verificar que funciona con workspace sin repos
    mkdir -p "$TEST_WORKSPACES_DIR/worktree-test"

    run run_ws_clean "--force" "worktree-test"
    [ "$status" -eq 0 ]
}

@test "ws-clean: --force option skips confirmation" {
    mkdir -p "$TEST_WORKSPACES_DIR/force-test"

    run run_ws_clean "--force" "force-test"
    [ "$status" -eq 0 ]
    [ ! -d "$TEST_WORKSPACES_DIR/force-test" ]
}

# =============================================================================
# Tests de aislamiento Maven
# =============================================================================

@test "ws-clean: removes the maven head of the workspace" {
    mkdir -p "$TEST_WORKSPACES_DIR/con-head"
    mkdir -p "$WS_MAVEN_HEAD_BASE/con-head/repository/com/test"

    run run_ws_clean "--force" "con-head"
    [ "$status" -eq 0 ]
    [ ! -d "$WS_MAVEN_HEAD_BASE/con-head" ]
}

@test "ws-clean: workspace without maven head cleans normally" {
    mkdir -p "$TEST_WORKSPACES_DIR/sin-head"

    run run_ws_clean "--force" "sin-head"
    [ "$status" -eq 0 ]
    [ ! -d "$TEST_WORKSPACES_DIR/sin-head" ]
}

# =============================================================================
# Tests de procesos vivos dentro del workspace
# =============================================================================

# Arranca un proceso AJENO —reparentado a init, no descendiente de este test— con
# su directorio de trabajo dentro de una ruta
# Uso: start_foreign_worker <dir>
# Retorna: el PID por stdout
start_foreign_worker() {
    local dir="$1"
    local pidfile="$TEST_TEMP_DIR/foreign.$$.$RANDOM.pid"

    ( ( cd "$dir" && exec nohup sh -c 'echo $$ > "$0"; exec sleep 30' "$pidfile" >/dev/null 2>&1 ) & ) &

    local waited=0
    while [ ! -s "$pidfile" ] && [ $waited -lt 50 ]; do
        sleep 0.1
        waited=$((waited + 1))
    done

    cat "$pidfile" 2>/dev/null
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

@test "ws-clean: no elimina un workspace con un proceso trabajando dentro" {
    mkdir -p "$TEST_WORKSPACES_DIR/ocupado"
    local intruso=$(start_foreign_worker "$TEST_WORKSPACES_DIR/ocupado")
    [ -n "$intruso" ]

    run run_ws_clean "--force" "ocupado"
    stop_foreign_workers

    [ "$status" -ne 0 ]
    [ -d "$TEST_WORKSPACES_DIR/ocupado" ]
    [[ "$output" == *"PID $intruso"* ]]
}

@test "ws-clean: detecta los procesos de un subdirectorio del workspace" {
    mkdir -p "$TEST_WORKSPACES_DIR/ocupado-dentro/ks-nuba/src"
    local intruso=$(start_foreign_worker "$TEST_WORKSPACES_DIR/ocupado-dentro/ks-nuba/src")
    [ -n "$intruso" ]

    run run_ws_clean "--force" "ocupado-dentro"
    stop_foreign_workers

    [ "$status" -ne 0 ]
    [ -d "$TEST_WORKSPACES_DIR/ocupado-dentro/ks-nuba/src" ]
    [[ "$output" == *"PID $intruso  en ks-nuba/src"* ]]
}

@test "ws-clean: no elimina el workspace desde el que se lanza" {
    mkdir -p "$TEST_WORKSPACES_DIR/propio/ks-nuba"

    run bash -c 'cd "$1" && "$WS_TOOLS_ROOT/bin/ws-clean" --force propio' _ "$TEST_WORKSPACES_DIR/propio/ks-nuba"

    [ "$status" -ne 0 ]
    [ -d "$TEST_WORKSPACES_DIR/propio" ]
    [[ "$output" == *"Estás dentro del workspace"* ]]
}
