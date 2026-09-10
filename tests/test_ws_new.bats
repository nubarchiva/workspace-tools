#!/usr/bin/env bats
# Tests para ws-new - Crear workspaces

load 'test_helper'

setup() {
    setup_test_environment
}

teardown() {
    teardown_test_environment
}

# Helper para ejecutar ws-new con entorno de test
run_ws_new() {
    env WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT" \
        WORKSPACES_DIR="$TEST_WORKSPACES_DIR" \
        WS_TOOLS="$WS_TOOLS_ROOT" \
        "$WS_TOOLS_ROOT/bin/ws-new" "$@"
}

# =============================================================================
# Tests de ayuda y validacion basica
# =============================================================================

@test "ws-new: no args shows help and exits with 1" {
    run run_ws_new
    [ "$status" -eq 1 ]
    [[ "$output" == *"Uso:"* ]]
}

@test "ws-new: help shows examples" {
    run run_ws_new
    [[ "$output" == *"Ejemplos"* ]]
    [[ "$output" == *"ws new"* ]]
}

@test "ws-new: help mentions master and develop" {
    run run_ws_new
    [[ "$output" == *"master"* ]]
    [[ "$output" == *"develop"* ]]
}

@test "ws-new: empty name shows help" {
    run run_ws_new ""
    [ "$status" -eq 1 ]
    [[ "$output" == *"Uso:"* ]]
}

# =============================================================================
# Tests de creacion de workspace
# =============================================================================

@test "ws-new: creates workspace directory" {
    run run_ws_new "test-workspace"
    [ "$status" -eq 0 ]
    [ -d "$TEST_WORKSPACES_DIR/test-workspace" ]
}

@test "ws-new: workspace without repos shows informative message" {
    run run_ws_new "empty-workspace"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ws add"* ]]
}

@test "ws-new: creates workspace with one repo" {
    create_test_repo "mi-repo"

    run run_ws_new "test-ws" "mi-repo"
    [ "$status" -eq 0 ]
    [ -d "$TEST_WORKSPACES_DIR/test-ws" ]
    [ -d "$TEST_WORKSPACES_DIR/test-ws/mi-repo" ]
}

@test "ws-new: creates workspace with multiple repos" {
    create_test_repo "repo-a"
    create_test_repo "repo-b"

    run run_ws_new "multi-ws" "repo-a" "repo-b"
    [ "$status" -eq 0 ]
    [ -d "$TEST_WORKSPACES_DIR/multi-ws/repo-a" ]
    [ -d "$TEST_WORKSPACES_DIR/multi-ws/repo-b" ]
}

@test "ws-new: creates workspace with repo in subdirectory" {
    create_test_repo "libs/mi-lib"

    run run_ws_new "subdir-ws" "libs/mi-lib"
    [ "$status" -eq 0 ]
    [ -d "$TEST_WORKSPACES_DIR/subdir-ws/libs/mi-lib" ]
}

@test "ws-new: nonexistent repo shows warning but does not fail" {
    run run_ws_new "test-ws" "repo-que-no-existe"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no encontrado"* ]] || [[ "$output" == *"saltando"* ]]
}

# =============================================================================
# Tests de templates
# =============================================================================

@test "ws-new: template with repo in subdirectory creates all worktrees" {
    create_test_repo "repo-a"
    create_test_repo "modules/sub-repo"
    echo "mi-template: repo-a modules/sub-repo" > "$TEST_WORKSPACE_ROOT/.ws-templates"

    run run_ws_new "tpl-ws" --template "mi-template"
    [ "$status" -eq 0 ]
    [ -d "$TEST_WORKSPACES_DIR/tpl-ws/repo-a" ]
    [ -d "$TEST_WORKSPACES_DIR/tpl-ws/modules/sub-repo" ]
}

@test "ws-new: template repos combine with manual repos without duplicates" {
    create_test_repo "repo-a"
    create_test_repo "modules/sub-repo"
    create_test_repo "repo-b"
    echo "mi-template: repo-a modules/sub-repo" > "$TEST_WORKSPACE_ROOT/.ws-templates"

    run run_ws_new "dedup-ws" --template "mi-template" "modules/sub-repo" "repo-b"
    [ "$status" -eq 0 ]
    [ -d "$TEST_WORKSPACES_DIR/dedup-ws/repo-a" ]
    [ -d "$TEST_WORKSPACES_DIR/dedup-ws/modules/sub-repo" ]
    [ -d "$TEST_WORKSPACES_DIR/dedup-ws/repo-b" ]
    [[ "$output" == *"Repos a incluir: repo-a modules/sub-repo repo-b"* ]]
}

@test "ws-new: nonexistent template fails with error" {
    echo "otro: repo-a" > "$TEST_WORKSPACE_ROOT/.ws-templates"

    run run_ws_new "tpl-ws" --template "no-existe"
    [ "$status" -eq 1 ]
    [[ "$output" == *"no encontrado"* ]]
}

