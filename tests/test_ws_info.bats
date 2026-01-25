#!/usr/bin/env bats
# Tests para ws-info
# Verifica el comportamiento del comando ws info
# Diferencia clave con ws-switch: auto-deteccion de workspace

load 'test_helper'

setup() {
    setup_test_environment
}

teardown() {
    teardown_test_environment
}

# =============================================================================
# Tests de ayuda
# =============================================================================

@test "ws-info: -h shows help" {
    run run_ws info -h

    [ "$status" -eq 0 ]
    [[ "$output" == *"Uso: ws info"* ]]
    [[ "$output" == *"auto-detecta"* ]]
}

@test "ws-info: --help shows help" {
    run run_ws info --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Uso: ws info"* ]]
}

@test "ws-info: help mentions examples" {
    run run_ws info --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Ejemplos"* ]]
    [[ "$output" == *"ws info"* ]]
}

# =============================================================================
# Tests de auto-deteccion (diferencia clave con ws-switch)
# =============================================================================

@test "ws-info: no args outside workspace lists available" {
    mkdir -p "$TEST_WORKSPACES_DIR/workspace-disponible"

    # Ejecutar desde fuera del workspace
    cd "$TEST_WORKSPACE_ROOT"
    run run_ws info

    [ "$status" -eq 0 ]
    [[ "$output" == *"Workspaces disponibles"* ]]
    [[ "$output" == *"workspace-disponible"* ]]
}

@test "ws-info: no args outside workspace shows correct usage" {
    run run_ws info

    [ "$status" -eq 0 ]
    # Debe mostrar "ws info" no "ws switch"
    [[ "$output" == *"ws info"* ]]
}

# Nota: El test de auto-deteccion dentro de workspace requiere
# simular estar dentro de un workspace, lo cual es complejo con el
# helper actual. Se marca como skip por ahora.
@test "ws-info: auto-detects workspace from inside" {
    skip "Requiere refactoring de detect_current_workspace para ser testeable"

    mkdir -p "$TEST_WORKSPACES_DIR/auto-detect"
    create_test_repo "repo-auto"

    cd "$TEST_WORKSPACE_ROOT/repo-auto"
    git worktree add "$TEST_WORKSPACES_DIR/auto-detect/repo-auto" -b feature/auto-detect 2>/dev/null || true
    cd - > /dev/null

    # Simular estar dentro del workspace
    cd "$TEST_WORKSPACES_DIR/auto-detect"
    run run_ws info

    [ "$status" -eq 0 ]
    [[ "$output" == *"Workspace detectado"* ]]
    [[ "$output" == *"auto-detect"* ]]
}

# =============================================================================
# Tests de busqueda de workspace (igual que ws-switch)
# =============================================================================

@test "ws-info: nonexistent workspace fails with code 1" {
    run run_ws info no-existe-xyz

    [ "$status" -eq 1 ]
    [[ "$output" == *"No se encontró"* ]] || [[ "$output" == *"no existe"* ]]
}

@test "ws-info: nonexistent workspace shows available workspaces" {
    mkdir -p "$TEST_WORKSPACES_DIR/mi-workspace"

    run run_ws info no-existe

    [ "$status" -eq 1 ]
    [[ "$output" == *"mi-workspace"* ]]
}

@test "ws-info: exact match works" {
    mkdir -p "$TEST_WORKSPACES_DIR/info-test"
    create_test_repo "repo-info"

    cd "$TEST_WORKSPACE_ROOT/repo-info"
    git worktree add "$TEST_WORKSPACES_DIR/info-test/repo-info" -b feature/info-test 2>/dev/null || true
    cd - > /dev/null

    run run_ws info info-test

    [ "$status" -eq 0 ]
    [[ "$output" == *"info-test"* ]]
}

@test "ws-info: partial search finds workspace" {
    mkdir -p "$TEST_WORKSPACES_DIR/feature-NUBA-5678"

    run run_ws info 5678

    [[ "$output" == *"NUBA-5678"* ]] || [[ "$output" == *"feature-NUBA-5678"* ]]
}

