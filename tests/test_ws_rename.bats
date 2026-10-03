#!/usr/bin/env bats
# Tests para ws-rename - Renombrar workspaces

load 'test_helper'

setup() {
    setup_test_environment

    create_maven_repo "repo-mvn" >/dev/null
    create_test_repo "repo-plain" >/dev/null
    env WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT" \
        WORKSPACES_DIR="$TEST_WORKSPACES_DIR" \
        WS_TOOLS="$WS_TOOLS_ROOT" \
        "$WS_TOOLS_ROOT/bin/ws-new" "viejo" "repo-mvn" "repo-plain" >/dev/null 2>&1
}

teardown() {
    teardown_test_environment
}

# Confirma el renombrado con la palabra que pide ws rename
run_ws_rename() {
    echo "RENOMBRAR" | env WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT" \
        WORKSPACES_DIR="$TEST_WORKSPACES_DIR" \
        WS_TOOLS="$WS_TOOLS_ROOT" \
        "$WS_TOOLS_ROOT/bin/ws-rename" "$@"
}

# Worktree propio de nuba-management en la rama wt/viejo
add_management_worktree() {
    create_test_repo "nuba-management" >/dev/null
    git -C "$TEST_WORKSPACE_ROOT/nuba-management" worktree add --quiet \
        -b wt/viejo "$TEST_WORKSPACES_DIR/viejo/nuba-management"
}

@test "ws-rename: moves the directory and renames the feature branch" {
    run run_ws_rename viejo nuevo
    [ "$status" -eq 0 ]
    [ ! -d "$TEST_WORKSPACES_DIR/viejo" ]
    [ "$(get_current_branch "$TEST_WORKSPACES_DIR/nuevo/repo-plain")" = "feature/nuevo" ]
}

@test "ws-rename: the origin repo registers the worktree at its new path" {
    run run_ws_rename viejo nuevo
    [ "$status" -eq 0 ]

    run git -C "$TEST_WORKSPACE_ROOT/repo-plain" worktree list --porcelain
    [[ "$output" != *"prunable"* ]]
    [[ "$output" == *"nuevo/repo-plain"* ]]
}

@test "ws-rename: maven.config points to the new workspace" {
    run run_ws_rename viejo nuevo
    [ "$status" -eq 0 ]

    config="$TEST_WORKSPACES_DIR/nuevo/repo-mvn/.mvn/maven.config"
    grep -qxF -- "-Dmaven.repo.local=$WS_MAVEN_HEAD_BASE/nuevo/repository" "$config"
}

@test "ws-rename: the workspace maven repository moves with it" {
    mkdir -p "$WS_MAVEN_HEAD_BASE/viejo/repository/com/test"

    run run_ws_rename viejo nuevo
    [ "$status" -eq 0 ]
    [ -d "$WS_MAVEN_HEAD_BASE/nuevo/repository/com/test" ]
    [ ! -d "$WS_MAVEN_HEAD_BASE/viejo" ]
}

@test "ws-rename: an existing maven repository for the new name is kept" {
    mkdir -p "$WS_MAVEN_HEAD_BASE/viejo/repository/com/viejo"
    mkdir -p "$WS_MAVEN_HEAD_BASE/nuevo/repository/com/nuevo"

    run run_ws_rename viejo nuevo
    [ "$status" -eq 0 ]
    [ -d "$WS_MAVEN_HEAD_BASE/nuevo/repository/com/nuevo" ]
    [ -d "$WS_MAVEN_HEAD_BASE/viejo/repository/com/viejo" ]
    [[ "$output" == *"$WS_MAVEN_HEAD_BASE/viejo"* ]]
}

@test "ws-rename: own nuba-management worktree moves to branch wt/<new>" {
    add_management_worktree

    run run_ws_rename viejo nuevo
    [ "$status" -eq 0 ]
    [ "$(get_current_branch "$TEST_WORKSPACES_DIR/nuevo/nuba-management")" = "wt/nuevo" ]
}

@test "ws-rename: .claude/CLAUDE.md describes the new workspace" {
    run run_ws_rename viejo nuevo
    [ "$status" -eq 0 ]

    claude_md="$TEST_WORKSPACES_DIR/nuevo/.claude/CLAUDE.md"
    grep -qF "# Worktree: nuevo" "$claude_md"
    grep -qF "$TEST_WORKSPACES_DIR/nuevo" "$claude_md"
    ! grep -qF "viejo" "$claude_md"
}

@test "ws-rename: ws doctor finds nothing to fix after renaming" {
    add_management_worktree

    run run_ws_rename viejo nuevo
    [ "$status" -eq 0 ]

    run env WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT" \
        WORKSPACES_DIR="$TEST_WORKSPACES_DIR" \
        "$WS_TOOLS_ROOT/bin/ws-doctor" --all
    [ "$status" -eq 0 ]
}
