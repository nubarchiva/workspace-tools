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

@test "ws-add: sin argumentos muestra ayuda" {
    run run_ws_add
    [ "$status" -eq 1 ]
    [[ "$output" == *"Uso:"* ]] || [[ "$output" == *"ws add"* ]]
}

@test "ws-add: solo workspace sin repo muestra error" {
    run run_ws_add "mi-workspace"
    [ "$status" -eq 1 ]
}

@test "ws-add: ayuda menciona repos en subdirectorios" {
    run run_ws_add
    [[ "$output" == *"libs"* ]] || [[ "$output" == *"modules"* ]] || [[ "$output" == *"Ejemplo"* ]]
}

# =============================================================================
# Tests de integracion (requieren refactoring)
# =============================================================================

@test "ws-add: workspace inexistente falla" {
    skip "Requiere que ws-add use WORKSPACE_ROOT del entorno"
    run run_ws_add "no-existe" "mi-repo"
    [ "$status" -ne 0 ]
}

@test "ws-add: anade repo a workspace existente" {
    skip "Requiere que ws-add use WORKSPACE_ROOT del entorno"
    # Crear workspace y repo
    mkdir -p "$TEST_WORKSPACES_DIR/mi-workspace"
    create_test_repo "mi-repo"

    run run_ws_add "mi-workspace" "mi-repo"
    [ "$status" -eq 0 ]
    [ -d "$TEST_WORKSPACES_DIR/mi-workspace/mi-repo" ]
}

@test "ws-add: anade multiples repos" {
    skip "Requiere que ws-add use WORKSPACE_ROOT del entorno"
    mkdir -p "$TEST_WORKSPACES_DIR/multi"
    create_test_repo "repo-a"
    create_test_repo "repo-b"

    run run_ws_add "multi" "repo-a" "repo-b"
    [ "$status" -eq 0 ]
    [ -d "$TEST_WORKSPACES_DIR/multi/repo-a" ]
    [ -d "$TEST_WORKSPACES_DIR/multi/repo-b" ]
}

@test "ws-add: repo en subdirectorio mantiene estructura" {
    skip "Requiere que ws-add use WORKSPACE_ROOT del entorno"
    mkdir -p "$TEST_WORKSPACES_DIR/subdir-test"
    create_test_repo "libs/mi-lib"

    run run_ws_add "subdir-test" "libs/mi-lib"
    [ "$status" -eq 0 ]
    [ -d "$TEST_WORKSPACES_DIR/subdir-test/libs/mi-lib" ]
}

@test "ws-add: busqueda parcial de workspace funciona" {
    skip "Requiere que ws-add use WORKSPACE_ROOT del entorno"
    mkdir -p "$TEST_WORKSPACES_DIR/NUBA-8400-feature"
    create_test_repo "mi-repo"

    # Buscar por "8400"
    run run_ws_add "8400" "mi-repo"
    [ "$status" -eq 0 ]
}

@test "ws-add: repo inexistente muestra warning" {
    skip "Requiere que ws-add use WORKSPACE_ROOT del entorno"
    mkdir -p "$TEST_WORKSPACES_DIR/warning-test"

    run run_ws_add "warning-test" "repo-fantasma"
    # No debe fallar completamente, pero debe advertir
    [[ "$output" == *"no encontrado"* ]] || [[ "$output" == *"saltando"* ]]
}

@test "ws-add: crea worktree en la branch correcta" {
    skip "Requiere que ws-add use WORKSPACE_ROOT del entorno"
    mkdir -p "$TEST_WORKSPACES_DIR/feature-123"
    create_test_repo "mi-repo"

    run run_ws_add "feature-123" "mi-repo"
    [ "$status" -eq 0 ]

    cd "$TEST_WORKSPACES_DIR/feature-123/mi-repo"
    branch=$(git branch --show-current)
    [ "$branch" = "feature/feature-123" ]
}

@test "ws-add: repo ya existente muestra warning" {
    skip "Requiere que ws-add use WORKSPACE_ROOT del entorno"
    mkdir -p "$TEST_WORKSPACES_DIR/duplicate-test"
    create_test_repo "mi-repo"

    # Anadir una vez
    run_ws_add "duplicate-test" "mi-repo"

    # Intentar anadir de nuevo
    run run_ws_add "duplicate-test" "mi-repo"
    [[ "$output" == *"ya existe"* ]] || [[ "$output" == *"saltando"* ]]
}

@test "ws-add: auto-deteccion de workspace funciona" {
    skip "Requiere que ws-add use WORKSPACE_ROOT del entorno"
    mkdir -p "$TEST_WORKSPACES_DIR/auto-detect"
    create_test_repo "nuevo-repo"

    # Ejecutar desde dentro del workspace
    cd "$TEST_WORKSPACES_DIR/auto-detect"
    run run_ws_add "nuevo-repo"
    [ "$status" -eq 0 ]
}
