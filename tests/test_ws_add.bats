#!/usr/bin/env bats
# Tests para ws-add - Anadir repos a workspace
#
# NOTA: Muchos tests estan marcados como skip porque ws-add tiene dependencias
# fijas que impiden testing aislado.

load 'test_helper'

setup() {
    setup_test_environment
}

teardown() {
    teardown_test_environment
}

# Helper para ejecutar ws-add
run_ws_add() {
    env WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT" \
        WORKSPACES_DIR="$TEST_WORKSPACES_DIR" \
        WS_TOOLS="$WS_TOOLS_ROOT" \
        "$WS_TOOLS_ROOT/bin/ws-add" "$@"
}

# =============================================================================
# Tests que funcionan
# =============================================================================

@test "ws-add: no args shows help" {
    run run_ws_add
    [ "$status" -eq 1 ]
    [[ "$output" == *"Uso:"* ]] || [[ "$output" == *"ws add"* ]]
}

@test "ws-add: workspace without repo shows error" {
    run run_ws_add "mi-workspace"
    [ "$status" -eq 1 ]
}

@test "ws-add: help mentions repos in subdirectories" {
    run run_ws_add
    [[ "$output" == *"libs"* ]] || [[ "$output" == *"modules"* ]] || [[ "$output" == *"Ejemplo"* ]]
}

# =============================================================================
# Tests de integracion (requieren refactoring)
# =============================================================================

@test "ws-add: nonexistent workspace fails" {
    run run_ws_add "no-existe" "mi-repo"
    [ "$status" -ne 0 ]
}

@test "ws-add: adds repo to existing workspace" {
    # Crear workspace y repo
    mkdir -p "$TEST_WORKSPACES_DIR/mi-workspace"
    create_test_repo "mi-repo"

    run run_ws_add "mi-workspace" "mi-repo"
    [ "$status" -eq 0 ]
    [ -d "$TEST_WORKSPACES_DIR/mi-workspace/mi-repo" ]
}

@test "ws-add: adds multiple repos" {
    mkdir -p "$TEST_WORKSPACES_DIR/multi"
    create_test_repo "repo-a"
    create_test_repo "repo-b"

    run run_ws_add "multi" "repo-a" "repo-b"
    [ "$status" -eq 0 ]
    [ -d "$TEST_WORKSPACES_DIR/multi/repo-a" ]
    [ -d "$TEST_WORKSPACES_DIR/multi/repo-b" ]
}

@test "ws-add: repo in subdirectory keeps structure" {
    mkdir -p "$TEST_WORKSPACES_DIR/subdir-test"
    create_test_repo "libs/mi-lib"

    run run_ws_add "subdir-test" "libs/mi-lib"
    [ "$status" -eq 0 ]
    [ -d "$TEST_WORKSPACES_DIR/subdir-test/libs/mi-lib" ]
}

@test "ws-add: partial workspace search works" {
    mkdir -p "$TEST_WORKSPACES_DIR/NUBA-8400-feature"
    create_test_repo "mi-repo"

    # Buscar por "8400"
    run run_ws_add "8400" "mi-repo"
    [ "$status" -eq 0 ]
}

@test "ws-add: nonexistent repo shows warning" {
    mkdir -p "$TEST_WORKSPACES_DIR/warning-test"

    run run_ws_add "warning-test" "repo-fantasma"
    # No debe fallar completamente, pero debe advertir
    [[ "$output" == *"no encontrado"* ]] || [[ "$output" == *"saltando"* ]]
}

@test "ws-add: creates worktree on correct branch" {
    mkdir -p "$TEST_WORKSPACES_DIR/feature-123"
    create_test_repo "mi-repo"

    run run_ws_add "feature-123" "mi-repo"
    [ "$status" -eq 0 ]

    cd "$TEST_WORKSPACES_DIR/feature-123/mi-repo"
    branch=$(git branch --show-current)
    [ "$branch" = "feature/feature-123" ]
}

@test "ws-add: existing repo shows warning" {
    mkdir -p "$TEST_WORKSPACES_DIR/duplicate-test"
    create_test_repo "mi-repo"

    # Anadir una vez
    run_ws_add "duplicate-test" "mi-repo"

    # Intentar anadir de nuevo
    run run_ws_add "duplicate-test" "mi-repo"
    [[ "$output" == *"ya existe"* ]] || [[ "$output" == *"saltando"* ]]
}

@test "ws-add: workspace auto-detection works" {
    mkdir -p "$TEST_WORKSPACES_DIR/auto-detect"
    create_test_repo "nuevo-repo"

    # Ejecutar desde dentro del workspace
    # Usamos subshell con cd para preservar el directorio de trabajo
    result=$(
        cd "$TEST_WORKSPACES_DIR/auto-detect"
        WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT" \
        WORKSPACES_DIR="$TEST_WORKSPACES_DIR" \
        WS_TOOLS="$WS_TOOLS_ROOT" \
        "$WS_TOOLS_ROOT/bin/ws-add" "nuevo-repo" 2>&1
        echo "EXIT_CODE:$?"
    )
    local exit_code=$(echo "$result" | grep "EXIT_CODE:" | cut -d: -f2)
    [ "$exit_code" -eq 0 ]
}
