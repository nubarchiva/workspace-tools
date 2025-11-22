#!/usr/bin/env bats
# Tests para ws-clean - Eliminar workspaces
#
# NOTA: Muchos tests estan marcados como skip porque ws-clean tiene dependencias
# fijas que impiden testing aislado.

load 'test_helper'

setup() {
    setup_test_environment
}

teardown() {
    teardown_test_environment
}

# Helper para ejecutar ws-clean
run_ws_clean() {
    env WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT" \
        WORKSPACES_DIR="$TEST_WORKSPACES_DIR" \
        WS_TOOLS="$WS_TOOLS_ROOT" \
        "$WS_TOOLS_ROOT/bin/ws-clean" "$@"
}

# =============================================================================
# Tests que funcionan
# =============================================================================

@test "ws-clean: sin argumentos muestra ayuda" {
    run run_ws_clean
    [ "$status" -eq 1 ]
    [[ "$output" == *"Uso:"* ]] || [[ "$output" == *"ws clean"* ]]
}

@test "ws-clean: ayuda menciona verificaciones" {
    run run_ws_clean
    [[ "$output" == *"cambios"* ]] || [[ "$output" == *"pendientes"* ]] || [[ "$output" == *"Ejemplo"* ]]
}

# =============================================================================
# Tests de integracion (requieren refactoring)
# =============================================================================

@test "ws-clean: workspace inexistente falla" {
    skip "Requiere que ws-clean use WORKSPACE_ROOT del entorno"
    run run_ws_clean "no-existe"
    [ "$status" -ne 0 ]
    [[ "$output" == *"no existe"* ]] || [[ "$output" == *"No se encontr"* ]]
}

@test "ws-clean: elimina workspace vacio" {
    skip "Requiere que ws-clean use WORKSPACE_ROOT del entorno"
    mkdir -p "$TEST_WORKSPACES_DIR/vacio"

    # Simular confirmacion
    run bash -c "echo 's' | env WORKSPACE_ROOT='$TEST_WORKSPACE_ROOT' '$WS_TOOLS_ROOT/bin/ws-clean' 'vacio'"
    [ "$status" -eq 0 ]
    [ ! -d "$TEST_WORKSPACES_DIR/vacio" ]
}

@test "ws-clean: busqueda parcial funciona" {
    skip "Requiere que ws-clean use WORKSPACE_ROOT del entorno"
    mkdir -p "$TEST_WORKSPACES_DIR/NUBA-8400-feature"

    # Buscar por "8400"
    run bash -c "echo 's' | env WORKSPACE_ROOT='$TEST_WORKSPACE_ROOT' '$WS_TOOLS_ROOT/bin/ws-clean' '8400'"
    [ "$status" -eq 0 ]
}

@test "ws-clean: advierte sobre cambios sin commitear" {
    skip "Requiere que ws-clean use WORKSPACE_ROOT del entorno"
    mkdir -p "$TEST_WORKSPACES_DIR/con-cambios/mi-repo"

    # Crear repo con cambios
    cd "$TEST_WORKSPACES_DIR/con-cambios/mi-repo"
    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "inicial" > file.txt
    git add file.txt
    git commit -m "initial" --quiet
    echo "cambio" >> file.txt  # Cambio sin commitear
    cd - > /dev/null

    run run_ws_clean "con-cambios"
    [[ "$output" == *"cambios"* ]] || [[ "$output" == *"sin commitear"* ]]
}

@test "ws-clean: elimina worktrees de git" {
    skip "Requiere que ws-clean use WORKSPACE_ROOT del entorno"
    # Este test verifica que git worktree prune se ejecuta
    # Requiere setup mas complejo con repo principal
    true
}

@test "ws-clean: opcion --force omite confirmacion" {
    skip "Requiere que ws-clean use WORKSPACE_ROOT del entorno"
    mkdir -p "$TEST_WORKSPACES_DIR/force-test"

    run env WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT" "$WS_TOOLS_ROOT/bin/ws-clean" "force-test" "--force"
    [ "$status" -eq 0 ]
    [ ! -d "$TEST_WORKSPACES_DIR/force-test" ]
}
