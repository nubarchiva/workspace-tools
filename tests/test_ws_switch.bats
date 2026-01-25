#!/usr/bin/env bats
# Tests para ws-switch
# Verifica el comportamiento del comando ws switch

load 'test_helper'

setup() {
    setup_test_environment
}

teardown() {
    teardown_test_environment
}

# =============================================================================
# Tests de ayuda y argumentos
# =============================================================================

@test "ws-switch: no args lists available workspaces" {
    # Crear un workspace de prueba
    mkdir -p "$TEST_WORKSPACES_DIR/test-workspace"

    run run_ws switch

    [ "$status" -eq 0 ]
    [[ "$output" == *"Workspaces disponibles"* ]]
    [[ "$output" == *"test-workspace"* ]]
}

@test "ws-switch: no args shows usage" {
    run run_ws switch

    [ "$status" -eq 0 ]
    [[ "$output" == *"Uso: ws switch"* ]]
}

@test "ws-switch: no workspaces shows appropriate message" {
    # No crear ningún workspace
    run run_ws switch

    [ "$status" -eq 0 ]
    [[ "$output" == *"Uso: ws switch"* ]]
}

# =============================================================================
# Tests de búsqueda de workspace
# =============================================================================

@test "ws-switch: nonexistent workspace fails with code 1" {
    run run_ws switch no-existe-xyz

    [ "$status" -eq 1 ]
    [[ "$output" == *"No se encontró"* ]] || [[ "$output" == *"no existe"* ]]
}

@test "ws-switch: nonexistent workspace shows available workspaces" {
    mkdir -p "$TEST_WORKSPACES_DIR/mi-workspace"

    run run_ws switch no-existe

    [ "$status" -eq 1 ]
    [[ "$output" == *"mi-workspace"* ]]
}

@test "ws-switch: exact match works" {
    mkdir -p "$TEST_WORKSPACES_DIR/mi-workspace"
    create_test_repo "mi-repo"

    # Crear worktree en el workspace
    cd "$TEST_WORKSPACE_ROOT/mi-repo"
    git worktree add "$TEST_WORKSPACES_DIR/mi-workspace/mi-repo" -b feature/mi-workspace 2>/dev/null || true
    cd - > /dev/null

    run run_ws switch mi-workspace

    [ "$status" -eq 0 ]
    [[ "$output" == *"mi-workspace"* ]]
}

@test "ws-switch: partial search finds unique workspace" {
    mkdir -p "$TEST_WORKSPACES_DIR/feature-NUBA-1234"

    run run_ws switch 1234

    # Debería encontrar el workspace (puede ser éxito o pedir selección)
    [[ "$output" == *"NUBA-1234"* ]] || [[ "$output" == *"feature-NUBA-1234"* ]]
}

@test "ws-switch: case-insensitive search" {
    mkdir -p "$TEST_WORKSPACES_DIR/MiWorkspace"

    run run_ws switch miwork

    [[ "$output" == *"MiWorkspace"* ]] || [[ "$output" == *"miworkspace"* ]]
}

# =============================================================================
# Tests de información mostrada
# =============================================================================

@test "ws-switch: shows header with workspace name" {
    mkdir -p "$TEST_WORKSPACES_DIR/test-ws"

    run run_ws switch test-ws

    [ "$status" -eq 0 ]
    [[ "$output" == *"test-ws"* ]]
}

@test "ws-switch: shows workspace path" {
    mkdir -p "$TEST_WORKSPACES_DIR/ruta-test"

    run run_ws switch ruta-test

    [ "$status" -eq 0 ]
    [[ "$output" == *"Ruta:"* ]]
    [[ "$output" == *"ruta-test"* ]]
}

@test "ws-switch: shows cd instructions" {
    mkdir -p "$TEST_WORKSPACES_DIR/cd-test"

    run run_ws switch cd-test

    [ "$status" -eq 0 ]
    [[ "$output" == *"Para trabajar aquí"* ]] || [[ "$output" == *"cd"* ]]
}

