#!/usr/bin/env bats
# Tests para la función ws() de completions/ws-function.sh: ws cd / ws switch
#
# ws() deriva el directorio de workspaces de WS_TOOLS, así que se monta una copia de
# workspace-tools dentro del entorno de prueba con ws-switch sustituido por un doble
# que deja constancia de su ejecución.

load 'test_helper'

# ws se invoca como `ws ... || rc=$?`: bats ejecuta con errexit, que una shell
# interactiva no tiene, y ws() encadena funciones que devuelven distinto de 0
# como resultado normal (p. ej. «nada que migrar»)

setup() {
    setup_test_environment
    mkdir -p "$TEST_WORKSPACES_DIR/solr-upgrade/ks-nuba/.git"
    mkdir -p "$TEST_TEMP_DIR/home"

    local fake_tools="$TEST_WORKSPACE_ROOT/tools/workspace-tools"
    mkdir -p "$fake_tools/bin"
    local file
    for file in "$WS_TOOLS_ROOT"/bin/*; do
        ln -s "$file" "$fake_tools/bin/$(basename "$file")"
    done
    rm "$fake_tools/bin/ws-switch"
    cat > "$fake_tools/bin/ws-switch" <<EOF
#!/bin/bash
echo "\$*" >> "$TEST_TEMP_DIR/ws-switch-calls"
echo "ESTADO DE LOS REPOS"
EOF
    chmod +x "$fake_tools/bin/ws-switch"

    export WS_TOOLS="$fake_tools"
    source "$WS_TOOLS_ROOT/completions/ws-function.sh"
    cd "$TEST_TEMP_DIR/home"
}

teardown() {
    teardown_test_environment
}

@test "ws cd: changes to the workspace without checking repo status" {
    local rc=0
    ws cd solr > "$TEST_TEMP_DIR/out" || rc=$?

    [ "$rc" -eq 0 ]
    [ "$(pwd)" = "$TEST_WORKSPACES_DIR/solr-upgrade" ]
    [ ! -e "$TEST_TEMP_DIR/ws-switch-calls" ]
    grep -q "Cambiado a workspace: solr-upgrade" "$TEST_TEMP_DIR/out"
    ! grep -q "ESTADO DE LOS REPOS" "$TEST_TEMP_DIR/out"
}

@test "ws cd --status: changes to the workspace and shows repo status" {
    local rc=0
    ws cd solr --status > "$TEST_TEMP_DIR/out" || rc=$?

    [ "$rc" -eq 0 ]
    [ "$(pwd)" = "$TEST_WORKSPACES_DIR/solr-upgrade" ]
    [ "$(cat "$TEST_TEMP_DIR/ws-switch-calls")" = "solr-upgrade" ]
    grep -q "ESTADO DE LOS REPOS" "$TEST_TEMP_DIR/out"
}

@test "ws cd -s before the pattern: shows repo status" {
    local rc=0
    ws cd -s solr > "$TEST_TEMP_DIR/out" || rc=$?

    [ "$rc" -eq 0 ]
    [ "$(pwd)" = "$TEST_WORKSPACES_DIR/solr-upgrade" ]
    grep -q "ESTADO DE LOS REPOS" "$TEST_TEMP_DIR/out"
}

@test "ws switch: changes to the workspace without checking repo status" {
    local rc=0
    ws switch solr > /dev/null || rc=$?

    [ "$rc" -eq 0 ]
    [ "$(pwd)" = "$TEST_WORKSPACES_DIR/solr-upgrade" ]
    [ ! -e "$TEST_TEMP_DIR/ws-switch-calls" ]
}

@test "ws cd: workspace not found stays in place and fails" {
    run ws cd no-existe-xyz

    [ "$status" -ne 0 ]
    [[ "$output" == *"No se encontró ningún workspace"* ]]
    [ "$(pwd)" = "$TEST_TEMP_DIR/home" ]
}
