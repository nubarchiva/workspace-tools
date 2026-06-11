#!/usr/bin/env bats
# Tests para ws-maven-utils.sh - Aislamiento del repositorio Maven por workspace

load 'test_helper'

setup() {
    setup_test_environment
    source "$WS_TOOLS_ROOT/bin/ws-maven-utils.sh"
}

teardown() {
    teardown_test_environment
}

# =============================================================================
# Tests de composición de rutas
# =============================================================================

@test "maven-utils: maven_head_repo composes base/workspace/repository" {
    result=$(maven_head_repo "mi-ws")
    [ "$result" = "$WS_MAVEN_HEAD_BASE/mi-ws/repository" ]
}

@test "maven-utils: maven_head_dir is the workspace root under the base" {
    result=$(maven_head_dir "mi-ws")
    [ "$result" = "$WS_MAVEN_HEAD_BASE/mi-ws" ]
}

@test "maven-utils: maven_tail_repo honors WS_MAVEN_TAIL" {
    result=$(maven_tail_repo)
    [ "$result" = "$WS_MAVEN_TAIL" ]
}

@test "maven-utils: maven_tail_repo defaults to ~/.m2/repository" {
    unset WS_MAVEN_TAIL
    result=$(maven_tail_repo)
    [ "$result" = "$HOME/.m2/repository" ]
}

# =============================================================================
# Tests de activación
# =============================================================================

@test "maven-utils: isolation enabled by default" {
    unset WS_MAVEN_ISOLATION
    maven_isolation_enabled
}

@test "maven-utils: WS_MAVEN_ISOLATION=false disables isolation" {
    WS_MAVEN_ISOLATION=false
    ! maven_isolation_enabled
}

# =============================================================================
# Tests de setup_maven_isolation
# =============================================================================

@test "maven-utils: setup writes head and tail to maven.config" {
    create_maven_repo "repo-cfg"

    setup_maven_isolation "$TEST_WORKSPACE_ROOT/repo-cfg" "ws-cfg"

    config="$TEST_WORKSPACE_ROOT/repo-cfg/.mvn/maven.config"
    [ -f "$config" ]
    grep -qxF -- "-Dmaven.repo.local=$WS_MAVEN_HEAD_BASE/ws-cfg/repository" "$config"
    grep -qxF -- "-Dmaven.repo.local.tail=$WS_MAVEN_TAIL" "$config"
}

@test "maven-utils: setup skips repo without pom.xml" {
    create_test_repo "repo-sin-pom"

    ! setup_maven_isolation "$TEST_WORKSPACE_ROOT/repo-sin-pom" "ws-x"
    [ ! -e "$TEST_WORKSPACE_ROOT/repo-sin-pom/.mvn" ]
}

@test "maven-utils: setup skips when isolation disabled" {
    create_maven_repo "repo-off"

    WS_MAVEN_ISOLATION=false
    ! setup_maven_isolation "$TEST_WORKSPACE_ROOT/repo-off" "ws-x"
    [ ! -e "$TEST_WORKSPACE_ROOT/repo-off/.mvn" ]
}

@test "maven-utils: setup excludes maven.config from git" {
    create_maven_repo "repo-excl"

    setup_maven_isolation "$TEST_WORKSPACE_ROOT/repo-excl" "ws-excl"

    grep -qxF '.mvn/maven.config' "$TEST_WORKSPACE_ROOT/repo-excl/.git/info/exclude"

    cd "$TEST_WORKSPACE_ROOT/repo-excl"
    [ -z "$(git status --porcelain)" ]
}

@test "maven-utils: setup is idempotent (single exclude line, config rewritten)" {
    create_maven_repo "repo-idem"

    setup_maven_isolation "$TEST_WORKSPACE_ROOT/repo-idem" "ws-idem"
    setup_maven_isolation "$TEST_WORKSPACE_ROOT/repo-idem" "ws-idem"

    count=$(grep -cxF '.mvn/maven.config' "$TEST_WORKSPACE_ROOT/repo-idem/.git/info/exclude")
    [ "$count" -eq 1 ]
}
