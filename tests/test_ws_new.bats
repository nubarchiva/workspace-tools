#!/usr/bin/env bats
# Tests para ws-new - Crear workspaces

load 'test_helper'

setup() {
    setup_test_environment
}

teardown() {
    teardown_test_environment
}

# Helper para ejecutar ws-new con entorno de test
run_ws_new() {
    env WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT" \
        WORKSPACES_DIR="$TEST_WORKSPACES_DIR" \
        WS_TOOLS="$WS_TOOLS_ROOT" \
        "$WS_TOOLS_ROOT/bin/ws-new" "$@"
}

# =============================================================================
# Tests de ayuda y validacion basica
# =============================================================================

@test "ws-new: sin argumentos muestra ayuda y sale con 1" {
    run run_ws_new
    [ "$status" -eq 1 ]
    [[ "$output" == *"Uso:"* ]]
}

@test "ws-new: ayuda muestra ejemplos" {
    run run_ws_new
    [[ "$output" == *"Ejemplos"* ]]
    [[ "$output" == *"ws new"* ]]
}

@test "ws-new: ayuda menciona master y develop" {
    run run_ws_new
    [[ "$output" == *"master"* ]]
    [[ "$output" == *"develop"* ]]
}

@test "ws-new: nombre vacio muestra ayuda" {
    run run_ws_new ""
    [ "$status" -eq 1 ]
    [[ "$output" == *"Uso:"* ]]
}

# =============================================================================
# Tests de creacion de workspace
# =============================================================================

@test "ws-new: crea directorio del workspace" {
    run run_ws_new "test-workspace"
    [ "$status" -eq 0 ]
    [ -d "$TEST_WORKSPACES_DIR/test-workspace" ]
}

@test "ws-new: workspace sin repos muestra mensaje informativo" {
    run run_ws_new "empty-workspace"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ws add"* ]]
}

@test "ws-new: crea workspace con un repo" {
    create_test_repo "mi-repo"

    run run_ws_new "test-ws" "mi-repo"
    [ "$status" -eq 0 ]
    [ -d "$TEST_WORKSPACES_DIR/test-ws" ]
    [ -d "$TEST_WORKSPACES_DIR/test-ws/mi-repo" ]
}

@test "ws-new: crea workspace con multiples repos" {
    create_test_repo "repo-a"
    create_test_repo "repo-b"

    run run_ws_new "multi-ws" "repo-a" "repo-b"
    [ "$status" -eq 0 ]
    [ -d "$TEST_WORKSPACES_DIR/multi-ws/repo-a" ]
    [ -d "$TEST_WORKSPACES_DIR/multi-ws/repo-b" ]
}

@test "ws-new: crea workspace con repo en subdirectorio" {
    create_test_repo "libs/mi-lib"

    run run_ws_new "subdir-ws" "libs/mi-lib"
    [ "$status" -eq 0 ]
    [ -d "$TEST_WORKSPACES_DIR/subdir-ws/libs/mi-lib" ]
}

@test "ws-new: repo inexistente muestra warning pero no falla" {
    run run_ws_new "test-ws" "repo-que-no-existe"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no encontrado"* ]] || [[ "$output" == *"saltando"* ]]
}

# =============================================================================
# Tests de branches
# =============================================================================

@test "ws-new: master usa branch master" {
    create_test_repo "mi-repo"

    # Cambiar el repo principal a otra branch para poder crear worktree en master
    cd "$TEST_WORKSPACE_ROOT/mi-repo"
    git checkout -b temp-branch --quiet
    cd - > /dev/null

    run run_ws_new "master" "mi-repo"
    [ "$status" -eq 0 ]

    # Verificar que el worktree existe
    [ -d "$TEST_WORKSPACES_DIR/master/mi-repo" ]

    cd "$TEST_WORKSPACES_DIR/master/mi-repo"
    branch=$(git branch --show-current)
    [ "$branch" = "master" ]
}

@test "ws-new: develop usa branch develop" {
    create_test_repo "mi-repo"

    # Crear branch develop si no existe
    cd "$TEST_WORKSPACE_ROOT/mi-repo"
    if ! git rev-parse --verify develop >/dev/null 2>&1; then
        git checkout -b develop --quiet
        git checkout master --quiet
    fi
    cd - > /dev/null

    run run_ws_new "develop" "mi-repo"
    [ "$status" -eq 0 ]

    cd "$TEST_WORKSPACES_DIR/develop/mi-repo"
    branch=$(git branch --show-current)
    [ "$branch" = "develop" ]
}

@test "ws-new: feature crea branch feature/nombre" {
    create_test_repo "mi-repo"

    run run_ws_new "mi-feature" "mi-repo"
    [ "$status" -eq 0 ]

    cd "$TEST_WORKSPACES_DIR/mi-feature/mi-repo"
    branch=$(git branch --show-current)
    [ "$branch" = "feature/mi-feature" ]
}

# =============================================================================
# Tests de worktrees
# =============================================================================

@test "ws-new: crea worktree de git valido" {
    create_test_repo "mi-repo"

    run run_ws_new "worktree-test" "mi-repo"
    [ "$status" -eq 0 ]

    [ -f "$TEST_WORKSPACES_DIR/worktree-test/mi-repo/.git" ] || \
    [ -d "$TEST_WORKSPACES_DIR/worktree-test/mi-repo/.git" ]

    cd "$TEST_WORKSPACES_DIR/worktree-test/mi-repo"
    run git status
    [ "$status" -eq 0 ]
}

@test "ws-new: worktree aparece en git worktree list" {
    create_test_repo "mi-repo"

    run_ws_new "listed-ws" "mi-repo"

    cd "$TEST_WORKSPACE_ROOT/mi-repo"
    run git worktree list
    [ "$status" -eq 0 ]
    [[ "$output" == *"listed-ws"* ]]
}
