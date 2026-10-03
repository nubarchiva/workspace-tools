#!/usr/bin/env bats
# Tests para ws-doctor - Diagnóstico y reparación de workspaces

load 'test_helper'

setup() {
    setup_test_environment
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

run_ws_doctor() {
    env WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT" \
        WORKSPACES_DIR="$TEST_WORKSPACES_DIR" \
        WS_TOOLS="$WS_TOOLS_ROOT" \
        "$WS_TOOLS_ROOT/bin/ws-doctor" "$@"
}

# Workspace "doc" con un repo Maven (repo-mvn) y uno sin pom.xml (repo-plain)
create_healthy_workspace() {
    create_maven_repo "repo-mvn" >/dev/null
    create_test_repo "repo-plain" >/dev/null
    run_ws_new "doc" "repo-mvn" "repo-plain"
}

maven_config() {
    echo "$TEST_WORKSPACES_DIR/$1/repo-mvn/.mvn/maven.config"
}

# =============================================================================
# Ayuda y despachador
# =============================================================================

@test "ws-doctor: --help shows usage" {
    run run_ws_doctor --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"ws doctor"* ]]
    [[ "$output" == *"--fix"* ]]
    [[ "$output" == *"--all"* ]]
}

@test "ws-doctor: ws dispatches doctor" {
    create_healthy_workspace

    run run_ws doctor doc
    [ "$status" -eq 0 ]
    [[ "$output" == *"Sin problemas"* ]]
}

# =============================================================================
# Workspace sano
# =============================================================================

@test "ws-doctor: healthy workspace reports no problems" {
    create_healthy_workspace

    run run_ws_doctor doc
    [ "$status" -eq 0 ]
    [[ "$output" == *"Sin problemas"* ]]
}

# =============================================================================
# Aislamiento Maven
# =============================================================================

@test "ws-doctor: missing maven.config is reported" {
    create_healthy_workspace
    rm "$(maven_config doc)"

    run run_ws_doctor doc
    [ "$status" -eq 1 ]
    [[ "$output" == *"repo-mvn"* ]]
    [[ "$output" == *"maven.config"* ]]
    [ ! -f "$(maven_config doc)" ]
}

@test "ws-doctor: --fix creates missing maven.config" {
    create_healthy_workspace
    rm "$(maven_config doc)"

    run run_ws_doctor --fix doc
    [ "$status" -eq 0 ]
    grep -qxF -- "-Dmaven.repo.local=$WS_MAVEN_HEAD_BASE/doc/repository" "$(maven_config doc)"
}

@test "ws-doctor: maven.config pointing to another workspace is reported and fixed" {
    create_healthy_workspace
    printf '%s\n' "-Dmaven.repo.local=$WS_MAVEN_HEAD_BASE/otro/repository" \
        "-Dmaven.repo.local.tail=$WS_MAVEN_TAIL" > "$(maven_config doc)"

    run run_ws_doctor doc
    [ "$status" -eq 1 ]
    [[ "$output" == *"maven.config"* ]]

    run run_ws_doctor --fix doc
    [ "$status" -eq 0 ]
    grep -qxF -- "-Dmaven.repo.local=$WS_MAVEN_HEAD_BASE/doc/repository" "$(maven_config doc)"
}

@test "ws-doctor: maven.config not excluded from git is reported and fixed" {
    create_healthy_workspace
    exclude="$TEST_WORKSPACE_ROOT/repo-mvn/.git/info/exclude"
    grep -vxF '.mvn/maven.config' "$exclude" > "$exclude.tmp" || true
    mv "$exclude.tmp" "$exclude"

    run run_ws_doctor doc
    [ "$status" -eq 1 ]
    [[ "$output" == *"exclude"* ]]

    run run_ws_doctor --fix doc
    [ "$status" -eq 0 ]
    grep -qxF '.mvn/maven.config' "$exclude"
}

@test "ws-doctor: maven checks are skipped with isolation disabled" {
    create_healthy_workspace
    rm "$(maven_config doc)"

    WS_MAVEN_ISOLATION=false run run_ws_doctor doc
    [ "$status" -eq 0 ]
}

# =============================================================================
# Rama
# =============================================================================

@test "ws-doctor: unexpected branch is reported and not changed by --fix" {
    create_healthy_workspace
    git -C "$TEST_WORKSPACES_DIR/doc/repo-plain" checkout --quiet -b otra

    run run_ws_doctor --fix doc
    [ "$status" -eq 1 ]
    [[ "$output" == *"repo-plain"* ]]
    [[ "$output" == *"otra"* ]]
    [ "$(get_current_branch "$TEST_WORKSPACES_DIR/doc/repo-plain")" = "otra" ]
}

@test "ws-doctor: detached HEAD is reported" {
    create_healthy_workspace
    git -C "$TEST_WORKSPACES_DIR/doc/repo-plain" checkout --quiet --detach

    run run_ws_doctor doc
    [ "$status" -eq 1 ]
    [[ "$output" == *"desacoplado"* ]]
}

# =============================================================================
# Enlace del worktree con su repo origen
# =============================================================================

