#!/usr/bin/env bats
# Tests para ws-stash
# Verifica el comportamiento del comando ws stash

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

@test "ws-stash: -h shows help" {
    run run_ws stash -h

    [ "$status" -eq 0 ]
    [[ "$output" == *"Uso: ws stash"* ]]
    [[ "$output" == *"push"* ]]
    [[ "$output" == *"pop"* ]]
}

@test "ws-stash: --help shows help" {
    run run_ws stash --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Uso: ws stash"* ]]
}

@test "ws-stash: help mentions available actions" {
    run run_ws stash --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"push"* ]]
    [[ "$output" == *"pop"* ]]
    [[ "$output" == *"list"* ]]
    [[ "$output" == *"clear"* ]]
    [[ "$output" == *"show"* ]]
}

# =============================================================================
# Tests de detección de workspace
# =============================================================================

@test "ws-stash: nonexistent workspace fails" {
    run run_ws stash list no-existe-xyz

    [ "$status" -eq 1 ]
    [[ "$output" == *"No se encontró"* ]] || [[ "$output" == *"no existe"* ]]
}

@test "ws-stash: no args outside workspace fails with clear message" {
    cd "$TEST_WORKSPACE_ROOT"
    run run_ws stash list

    [ "$status" -eq 1 ]
    [[ "$output" == *"no se pudo detectar"* ]] || [[ "$output" == *"No se especificó"* ]]
}

@test "ws-stash: partial match finds workspace" {
    mkdir -p "$TEST_WORKSPACES_DIR/feature-NUBA-9999"
    create_test_repo "repo-9999"

    cd "$TEST_WORKSPACE_ROOT/repo-9999"
    git worktree add "$TEST_WORKSPACES_DIR/feature-NUBA-9999/repo-9999" -b feature/nuba-9999 2>/dev/null || true
    cd - > /dev/null

    run run_ws stash list 9999

    # Debe encontrar el workspace
    [[ "$output" == *"NUBA-9999"* ]] || [[ "$output" == *"feature-NUBA-9999"* ]]
}

@test "ws-stash: explicit workspace works" {
    mkdir -p "$TEST_WORKSPACES_DIR/stash-test"
    create_test_repo "repo-stash-test"

    cd "$TEST_WORKSPACE_ROOT/repo-stash-test"
    git worktree add "$TEST_WORKSPACES_DIR/stash-test/repo-stash-test" -b feature/stash-test 2>/dev/null || true
    cd - > /dev/null

    run run_ws stash list stash-test

    [ "$status" -eq 0 ]
    [[ "$output" == *"stash-test"* ]]
}

# =============================================================================
# Tests de stash list
# =============================================================================

@test "ws-stash: list in empty workspace shows message" {
    mkdir -p "$TEST_WORKSPACES_DIR/vacio-stash"

    run run_ws stash list vacio-stash

    [ "$status" -eq 1 ]
    [[ "$output" == *"No hay repos"* ]]
}

@test "ws-stash: list in workspace with repo without stashes" {
    mkdir -p "$TEST_WORKSPACES_DIR/sin-stash"
    create_test_repo "repo-limpio"

    cd "$TEST_WORKSPACE_ROOT/repo-limpio"
    git worktree add "$TEST_WORKSPACES_DIR/sin-stash/repo-limpio" -b feature/sin-stash 2>/dev/null || true
    cd - > /dev/null

    run run_ws stash list sin-stash

    [ "$status" -eq 0 ]
    [[ "$output" == *"No hay stashes"* ]] || [[ "$output" == *"sin-stash"* ]]
}

# =============================================================================
# Tests de stash push
# =============================================================================

@test "ws-stash: push in repo without changes shows 'Sin cambios'" {
    mkdir -p "$TEST_WORKSPACES_DIR/push-test"
    create_test_repo "repo-push"

    cd "$TEST_WORKSPACE_ROOT/repo-push"
    git worktree add "$TEST_WORKSPACES_DIR/push-test/repo-push" -b feature/push-test 2>/dev/null || true
    cd - > /dev/null

    run run_ws stash push-test

    [ "$status" -eq 0 ]
    [[ "$output" == *"Sin cambios"* ]]
}

@test "ws-stash: push with changes creates stash" {
    mkdir -p "$TEST_WORKSPACES_DIR/push-cambios"
    create_test_repo "repo-cambios"

    cd "$TEST_WORKSPACE_ROOT/repo-cambios"
    git worktree add "$TEST_WORKSPACES_DIR/push-cambios/repo-cambios" -b feature/push-cambios 2>/dev/null || true
    cd - > /dev/null

    # Crear cambio sin commitear
    echo "cambio" > "$TEST_WORKSPACES_DIR/push-cambios/repo-cambios/nuevo.txt"

    run run_ws stash push-cambios

    [ "$status" -eq 0 ]
    [[ "$output" == *"Stash creado"* ]] || [[ "$output" == *"stashes creados"* ]]
}

@test "ws-stash: push with custom message" {
    mkdir -p "$TEST_WORKSPACES_DIR/push-msg"
    create_test_repo "repo-msg"

    cd "$TEST_WORKSPACE_ROOT/repo-msg"
    git worktree add "$TEST_WORKSPACES_DIR/push-msg/repo-msg" -b feature/push-msg 2>/dev/null || true
    cd - > /dev/null

    echo "cambio" > "$TEST_WORKSPACES_DIR/push-msg/repo-msg/archivo.txt"

    run run_ws stash push "Mi mensaje de stash" push-msg

    [ "$status" -eq 0 ]
    [[ "$output" == *"Mi mensaje de stash"* ]] || [[ "$output" == *"Stash creado"* ]]
}

# =============================================================================
# Tests de stash pop
# =============================================================================

@test "ws-stash: pop without stashes shows 'Sin stashes'" {
    mkdir -p "$TEST_WORKSPACES_DIR/pop-vacio"
    create_test_repo "repo-pop-vacio"

    cd "$TEST_WORKSPACE_ROOT/repo-pop-vacio"
    git worktree add "$TEST_WORKSPACES_DIR/pop-vacio/repo-pop-vacio" -b feature/pop-vacio 2>/dev/null || true
    cd - > /dev/null

    run run_ws stash pop pop-vacio

    [ "$status" -eq 0 ]
    [[ "$output" == *"Sin stashes"* ]]
}

# =============================================================================
# Tests de acción por defecto
# =============================================================================

@test "ws-stash: no action uses push by default" {
    mkdir -p "$TEST_WORKSPACES_DIR/default-action"
    create_test_repo "repo-default"

    cd "$TEST_WORKSPACE_ROOT/repo-default"
    git worktree add "$TEST_WORKSPACES_DIR/default-action/repo-default" -b feature/default-action 2>/dev/null || true
    cd - > /dev/null

    run run_ws stash default-action

    [ "$status" -eq 0 ]
    # Debe ejecutar push (mostrar "Stash push" en header o "Sin cambios")
    [[ "$output" == *"Stash push"* ]] || [[ "$output" == *"Sin cambios"* ]]
}
