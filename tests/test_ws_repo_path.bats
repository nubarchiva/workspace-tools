#!/usr/bin/env bats
# Tests para ws-repo-path y la función wscd que lo usa

load 'test_helper'

setup() {
    setup_test_environment
    mkdir -p "$TEST_WORKSPACES_DIR/solr-upgrade/ks-nuba/.git"
    mkdir -p "$TEST_WORKSPACES_DIR/solr-upgrade/dga-commons/.git"
    mkdir -p "$TEST_WORKSPACES_DIR/otro-evolutivo"
    mkdir -p "$TEST_TEMP_DIR/home"
}

teardown() {
    teardown_test_environment
}

# Carga la función wscd de setup.sh sin ejecutar el resto del script
load_wscd() {
    eval "$(sed -n '/^wscd()/,/^}/p' "$WS_TOOLS_ROOT/setup.sh")"
}

# =============================================================================
# Dentro de un workspace: navegación entre sus repos
# =============================================================================

@test "ws-repo-path: inside workspace returns the matching repo path" {
    cd "$TEST_WORKSPACES_DIR/solr-upgrade/ks-nuba"

    run "$WS_TOOLS_ROOT/bin/ws-repo-path" commons

    [ "$status" -eq 0 ]
    [ "$output" = "$TEST_WORKSPACES_DIR/solr-upgrade/dga-commons" ]
}

# =============================================================================
# Fuera de un workspace
# =============================================================================

@test "ws-repo-path: outside workspace with pattern matching a workspace exits 3 without output" {
    cd "$TEST_TEMP_DIR/home"

    run "$WS_TOOLS_ROOT/bin/ws-repo-path" solr

    [ "$status" -eq 3 ]
    [ -z "$output" ]
}

@test "ws-repo-path: outside workspace with pattern matching no workspace explains ws cd" {
    cd "$TEST_TEMP_DIR/home"

    run "$WS_TOOLS_ROOT/bin/ws-repo-path" no-existe-xyz

    [ "$status" -eq 1 ]
    [[ "$output" == *"No estás dentro de un workspace"* ]]
    [[ "$output" == *"'no-existe-xyz'"* ]]
    [[ "$output" == *"ws cd <nombre>"* ]]
    [[ "$output" == *"solr-upgrade"* ]]
    [[ "$output" == *"otro-evolutivo"* ]]
}

@test "ws-repo-path: outside workspace without pattern explains ws cd" {
    cd "$TEST_TEMP_DIR/home"

    run "$WS_TOOLS_ROOT/bin/ws-repo-path"

    [ "$status" -eq 1 ]
    [[ "$output" == *"No estás dentro de un workspace"* ]]
    [[ "$output" == *"ws cd <nombre>"* ]]
    [[ "$output" == *"solr-upgrade"* ]]
}

@test "ws-repo-path: outside workspace '.' is not taken as a workspace pattern" {
    cd "$TEST_TEMP_DIR/home"

    run "$WS_TOOLS_ROOT/bin/ws-repo-path" .

    [ "$status" -eq 1 ]
    [[ "$output" == *"ws cd <nombre>"* ]]
}

# =============================================================================
# wscd
# =============================================================================

@test "wscd: outside workspace with pattern matching a workspace runs ws cd" {
    load_wscd
    ws() { echo "ws $*"; }
    cd "$TEST_TEMP_DIR/home"

    run wscd solr

    [ "$status" -eq 0 ]
    [ "$output" = "ws cd solr" ]
}

@test "wscd: outside workspace with pattern matching no workspace shows the explanation" {
    load_wscd
    ws() { echo "ws $*"; }
    cd "$TEST_TEMP_DIR/home"

    run wscd no-existe-xyz

    [ "$status" -eq 1 ]
    [[ "$output" == *"ws cd <nombre>"* ]]
    [[ "$output" != "ws cd"* ]]
}

@test "wscd: inside workspace changes to the matching repo" {
    load_wscd
    cd "$TEST_WORKSPACES_DIR/solr-upgrade/ks-nuba"

    wscd commons

    [ "$(pwd)" = "$TEST_WORKSPACES_DIR/solr-upgrade/dga-commons" ]
}
