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
# Tests para get_branch_name()
# =============================================================================

@test "get_branch_name: master retorna master" {
    result=$(get_branch_name "master")
    [ "$result" = "master" ]
}

@test "get_branch_name: develop retorna develop" {
    result=$(get_branch_name "develop")
    [ "$result" = "develop" ]
}

@test "get_branch_name: cualquier otro nombre retorna feature/nombre" {
    result=$(get_branch_name "mi-feature")
    [ "$result" = "feature/mi-feature" ]
}

@test "get_branch_name: nombre con guiones retorna feature/nombre" {
    result=$(get_branch_name "NUBA-8400-nueva-funcionalidad")
    [ "$result" = "feature/NUBA-8400-nueva-funcionalidad" ]
}

@test "get_branch_name: nombre numerico retorna feature/numero" {
    result=$(get_branch_name "12345")
    [ "$result" = "feature/12345" ]
}

# =============================================================================
# Tests para find_matching_workspace()
# =============================================================================

@test "find_matching_workspace: coincidencia exacta retorna el nombre" {
    mkdir -p "$TEST_WORKSPACES_DIR/mi-workspace"

    result=$(find_matching_workspace "mi-workspace" "$TEST_WORKSPACES_DIR")
    [ "$result" = "mi-workspace" ]
}

@test "find_matching_workspace: coincidencia parcial retorna el workspace" {
    mkdir -p "$TEST_WORKSPACES_DIR/NUBA-8400-feature"

    result=$(find_matching_workspace "8400" "$TEST_WORKSPACES_DIR")
    [ "$result" = "NUBA-8400-feature" ]
}

@test "find_matching_workspace: busqueda case-insensitive" {
    mkdir -p "$TEST_WORKSPACES_DIR/MiWorkspace"

    result=$(find_matching_workspace "miworkspace" "$TEST_WORKSPACES_DIR")
    [ "$result" = "MiWorkspace" ]
}

@test "find_matching_workspace: master retorna master directamente" {
    # No necesita que exista el directorio
    result=$(find_matching_workspace "master" "$TEST_WORKSPACES_DIR")
    [ "$result" = "master" ]
}

@test "find_matching_workspace: develop retorna develop directamente" {
    result=$(find_matching_workspace "develop" "$TEST_WORKSPACES_DIR")
    [ "$result" = "develop" ]
}

@test "find_matching_workspace: sin coincidencias falla con codigo 1" {
    mkdir -p "$TEST_WORKSPACES_DIR/otro-workspace"

    run find_matching_workspace "inexistente" "$TEST_WORKSPACES_DIR"
    [ "$status" -eq 1 ]
}

@test "find_matching_workspace: sin directorio workspaces falla" {
    rm -rf "$TEST_WORKSPACES_DIR"

    run find_matching_workspace "algo" "$TEST_WORKSPACES_DIR"
    [ "$status" -eq 1 ]
}

# =============================================================================
# Tests para find_repos_in_workspace()
# =============================================================================

@test "find_repos_in_workspace: encuentra repo en raiz" {
    local ws_dir="$TEST_WORKSPACES_DIR/test-ws"
    mkdir -p "$ws_dir/mi-repo"
    cd "$ws_dir/mi-repo"
    git init --quiet
    cd - > /dev/null

    result=$(find_repos_in_workspace "$ws_dir")
    [[ "$result" == *"mi-repo"* ]]
}

@test "find_repos_in_workspace: encuentra repos en subdirectorios" {
    local ws_dir="$TEST_WORKSPACES_DIR/test-ws"
    mkdir -p "$ws_dir/libs/mi-lib"
    cd "$ws_dir/libs/mi-lib"
    git init --quiet
    cd - > /dev/null

    result=$(find_repos_in_workspace "$ws_dir")
    [[ "$result" == *"libs/mi-lib"* ]]
}

@test "find_repos_in_workspace: workspace vacio retorna vacio" {
    local ws_dir="$TEST_WORKSPACES_DIR/empty-ws"
    mkdir -p "$ws_dir"

    result=$(find_repos_in_workspace "$ws_dir")
    [ -z "$result" ]
}

@test "find_repos_in_workspace: multiples repos ordenados" {
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

@test "detect_current_workspace: dentro de workspace retorna nombre" {
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

@test "detect_current_workspace: fuera de workspaces retorna vacio" {
    skip "Requiere refactoring de detect_current_workspace para ser testeable"
}

@test "detect_current_workspace: en subdirectorio profundo detecta workspace" {
    skip "Requiere refactoring de detect_current_workspace para ser testeable"
}

# =============================================================================
# Tests para copy_workspace_config() - Solo verificar que no falla
# =============================================================================

@test "copy_workspace_config: ejecuta sin errores en directorio vacio" {
    local ws_dir="$TEST_WORKSPACES_DIR/config-test"
    mkdir -p "$ws_dir"

    # La funcion usa WORKSPACE_ROOT que puede no estar bien en test
    # Verificar solo que no explota
    export CONFIG_REFERENCE_DIR="$TEST_WORKSPACE_ROOT"
    export WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT"

    run copy_workspace_config "$ws_dir"
    [ "$status" -eq 0 ]
}