@test "ws-doctor: moved workspace is reported as unlinked and --fix repairs it" {
    create_healthy_workspace
    mv "$TEST_WORKSPACES_DIR/doc" "$TEST_WORKSPACES_DIR/doc2"
    # El nombre nuevo exige su propio maven.config: se aísla la comprobación del enlace
    WS_MAVEN_ISOLATION=false run run_ws_doctor doc2
    [ "$status" -eq 1 ]
    [[ "$output" == *"desenlazado"* ]]

    WS_MAVEN_ISOLATION=false run run_ws_doctor --fix doc2
    [[ "$output" == *"reparado"* ]]
    # La rama sigue siendo feature/doc: se informa, no se repara
    [[ "$output" == *"feature/doc2"* ]]

    WS_MAVEN_ISOLATION=false run run_ws_doctor doc2
    [[ "$output" != *"desenlazado"* ]]
    run git -C "$TEST_WORKSPACE_ROOT/repo-plain" worktree list --porcelain
    [[ "$output" != *"prunable"* ]]
    [[ "$output" == *"doc2/repo-plain"* ]]
}

@test "ws-doctor: missing worktree registration is reported" {
    create_healthy_workspace
    admin=$(sed -n 's/^gitdir: //p' "$TEST_WORKSPACES_DIR/doc/repo-plain/.git")
    rm -rf "$admin"

    run run_ws_doctor --fix doc
    [ "$status" -eq 1 ]
    [[ "$output" == *"repo-plain"* ]]
    [[ "$output" == *"registro"* ]]
}

# =============================================================================
# nuba-management y enlaces de configuración
# =============================================================================

@test "ws-doctor: own nuba-management worktree expects branch wt/<workspace>" {
    create_healthy_workspace
    create_test_repo "nuba-management" >/dev/null
    git -C "$TEST_WORKSPACE_ROOT/nuba-management" worktree add --quiet \
        -b wt/doc "$TEST_WORKSPACES_DIR/doc/nuba-management"

    run run_ws_doctor doc
    [ "$status" -eq 0 ]
    [[ "$output" == *"Sin problemas"* ]]
}

@test "ws-doctor: broken shared nuba-management symlink is reported" {
    create_healthy_workspace
    ln -s "$TEST_WORKSPACE_ROOT/no-existe" "$TEST_WORKSPACES_DIR/doc/nuba-management"

    run run_ws_doctor doc
    [ "$status" -eq 1 ]
    [[ "$output" == *"nuba-management"* ]]
}

@test "ws-doctor: broken AI.md symlink is reported" {
    create_healthy_workspace
    ln -s "$TEST_WORKSPACE_ROOT/no-existe.md" "$TEST_WORKSPACES_DIR/doc/AI.md"

    run run_ws_doctor doc
    [ "$status" -eq 1 ]
    [[ "$output" == *"AI.md"* ]]
}

# =============================================================================
# Comprobaciones globales (--all)
# =============================================================================

@test "ws-doctor: --all reports orphan maven head and --fix keeps it" {
    create_healthy_workspace
    mkdir -p "$WS_MAVEN_HEAD_BASE/borrado/repository"

    run run_ws_doctor --all --fix
    [ "$status" -eq 1 ]
    [[ "$output" == *"borrado"* ]]
    [ -d "$WS_MAVEN_HEAD_BASE/borrado" ]
}

@test "ws-doctor: --all reports orphan worktree registration and --fix prunes it" {
    create_healthy_workspace
    git -C "$TEST_WORKSPACE_ROOT/repo-plain" branch feature/tmp
    git -C "$TEST_WORKSPACE_ROOT/repo-plain" worktree add --quiet "$TEST_TEMP_DIR/tmp-wt" feature/tmp
    rm -rf "$TEST_TEMP_DIR/tmp-wt"

    run run_ws_doctor --all
    [ "$status" -eq 1 ]
    [[ "$output" == *"repo-plain"* ]]
    [[ "$output" == *"huérfano"* ]]

    run run_ws_doctor --all --fix
    [ "$status" -eq 0 ]
    run git -C "$TEST_WORKSPACE_ROOT/repo-plain" worktree list --porcelain
    [[ "$output" != *"prunable"* ]]
}

@test "ws-doctor: --all --fix repairs a moved workspace instead of pruning it" {
    create_healthy_workspace
    mv "$TEST_WORKSPACES_DIR/doc" "$TEST_WORKSPACES_DIR/doc2"

    WS_MAVEN_ISOLATION=false run run_ws_doctor --all
    [ "$status" -eq 1 ]
    [[ "$output" != *"huérfano"* ]]

    WS_MAVEN_ISOLATION=false run run_ws_doctor --all --fix
    [[ "$output" == *"reparado"* ]]
    [[ "$output" != *"huérfano"* ]]
    git -C "$TEST_WORKSPACES_DIR/doc2/repo-plain" status >/dev/null
    run git -C "$TEST_WORKSPACE_ROOT/repo-plain" worktree list --porcelain
    [[ "$output" == *"doc2/repo-plain"* ]]
}