# =============================================================================
# Tests de información mostrada (igual que ws-switch)
# =============================================================================

@test "ws-info: shows header with workspace name" {
    mkdir -p "$TEST_WORKSPACES_DIR/header-test"

    run run_ws info header-test

    [ "$status" -eq 0 ]
    [[ "$output" == *"header-test"* ]]
}

@test "ws-info: shows workspace path" {
    mkdir -p "$TEST_WORKSPACES_DIR/ruta-info"

    run run_ws info ruta-info

    [ "$status" -eq 0 ]
    [[ "$output" == *"Ruta:"* ]]
    [[ "$output" == *"ruta-info"* ]]
}

@test "ws-info: empty workspace shows informative message" {
    mkdir -p "$TEST_WORKSPACES_DIR/vacio-info"

    run run_ws info vacio-info

    [ "$status" -eq 0 ]
    [[ "$output" == *"No hay repos"* ]] || [[ "$output" == *"ws add"* ]]
}

# =============================================================================
# Tests con repos
# =============================================================================

@test "ws-info: shows workspace repos" {
    mkdir -p "$TEST_WORKSPACES_DIR/con-repos-info"
    create_test_repo "repo-visible"

    cd "$TEST_WORKSPACE_ROOT/repo-visible"
    git worktree add "$TEST_WORKSPACES_DIR/con-repos-info/repo-visible" -b feature/con-repos-info 2>/dev/null || true
    cd - > /dev/null

    run run_ws info con-repos-info

    [ "$status" -eq 0 ]
    [[ "$output" == *"repo-visible"* ]]
}

@test "ws-info: shows branch of each repo" {
    mkdir -p "$TEST_WORKSPACES_DIR/branch-info"
    create_test_repo "repo-branch"

    cd "$TEST_WORKSPACE_ROOT/repo-branch"
    git worktree add "$TEST_WORKSPACES_DIR/branch-info/repo-branch" -b feature/branch-info 2>/dev/null || true
    cd - > /dev/null

    run run_ws info branch-info

    [ "$status" -eq 0 ]
    [[ "$output" == *"Branch:"* ]]
    [[ "$output" == *"feature/branch-info"* ]]
}

@test "ws-info: shows clean state when repo is clean" {
    mkdir -p "$TEST_WORKSPACES_DIR/limpio-info"
    create_test_repo "repo-limpio-info"

    cd "$TEST_WORKSPACE_ROOT/repo-limpio-info"
    git worktree add "$TEST_WORKSPACES_DIR/limpio-info/repo-limpio-info" -b feature/limpio-info 2>/dev/null || true
    cd - > /dev/null

    run run_ws info limpio-info

    [ "$status" -eq 0 ]
    [[ "$output" == *"Sin cambios"* ]]
}

@test "ws-info: shows warning when uncommitted changes" {
    mkdir -p "$TEST_WORKSPACES_DIR/cambios-info"
    create_test_repo "repo-cambios-info"

    cd "$TEST_WORKSPACE_ROOT/repo-cambios-info"
    git worktree add "$TEST_WORKSPACES_DIR/cambios-info/repo-cambios-info" -b feature/cambios-info 2>/dev/null || true
    cd - > /dev/null

    # Crear un archivo sin commitear
    echo "cambio" > "$TEST_WORKSPACES_DIR/cambios-info/repo-cambios-info/archivo-nuevo.txt"

    run run_ws info cambios-info

    [ "$status" -eq 0 ]
    [[ "$output" == *"Cambios sin commitear"* ]] || [[ "$output" == *"archivo-nuevo.txt"* ]]
}

# =============================================================================
# Tests de modo offline
# =============================================================================

@test "ws-info: offline mode shows indicator [OFFLINE]" {
    mkdir -p "$TEST_WORKSPACES_DIR/offline-test"

    # Activar modo offline
    echo "offline" > "$WS_TOOLS_ROOT/.ws-mode"

    run run_ws info offline-test

    # Limpiar
    rm -f "$WS_TOOLS_ROOT/.ws-mode"

    [ "$status" -eq 0 ]
    [[ "$output" == *"OFFLINE"* ]]
}