@test "ws-switch: empty workspace shows informative message" {
    mkdir -p "$TEST_WORKSPACES_DIR/vacio"

    run run_ws switch vacio

    [ "$status" -eq 0 ]
    [[ "$output" == *"No hay repos"* ]] || [[ "$output" == *"ws add"* ]]
}

# =============================================================================
# Tests con repos
# =============================================================================

@test "ws-switch: shows workspace repos" {
    mkdir -p "$TEST_WORKSPACES_DIR/con-repos"
    create_test_repo "repo-test"

    cd "$TEST_WORKSPACE_ROOT/repo-test"
    git worktree add "$TEST_WORKSPACES_DIR/con-repos/repo-test" -b feature/con-repos 2>/dev/null || true
    cd - > /dev/null

    run run_ws switch con-repos

    [ "$status" -eq 0 ]
    [[ "$output" == *"repo-test"* ]]
}

@test "ws-switch: shows branch of each repo" {
    mkdir -p "$TEST_WORKSPACES_DIR/branch-test"
    create_test_repo "mi-repo"

    cd "$TEST_WORKSPACE_ROOT/mi-repo"
    git worktree add "$TEST_WORKSPACES_DIR/branch-test/mi-repo" -b feature/branch-test 2>/dev/null || true
    cd - > /dev/null

    run run_ws switch branch-test

    [ "$status" -eq 0 ]
    [[ "$output" == *"Branch:"* ]]
    [[ "$output" == *"feature/branch-test"* ]]
}

@test "ws-switch: shows clean state when repo is clean" {
    mkdir -p "$TEST_WORKSPACES_DIR/limpio"
    create_test_repo "repo-limpio"

    cd "$TEST_WORKSPACE_ROOT/repo-limpio"
    git worktree add "$TEST_WORKSPACES_DIR/limpio/repo-limpio" -b feature/limpio 2>/dev/null || true
    cd - > /dev/null

    run run_ws switch limpio

    [ "$status" -eq 0 ]
    [[ "$output" == *"Sin cambios"* ]]
}

@test "ws-switch: shows warning when uncommitted changes" {
    mkdir -p "$TEST_WORKSPACES_DIR/con-cambios"
    create_test_repo "repo-cambios"

    cd "$TEST_WORKSPACE_ROOT/repo-cambios"
    git worktree add "$TEST_WORKSPACES_DIR/con-cambios/repo-cambios" -b feature/con-cambios 2>/dev/null || true
    cd - > /dev/null

    # Crear un archivo sin commitear en el worktree
    echo "cambio" > "$TEST_WORKSPACES_DIR/con-cambios/repo-cambios/nuevo.txt"

    run run_ws switch con-cambios

    [ "$status" -eq 0 ]
    [[ "$output" == *"Cambios sin commitear"* ]] || [[ "$output" == *"nuevo.txt"* ]]
}

# =============================================================================
# Tests de workspaces especiales
# =============================================================================

@test "ws-switch: master shows master branch" {
    mkdir -p "$TEST_WORKSPACES_DIR/master"
    create_test_repo "repo-master"

    cd "$TEST_WORKSPACE_ROOT/repo-master"
    git worktree add "$TEST_WORKSPACES_DIR/master/repo-master" master 2>/dev/null || true
    cd - > /dev/null

    run run_ws switch master

    [ "$status" -eq 0 ]
    [[ "$output" == *"master"* ]]
}

@test "ws-switch: develop shows develop branch" {
    mkdir -p "$TEST_WORKSPACES_DIR/develop"
    create_test_repo "repo-develop"

    cd "$TEST_WORKSPACE_ROOT/repo-develop"
    git branch develop 2>/dev/null || true
    git worktree add "$TEST_WORKSPACES_DIR/develop/repo-develop" develop 2>/dev/null || true
    cd - > /dev/null

    run run_ws switch develop

    [ "$status" -eq 0 ]
    [[ "$output" == *"develop"* ]]
}
