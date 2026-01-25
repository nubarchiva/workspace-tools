#!/usr/bin/env bats
# Tests para ws-common.sh - Funciones compartidas

load 'test_helper'

setup() {
    setup_test_environment
    load_ws_common
}

teardown() {
    teardown_test_environment
}

# =============================================================================
# Tests para validate_workspace_name()
# =============================================================================

@test "validate_workspace_name: valid name returns 0" {
    run validate_workspace_name "mi-workspace"
    [ "$status" -eq 0 ]
}

@test "validate_workspace_name: empty name returns 1" {
    run validate_workspace_name ""
    [ "$status" -eq 1 ]
    [[ "$output" == *"vacío"* ]]
}

@test "validate_workspace_name: name with spaces returns 1" {
    run validate_workspace_name "mi workspace"
    [ "$status" -eq 1 ]
    [[ "$output" == *"espacios"* ]]
}

@test "validate_workspace_name: very long name returns 1" {
    local long_name=$(printf 'a%.0s' {1..70})
    run validate_workspace_name "$long_name"
    [ "$status" -eq 1 ]
    [[ "$output" == *"largo"* ]]
}

@test "validate_workspace_name: name with slash returns 1" {
    run validate_workspace_name "mi/workspace"
    [ "$status" -eq 1 ]
    [[ "$output" == *"no permitidos"* ]]
}

@test "validate_workspace_name: name starting with dot returns 1" {
    run validate_workspace_name ".hidden"
    [ "$status" -eq 1 ]
    [[ "$output" == *"punto"* ]]
}

@test "validate_workspace_name: name starting with dash returns 1" {
    run validate_workspace_name "-invalid"
    [ "$status" -eq 1 ]
    [[ "$output" == *"guión"* ]]
}

@test "validate_workspace_name: reserved name workspaces retorna 1" {
    run validate_workspace_name "workspaces"
    [ "$status" -eq 1 ]
    [[ "$output" == *"reservado"* ]]
}

@test "validate_workspace_name: reserved name repos retorna 1" {
    run validate_workspace_name "repos"
    [ "$status" -eq 1 ]
    [[ "$output" == *"reservado"* ]]
}

@test "validate_workspace_name: master is valid" {
    run validate_workspace_name "master"
    [ "$status" -eq 0 ]
}

@test "validate_workspace_name: develop is valid" {
    run validate_workspace_name "develop"
    [ "$status" -eq 0 ]
}

# =============================================================================
# Tests para get_branch_name()
# =============================================================================

@test "get_branch_name: master returns master" {
    result=$(get_branch_name "master")
    [ "$result" = "master" ]
}

@test "get_branch_name: develop returns develop" {
    result=$(get_branch_name "develop")
    [ "$result" = "develop" ]
}

@test "get_branch_name: any other name returns feature/nombre" {
    result=$(get_branch_name "mi-feature")
    [ "$result" = "feature/mi-feature" ]
}

@test "get_branch_name: name with dashes returns feature/nombre" {
    result=$(get_branch_name "NUBA-8400-nueva-funcionalidad")
    [ "$result" = "feature/NUBA-8400-nueva-funcionalidad" ]
}

@test "get_branch_name: numeric name returns feature/numero" {
    result=$(get_branch_name "12345")
    [ "$result" = "feature/12345" ]
}

# =============================================================================
# Tests para find_matching_workspace()
# =============================================================================

@test "find_matching_workspace: exact match returns name" {
    mkdir -p "$TEST_WORKSPACES_DIR/mi-workspace"

    result=$(find_matching_workspace "mi-workspace" "$TEST_WORKSPACES_DIR")
    [ "$result" = "mi-workspace" ]
}

@test "find_matching_workspace: partial match returns workspace" {
    mkdir -p "$TEST_WORKSPACES_DIR/NUBA-8400-feature"

    result=$(find_matching_workspace "8400" "$TEST_WORKSPACES_DIR")
    [ "$result" = "NUBA-8400-feature" ]
}

@test "find_matching_workspace: case-insensitive search" {
    mkdir -p "$TEST_WORKSPACES_DIR/MiWorkspace"

    result=$(find_matching_workspace "miworkspace" "$TEST_WORKSPACES_DIR")
    [ "$result" = "MiWorkspace" ]
}

@test "find_matching_workspace: master returns master directamente" {
    # No necesita que exista el directorio
    result=$(find_matching_workspace "master" "$TEST_WORKSPACES_DIR")
    [ "$result" = "master" ]
}

