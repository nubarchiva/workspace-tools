#!/usr/bin/env bats
# Tests para ws-git
# Verifica el comportamiento del comando ws git

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

@test "ws-git: sin argumentos y sin workspace detectado muestra error" {
    cd "$TEST_WORKSPACE_ROOT"
    run run_ws git

    [ "$status" -eq 1 ]
    # Puede fallar por no tener comando Git o por no detectar workspace
    [[ "$output" == *"no se especificó"* ]] || [[ "$output" == *"no se pudo detectar"* ]] || [[ "$output" == *"comando"* ]]
}

@test "ws-git: workspace sin comando git muestra error" {
    mkdir -p "$TEST_WORKSPACES_DIR/git-test"

    run run_ws git git-test

    [ "$status" -eq 1 ]
    [[ "$output" == *"comando"* ]] || [[ "$output" == *"Git"* ]]
}

# =============================================================================
# Tests de detección de workspace
# =============================================================================

@test "ws-git: workspace inexistente falla" {
    run run_ws git no-existe-xyz status

    [ "$status" -eq 1 ]
    [[ "$output" == *"No se encontró"* ]] || [[ "$output" == *"no existe"* ]]
}

@test "ws-git: coincidencia parcial encuentra workspace" {
    mkdir -p "$TEST_WORKSPACES_DIR/feature-GIT-4321"

    run run_ws git 4321 status

    # Puede fallar por no tener repos, pero debe encontrar el workspace
    [[ "$output" == *"GIT-4321"* ]] || [[ "$output" == *"feature-GIT-4321"* ]] || [[ "$output" == *"No hay repos"* ]]
}

@test "ws-git: workspace vacío falla con mensaje claro" {
    mkdir -p "$TEST_WORKSPACES_DIR/git-vacio"

    run run_ws git git-vacio status

    [ "$status" -eq 1 ]
    [[ "$output" == *"No hay repos"* ]]
}

# =============================================================================
# Tests de detección inteligente de argumentos
# =============================================================================

@test "ws-git: sin workspace y sin auto-detección falla" {
    # Sin crear ningún workspace, ejecutar desde la raíz
    cd "$TEST_WORKSPACE_ROOT"
    run run_ws git status

    # Debe fallar porque no hay workspace que detectar ni "status" es workspace válido
    [ "$status" -eq 1 ]
    # El mensaje puede variar: no encontrar workspace o no detectar automáticamente
    [[ "$output" == *"No se encontró"* ]] || [[ "$output" == *"no se pudo detectar"* ]] || [[ "$output" == *"no se especificó"* ]] || [[ "$output" == *"debes especificar"* ]]
}

@test "ws-git: workspace explícito toma args restantes como git args" {
    mkdir -p "$TEST_WORKSPACES_DIR/explicit-git"
    create_test_repo "repo-git-explicit"

    cd "$TEST_WORKSPACE_ROOT/repo-git-explicit"
    git worktree add "$TEST_WORKSPACES_DIR/explicit-git/repo-git-explicit" -b feature/explicit-git 2>/dev/null || true
    cd - > /dev/null

    run run_ws git explicit-git status

    [ "$status" -eq 0 ]
    [[ "$output" == *"explicit-git"* ]]
    [[ "$output" == *"status"* ]] || [[ "$output" == *"git"* ]]
}

# =============================================================================
# Tests de comandos git
# =============================================================================

@test "ws-git: status muestra estado de repos" {
    mkdir -p "$TEST_WORKSPACES_DIR/git-status"
    create_test_repo "repo-status"

    cd "$TEST_WORKSPACE_ROOT/repo-status"
    git worktree add "$TEST_WORKSPACES_DIR/git-status/repo-status" -b feature/git-status 2>/dev/null || true
    cd - > /dev/null

    run run_ws git git-status status

    [ "$status" -eq 0 ]
    [[ "$output" == *"repo-status"* ]]
}

@test "ws-git: muestra header con información del workspace" {
    mkdir -p "$TEST_WORKSPACES_DIR/header-git"
    create_test_repo "repo-header-git"

    cd "$TEST_WORKSPACE_ROOT/repo-header-git"
    git worktree add "$TEST_WORKSPACES_DIR/header-git/repo-header-git" -b feature/header-git 2>/dev/null || true
    cd - > /dev/null

    run run_ws git header-git status

    [ "$status" -eq 0 ]
    [[ "$output" == *"header-git"* ]]
    [[ "$output" == *"Workspace"* ]] || [[ "$output" == *"Branch"* ]]
}

@test "ws-git: log funciona en todos los repos" {
    mkdir -p "$TEST_WORKSPACES_DIR/git-log"
    create_test_repo "repo-log"

    cd "$TEST_WORKSPACE_ROOT/repo-log"
    git worktree add "$TEST_WORKSPACES_DIR/git-log/repo-log" -b feature/git-log 2>/dev/null || true
    cd - > /dev/null

    run run_ws git git-log log --oneline -1

    [ "$status" -eq 0 ]
    [[ "$output" == *"repo-log"* ]]
}

# =============================================================================
# Tests de push especial
# =============================================================================

@test "ws-git: push sin upstream y sin commits no crea branch remota" {
    mkdir -p "$TEST_WORKSPACES_DIR/git-push-vacio"
    create_test_repo "repo-push-vacio"

    cd "$TEST_WORKSPACE_ROOT/repo-push-vacio"
    git worktree add "$TEST_WORKSPACES_DIR/git-push-vacio/repo-push-vacio" -b feature/git-push-vacio 2>/dev/null || true
    cd - > /dev/null

    run run_ws git git-push-vacio push

    [ "$status" -eq 0 ]
    # Debe omitir push cuando no hay commits nuevos
    [[ "$output" == *"omitiendo"* ]] || [[ "$output" == *"Sin commits"* ]] || [[ "$output" == *"branch remota"* ]]
}

# =============================================================================
# Tests de múltiples repos
# =============================================================================

@test "ws-git: ejecuta en múltiples repos" {
    mkdir -p "$TEST_WORKSPACES_DIR/multi-repo"
    create_test_repo "repo-uno"
    create_test_repo "repo-dos"

    cd "$TEST_WORKSPACE_ROOT/repo-uno"
    git worktree add "$TEST_WORKSPACES_DIR/multi-repo/repo-uno" -b feature/multi-repo 2>/dev/null || true
    cd - > /dev/null

    cd "$TEST_WORKSPACE_ROOT/repo-dos"
    git worktree add "$TEST_WORKSPACES_DIR/multi-repo/repo-dos" -b feature/multi-repo 2>/dev/null || true
    cd - > /dev/null

    run run_ws git multi-repo status

    [ "$status" -eq 0 ]
    [[ "$output" == *"repo-uno"* ]]
    [[ "$output" == *"repo-dos"* ]]
}

@test "ws-git: éxito muestra mensaje de confirmación" {
    mkdir -p "$TEST_WORKSPACES_DIR/git-ok"
    create_test_repo "repo-ok"

    cd "$TEST_WORKSPACE_ROOT/repo-ok"
    git worktree add "$TEST_WORKSPACES_DIR/git-ok/repo-ok" -b feature/git-ok 2>/dev/null || true
    cd - > /dev/null

    run run_ws git git-ok status

    [ "$status" -eq 0 ]
    [[ "$output" == *"correctamente"* ]] || [[ "$output" == *"Git ejecutado"* ]]
}