# =============================================================================
# Tests de branches
# =============================================================================

@test "ws-new: master uses master branch" {
    create_test_repo "mi-repo"

    # Cambiar el repo principal a otra branch para poder crear worktree en master
    cd "$TEST_WORKSPACE_ROOT/mi-repo"
    git checkout -b temp-branch --quiet
    cd - > /dev/null

    run run_ws_new "master" "mi-repo"
    [ "$status" -eq 0 ]

    # Verificar que el worktree existe
    [ -d "$TEST_WORKSPACES_DIR/master/mi-repo" ]

    cd "$TEST_WORKSPACES_DIR/master/mi-repo"
    branch=$(git branch --show-current)
    [ "$branch" = "master" ]
}

@test "ws-new: develop uses develop branch" {
    create_test_repo "mi-repo"

    # Crear branch develop si no existe
    cd "$TEST_WORKSPACE_ROOT/mi-repo"
    if ! git rev-parse --verify develop >/dev/null 2>&1; then
        git checkout -b develop --quiet
        git checkout master --quiet
    fi
    cd - > /dev/null

    run run_ws_new "develop" "mi-repo"
    [ "$status" -eq 0 ]

    cd "$TEST_WORKSPACES_DIR/develop/mi-repo"
    branch=$(git branch --show-current)
    [ "$branch" = "develop" ]
}

@test "ws-new: feature creates branch feature/nombre" {
    create_test_repo "mi-repo"

    run run_ws_new "mi-feature" "mi-repo"
    [ "$status" -eq 0 ]

    cd "$TEST_WORKSPACES_DIR/mi-feature/mi-repo"
    branch=$(git branch --show-current)
    [ "$branch" = "feature/mi-feature" ]
}

# =============================================================================
# Tests de worktrees
# =============================================================================

@test "ws-new: creates valid git worktree" {
    create_test_repo "mi-repo"

    run run_ws_new "worktree-test" "mi-repo"
    [ "$status" -eq 0 ]

    [ -f "$TEST_WORKSPACES_DIR/worktree-test/mi-repo/.git" ] || \
    [ -d "$TEST_WORKSPACES_DIR/worktree-test/mi-repo/.git" ]

    cd "$TEST_WORKSPACES_DIR/worktree-test/mi-repo"
    run git status
    [ "$status" -eq 0 ]
}

@test "ws-new: worktree appears in git worktree list" {
    create_test_repo "mi-repo"

    run_ws_new "listed-ws" "mi-repo"

    cd "$TEST_WORKSPACE_ROOT/mi-repo"
    run git worktree list
    [ "$status" -eq 0 ]
    [[ "$output" == *"listed-ws"* ]]
}

# =============================================================================
# Tests de aislamiento Maven
# =============================================================================

@test "ws-new: maven repo gets .mvn/maven.config with workspace head" {
    create_maven_repo "repo-mvn"

    run run_ws_new "iso-ws" "repo-mvn"
    [ "$status" -eq 0 ]

    config="$TEST_WORKSPACES_DIR/iso-ws/repo-mvn/.mvn/maven.config"
    [ -f "$config" ]
    grep -qxF -- "-Dmaven.repo.local=$WS_MAVEN_HEAD_BASE/iso-ws/repository" "$config"
    grep -qxF -- "-Dmaven.repo.local.tail=$WS_MAVEN_TAIL" "$config"
}

@test "ws-new: maven.config does not dirty the worktree" {
    create_maven_repo "repo-mvn"

    run run_ws_new "excl-ws" "repo-mvn"
    [ "$status" -eq 0 ]

    grep -qxF '.mvn/maven.config' "$TEST_WORKSPACE_ROOT/repo-mvn/.git/info/exclude"

    cd "$TEST_WORKSPACES_DIR/excl-ws/repo-mvn"
    [ -z "$(git status --porcelain)" ]
}

@test "ws-new: repo without pom.xml does not get maven.config" {
    create_test_repo "repo-plain"

    run run_ws_new "plain-ws" "repo-plain"
    [ "$status" -eq 0 ]
    [ ! -e "$TEST_WORKSPACES_DIR/plain-ws/repo-plain/.mvn" ]
}

@test "ws-new: WS_MAVEN_ISOLATION=false disables isolation" {
    create_maven_repo "repo-mvn"

    WS_MAVEN_ISOLATION=false run run_ws_new "no-iso-ws" "repo-mvn"
    [ "$status" -eq 0 ]
    [ ! -e "$TEST_WORKSPACES_DIR/no-iso-ws/repo-mvn/.mvn" ]
}

@test "ws-new: prints hint to populate the maven head" {
    create_maven_repo "repo-mvn"

    run run_ws_new "hint-ws" "repo-mvn"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ws mvn hint-ws install -DskipTests -nsu"* ]]
}
