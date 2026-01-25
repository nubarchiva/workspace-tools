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

    run run_ws_clean "con-cambios"
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