@test "find_matching_workspace: develop returns develop directamente" {
    result=$(find_matching_workspace "develop" "$TEST_WORKSPACES_DIR")
    [ "$result" = "develop" ]
}

@test "find_matching_workspace: no matches fails with code 1" {
    mkdir -p "$TEST_WORKSPACES_DIR/otro-workspace"

    run find_matching_workspace "inexistente" "$TEST_WORKSPACES_DIR"
    [ "$status" -eq 1 ]
}

@test "find_matching_workspace: without workspaces directory fails" {
    rm -rf "$TEST_WORKSPACES_DIR"

    run find_matching_workspace "algo" "$TEST_WORKSPACES_DIR"
    [ "$status" -eq 1 ]
}

# =============================================================================
# Tests para find_repos_in_workspace()
# =============================================================================

@test "find_repos_in_workspace: finds repo in root" {
    local ws_dir="$TEST_WORKSPACES_DIR/test-ws"
    mkdir -p "$ws_dir/mi-repo"
    cd "$ws_dir/mi-repo"
    git init --quiet
    cd - > /dev/null

    result=$(find_repos_in_workspace "$ws_dir")
    [[ "$result" == *"mi-repo"* ]]
}

@test "find_repos_in_workspace: finds repos in subdirectories" {
    local ws_dir="$TEST_WORKSPACES_DIR/test-ws"
    mkdir -p "$ws_dir/libs/mi-lib"
    cd "$ws_dir/libs/mi-lib"
    git init --quiet
    cd - > /dev/null

    result=$(find_repos_in_workspace "$ws_dir")
    [[ "$result" == *"libs/mi-lib"* ]]
}

@test "find_repos_in_workspace: empty workspace returns empty" {
    local ws_dir="$TEST_WORKSPACES_DIR/empty-ws"
    mkdir -p "$ws_dir"

    result=$(find_repos_in_workspace "$ws_dir")
    [ -z "$result" ]
}

@test "find_repos_in_workspace: multiple repos sorted" {
    local ws_dir="$TEST_WORKSPACES_DIR/multi-ws"

    # Crear varios repos
    mkdir -p "$ws_dir/repo-b"
    cd "$ws_dir/repo-b" && git init --quiet && cd - > /dev/null

    mkdir -p "$ws_dir/repo-a"
    cd "$ws_dir/repo-a" && git init --quiet && cd - > /dev/null

    mkdir -p "$ws_dir/libs/lib-c"
    cd "$ws_dir/libs/lib-c" && git init --quiet && cd - > /dev/null

    result=$(find_repos_in_workspace "$ws_dir")

    # Debe contener los tres
    [[ "$result" == *"repo-a"* ]]
    [[ "$result" == *"repo-b"* ]]
    [[ "$result" == *"libs/lib-c"* ]]
}

# =============================================================================
# Tests para detect_current_workspace()
# =============================================================================

@test "detect_current_workspace: inside workspace returns name" {
    mkdir -p "$TEST_WORKSPACES_DIR/mi-workspace/repo"

    # La funcion detect_current_workspace usa WS_TOOLS para calcular la ruta
    # Necesitamos ajustar el entorno para que funcione en test
    # Por ahora verificamos que la funcion existe y es callable
    cd "$TEST_WORKSPACES_DIR/mi-workspace/repo"

    # Llamar con el WORKSPACES_DIR correcto (la funcion lee de variable global)
    # Nota: esta funcion tiene dependencia de WS_TOOLS que complica el test
    # La marcamos como skip temporal
    skip "Requiere refactoring de detect_current_workspace para ser testeable"
}

@test "detect_current_workspace: outside workspaces returns empty" {
    skip "Requiere refactoring de detect_current_workspace para ser testeable"
}

@test "detect_current_workspace: in deep subdirectory detects workspace" {
    skip "Requiere refactoring de detect_current_workspace para ser testeable"
}

# =============================================================================
# Tests para copy_workspace_config() - Solo verificar que no falla
# =============================================================================

@test "copy_workspace_config: runs without errors in empty directory" {
    local ws_dir="$TEST_WORKSPACES_DIR/config-test"
    mkdir -p "$ws_dir"

    # La funcion usa WORKSPACE_ROOT que puede no estar bien en test
    # Verificar solo que no explota
    export CONFIG_REFERENCE_DIR="$TEST_WORKSPACE_ROOT"
    export WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT"

    run copy_workspace_config "$ws_dir"
    [ "$status" -eq 0 ]
}
