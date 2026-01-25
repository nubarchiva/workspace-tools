#!/usr/bin/env bats
# Tests para ws-list - Listar workspaces
#
# NOTA: Muchos tests estan marcados como skip porque ws-list tiene dependencias
# fijas que impiden testing aislado.

load 'test_helper'

setup() {
    setup_test_environment
}

teardown() {
    teardown_test_environment
}

# Helper para ejecutar ws-list
run_ws_list() {
    env WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT" \
        WORKSPACES_DIR="$TEST_WORKSPACES_DIR" \
        WS_TOOLS="$WS_TOOLS_ROOT" \
        "$WS_TOOLS_ROOT/bin/ws-list" "$@"
}

# =============================================================================
# Tests que funcionan (verifican output/comportamiento basico)
# =============================================================================

@test "ws-list: ejecuta sin errores" {
    run run_ws_list
    # Puede dar 0 aunque no haya workspaces
    [ "$status" -eq 0 ]
}

@test "ws-list: output contains header WORKSPACES" {
    run run_ws_list
    [[ "$output" == *"WORKSPACES"* ]]
}

@test "ws-list: with filter shows filter in header" {
    run run_ws_list "mi-filtro"
    [[ "$output" == *"filtro"* ]] || [[ "$output" == *"mi-filtro"* ]]
}

# =============================================================================
# Tests de integracion (requieren refactoring)
# =============================================================================

@test "ws-list: no workspaces shows message apropiado" {
    run run_ws_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"No hay workspaces"* ]] || [[ "$output" == *"ws new"* ]]
}

@test "ws-list: shows existing workspace" {
    mkdir -p "$TEST_WORKSPACES_DIR/mi-workspace"

    run run_ws_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"mi-workspace"* ]]
}

@test "ws-list: shows multiple workspaces" {
    mkdir -p "$TEST_WORKSPACES_DIR/workspace-a"
    mkdir -p "$TEST_WORKSPACES_DIR/workspace-b"

    run run_ws_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"workspace-a"* ]]
    [[ "$output" == *"workspace-b"* ]]
}

@test "ws-list: shows branch of each workspace" {
    mkdir -p "$TEST_WORKSPACES_DIR/mi-feature"

    run run_ws_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"feature/mi-feature"* ]]
}

@test "ws-list: master shows master branch" {
    mkdir -p "$TEST_WORKSPACES_DIR/master"

    run run_ws_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"master"* ]]
}

@test "ws-list: filtra por patron parcial" {
    mkdir -p "$TEST_WORKSPACES_DIR/NUBA-8400-feature"
    mkdir -p "$TEST_WORKSPACES_DIR/otro-workspace"

    run run_ws_list "8400"
    [ "$status" -eq 0 ]
    [[ "$output" == *"NUBA-8400"* ]]
    [[ "$output" != *"otro-workspace"* ]]
}

@test "ws-list: shows repo count" {
    mkdir -p "$TEST_WORKSPACES_DIR/con-repos"

    # Crear repo dentro del workspace
    mkdir -p "$TEST_WORKSPACES_DIR/con-repos/mi-repo"
    cd "$TEST_WORKSPACES_DIR/con-repos/mi-repo"
    git init --quiet
    cd - > /dev/null

    run run_ws_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"Repos"* ]] || [[ "$output" == *"1"* ]]
}

@test "ws-list: shows total workspaces" {
    mkdir -p "$TEST_WORKSPACES_DIR/ws-1"
    mkdir -p "$TEST_WORKSPACES_DIR/ws-2"
    mkdir -p "$TEST_WORKSPACES_DIR/ws-3"

    run run_ws_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"Total"* ]] || [[ "$output" == *"3"* ]]
}

@test "ws-list: filter without matches shows message" {
    mkdir -p "$TEST_WORKSPACES_DIR/mi-workspace"

    run run_ws_list "inexistente"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No hay"* ]] || [[ "$output" == *"0"* ]]
}
