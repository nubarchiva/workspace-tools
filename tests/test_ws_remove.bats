#!/usr/bin/env bats
# Tests para ws-remove - Quitar repos de un workspace

load 'test_helper'

setup() {
    setup_test_environment
    create_test_repo "repo-a" >/dev/null
    create_test_repo "repo-b" >/dev/null
}

teardown() {
    teardown_test_environment
}

run_ws_new() {
    env WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT" \
        WORKSPACES_DIR="$TEST_WORKSPACES_DIR" \
        WS_TOOLS="$WS_TOOLS_ROOT" \
        "$WS_TOOLS_ROOT/bin/ws-new" "$@" >/dev/null 2>&1
}

# Confirma la eliminación con la respuesta que pide ws remove
run_ws_remove() {
    echo "s" | env WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT" \
        WORKSPACES_DIR="$TEST_WORKSPACES_DIR" \
        WS_TOOLS="$WS_TOOLS_ROOT" \
        "$WS_TOOLS_ROOT/bin/ws-remove" "$@"
}

branch_exists() {
    git -C "$TEST_WORKSPACE_ROOT/$1" show-ref --verify --quiet "refs/heads/$2"
}

@test "ws-remove: removes the worktree and the feature branch" {
    run_ws_new "fea" "repo-a" "repo-b"

    run run_ws_remove "fea" "repo-a"
    [ "$status" -eq 0 ]
    [ ! -d "$TEST_WORKSPACES_DIR/fea/repo-a" ]
    ! branch_exists "repo-a" "feature/fea"
    [ -d "$TEST_WORKSPACES_DIR/fea/repo-b" ]
}

@test "ws-remove: keeps the integration branch of a branch workspace" {
    git -C "$TEST_WORKSPACE_ROOT/repo-a" branch develop
    git -C "$TEST_WORKSPACE_ROOT/repo-b" branch develop
    run_ws_new "develop" "repo-a" "repo-b"

    run run_ws_remove "develop" "repo-a"
    [ "$status" -eq 0 ]
    [ ! -d "$TEST_WORKSPACES_DIR/develop/repo-a" ]
    branch_exists "repo-a" "develop"
    [[ "$output" == *"develop"* ]]
}
