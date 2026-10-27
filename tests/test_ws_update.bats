#!/usr/bin/env bats
# Tests para ws-update
# Verifica la actualización interactiva y el contrato de --summary, --keep-conflicts y --push

load 'test_helper'

WS="evol"

setup() {
    setup_test_environment
    mkdir -p "$TEST_TEMP_DIR/remotes" "$TEST_TEMP_DIR/publishers"
}

teardown() {
    teardown_test_environment
}

run_update() {
    env WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT" \
        WORKSPACES_DIR="$TEST_WORKSPACES_DIR" \
        WS_TOOLS="$WS_TOOLS_ROOT" \
        "$WS_TOOLS_ROOT/bin/ws-update" "$@"
}

# Repo con remoto propio, clon origen y worktree en la rama del workspace
# Uso: add_repo <repo> [rama_base]
add_repo() {
    local repo=$1
    local base=${2:-develop}
    local remote="$TEST_TEMP_DIR/remotes/$repo.git"
    local publisher="$TEST_TEMP_DIR/publishers/$repo"
    local clone="$TEST_WORKSPACE_ROOT/$repo"

    git init --quiet --bare --initial-branch="$base" "$remote"
    git init --quiet --initial-branch="$base" "$publisher"
    git -C "$publisher" config user.email "test@test.com"
    git -C "$publisher" config user.name "Test User"
    printf 'uno\ndos\ntres\n' > "$publisher/shared.txt"
    git -C "$publisher" add shared.txt
    git -C "$publisher" commit --quiet -m "Initial commit"
    git -C "$publisher" remote add origin "$remote"
    git -C "$publisher" push --quiet origin "$base"

    git clone --quiet "$remote" "$clone"
    git -C "$clone" config user.email "test@test.com"
    git -C "$clone" config user.name "Test User"
    git -C "$clone" worktree add --quiet --no-track -b "feature/$WS" \
        "$TEST_WORKSPACES_DIR/$WS/$repo" "origin/$base"
}

repo_dir() {
    echo "$TEST_WORKSPACES_DIR/$WS/$1"
}

# Publica en develop un commit que cambia un fichero del repo
# Uso: publish_on_develop <repo> <fichero> <contenido>
publish_on_develop() {
    local publisher="$TEST_TEMP_DIR/publishers/$1"
    printf '%s\n' "$3" > "$publisher/$2"
    git -C "$publisher" add "$2"
    git -C "$publisher" commit --quiet -m "develop: $2"
    git -C "$publisher" push --quiet origin develop
}

# Commit en la rama del workspace
# Uso: commit_on_branch <repo> <fichero> <contenido>
commit_on_branch() {
    local dir
    dir=$(repo_dir "$1")
    printf '%s\n' "$3" > "$dir/$2"
    git -C "$dir" add "$2"
    git -C "$dir" commit --quiet -m "branch: $2"
}

# Deja el repo con un conflicto entre develop y la rama del workspace en shared.txt
prepare_conflict() {
    publish_on_develop "$1" shared.txt "desde develop"
    commit_on_branch "$1" shared.txt "desde la rama"
}

short_head() {
    git -C "$(repo_dir "$1")" rev-parse --short HEAD
}

merge_in_progress() {
    git -C "$(repo_dir "$1")" rev-parse -q --verify MERGE_HEAD >/dev/null
}

# =============================================================================
# Uso interactivo: no cambia
# =============================================================================

@test "ws-update: interactive mode stops at the first conflict and aborts the merge" {
    add_repo repo-a
    add_repo repo-b
    prepare_conflict repo-a
    publish_on_develop repo-b nuevo.txt "nuevo"

    run run_update "$WS"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Actualización detenida por conflictos"* ]]
    ! merge_in_progress repo-a
    [ ! -f "$(repo_dir repo-b)/nuevo.txt" ]
}

@test "ws-update: interactive --keep-conflicts leaves the merge open and goes on with the next repo" {
    add_repo repo-a
    add_repo repo-b
    prepare_conflict repo-a
    publish_on_develop repo-b nuevo.txt "nuevo"

    run run_update "$WS" --keep-conflicts

    [ "$status" -eq 1 ]
    merge_in_progress repo-a
    grep -q '^<<<<<<<' "$(repo_dir repo-a)/shared.txt"
    [ -f "$(repo_dir repo-b)/nuevo.txt" ]
}

@test "ws-update: --all --keep-conflicts leaves the merge open" {
    add_repo repo-a
    prepare_conflict repo-a

    run run_update --all --keep-conflicts

    merge_in_progress repo-a
}

# =============================================================================
# --summary: una línea por repositorio
# =============================================================================

@test "ws-update: --summary reports each repo state on one line" {
    add_repo repo-ff
    add_repo repo-merge
    add_repo repo-same
    local before
    before=$(short_head repo-ff)
    publish_on_develop repo-ff nuevo.txt "nuevo"
    publish_on_develop repo-merge nuevo.txt "nuevo"
    commit_on_branch repo-merge propio.txt "propio"

    run run_update "$WS" --summary

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "fast-forward repo-ff origin/develop $before..$(short_head repo-ff)" ]
    [ "${lines[1]}" = "merged repo-merge origin/develop $(short_head repo-merge)" ]
    [ "${lines[2]}" = "up-to-date repo-same origin/develop" ]
    [ "${#lines[@]}" -eq 3 ]
    [ "$(git -C "$(repo_dir repo-merge)" rev-list --parents -n 1 HEAD | wc -w | tr -d ' ')" -eq 3 ]
}

@test "ws-update: --summary goes on after a conflict and aborts it by default" {
    add_repo repo-a
    add_repo repo-b
    prepare_conflict repo-a
    local before
    before=$(short_head repo-b)
    publish_on_develop repo-b nuevo.txt "nuevo"

    run run_update "$WS" --summary

    [ "$status" -eq 1 ]
    [ "${lines[0]}" = "conflict repo-a origin/develop aborted shared.txt" ]
    [ "${lines[1]}" = "fast-forward repo-b origin/develop $before..$(short_head repo-b)" ]
    ! merge_in_progress repo-a
    [ -f "$(repo_dir repo-b)/nuevo.txt" ]
}

@test "ws-update: --summary --keep-conflicts lists the conflicted files and leaves the merge open" {
    add_repo repo-a
    prepare_conflict repo-a
    publish_on_develop repo-a otro.txt "otro"
    commit_on_branch repo-a otro.txt "otro de la rama"

    run run_update "$WS" --summary --keep-conflicts

    [ "$status" -eq 1 ]
    [ "$output" = "conflict repo-a origin/develop open otro.txt shared.txt" ]
    merge_in_progress repo-a
}

@test "ws-update: --summary skips a repo with a merge in progress" {
    add_repo repo-a
    prepare_conflict repo-a
    run_update "$WS" --summary --keep-conflicts || true

    run run_update "$WS" --summary

    [ "$status" -eq 2 ]
    [ "$output" = "skipped repo-a merge-in-progress" ]
    merge_in_progress repo-a
}

@test "ws-update: --summary skips a repo with uncommitted changes" {
    add_repo repo-a
    publish_on_develop repo-a nuevo.txt "nuevo"
    echo "local" > "$(repo_dir repo-a)/local.txt"

    run run_update "$WS" --summary

    [ "$status" -eq 2 ]
    [ "$output" = "skipped repo-a uncommitted-changes" ]
}

@test "ws-update: --summary skips a repo without base branch" {
    add_repo repo-a trunk

    run run_update "$WS" --summary

    [ "$status" -eq 2 ]
    [ "$output" = "skipped repo-a no-base-branch" ]
}

@test "ws-update: --summary skips a repo that is not on the workspace branch" {
    add_repo repo-a
    git -C "$(repo_dir repo-a)" switch --quiet -c otra

    run run_update "$WS" --summary

    [ "$status" -eq 2 ]
    [ "$output" = "skipped repo-a not-on-workspace-branch otra" ]
}

@test "ws-update: --summary reports an unreachable remote as an error" {
    add_repo repo-a
    git -C "$TEST_WORKSPACE_ROOT/repo-a" remote set-url origin "$TEST_TEMP_DIR/no-existe.git"

    run run_update "$WS" --summary

    [ "$status" -eq 2 ]
    [ "$output" = "error repo-a remote-unreachable" ]
}

@test "ws-update: --summary reports a merge that git refuses as an error" {
    add_repo repo-a
    local publisher="$TEST_TEMP_DIR/publishers/repo-a"
    git -C "$publisher" switch --quiet --orphan otra-historia
    echo "otra" > "$publisher/otra.txt"
    git -C "$publisher" add otra.txt
    git -C "$publisher" commit --quiet -m "otra historia"
    git -C "$publisher" push --quiet --force origin otra-historia:develop

    run run_update "$WS" --summary

    [ "$status" -eq 2 ]
    [ "${#lines[@]}" -eq 1 ]
    [[ "$output" == "error repo-a merge-failed "?* ]]
    ! merge_in_progress repo-a
}

@test "ws-update: --summary leaves nuba-management out" {
    add_repo repo-a
    create_test_repo "nuba-management" >/dev/null
    git -C "$TEST_WORKSPACE_ROOT/nuba-management" worktree add --quiet \
        -b "wt/$WS" "$TEST_WORKSPACES_DIR/$WS/nuba-management"

    run run_update "$WS" --summary

    [ "$status" -eq 0 ]
    [ "$output" = "up-to-date repo-a origin/develop" ]
}

@test "ws-update: --summary resolves the auto-detected workspace without printing it" {
    add_repo repo-a
    cd "$(repo_dir repo-a)"

    run run_update --summary

    [ "$status" -eq 0 ]
    [ "$output" = "up-to-date repo-a origin/develop" ]
}

@test "ws-update: --summary fails with code 2 when the workspace does not exist" {
    run run_update no-existe --summary

    [ "$status" -eq 2 ]
}

@test "ws-update: --summary fails with code 2 when the pattern matches several workspaces" {
    mkdir -p "$TEST_WORKSPACES_DIR/evol-uno" "$TEST_WORKSPACES_DIR/evol-dos"

    run run_update evol- --summary < /dev/null

    [ "$status" -eq 2 ]
}

@test "ws-update: --summary uses the exact workspace name when it is a prefix of another" {
    add_repo repo-a
    mkdir -p "$TEST_WORKSPACES_DIR/$WS-bis"

    run run_update "$WS" --summary < /dev/null

    [ "$status" -eq 0 ]
    [ "$output" = "up-to-date repo-a origin/develop" ]
}

@test "ws-update: merge-only options reject --rebase, --all and --dry with code 2" {
    add_repo repo-a

    run run_update "$WS" --summary --rebase
    [ "$status" -eq 2 ]
    run run_update "$WS" --keep-conflicts --rebase
    [ "$status" -eq 2 ]
    run run_update --all --summary
    [ "$status" -eq 2 ]
    run run_update "$WS" --summary --dry
    [ "$status" -eq 2 ]
    run run_update "$WS" --push --keep-conflicts
    [ "$status" -eq 2 ]
}

# =============================================================================
# --push: publicar la rama del workspace
# =============================================================================

@test "ws-update: --push publishes the commits ahead of the remote branch" {
    add_repo repo-a
    commit_on_branch repo-a propio.txt "propio"
    git -C "$(repo_dir repo-a)" push --quiet origin "feature/$WS"
    local before
    before=$(short_head repo-a)
    publish_on_develop repo-a nuevo.txt "nuevo"
    run_update "$WS" --summary

    run run_update "$WS" --push

    [ "$status" -eq 0 ]
    [ "$output" = "pushed repo-a feature/$WS $before..$(short_head repo-a)" ]
    [ "$(git -C "$TEST_TEMP_DIR/remotes/repo-a.git" rev-parse --short "feature/$WS")" = "$(short_head repo-a)" ]
}

@test "ws-update: --push creates the remote branch when it does not exist" {
    add_repo repo-a
    commit_on_branch repo-a propio.txt "propio"

    run run_update "$WS" --push

    [ "$status" -eq 0 ]
    [ "$output" = "pushed repo-a feature/$WS new..$(short_head repo-a)" ]
}

@test "ws-update: --push does not create the remote branch without commits of its own" {
    add_repo repo-a
    publish_on_develop repo-a nuevo.txt "nuevo"
    run_update "$WS" --summary

    run run_update "$WS" --push

    [ "$status" -eq 0 ]
    [ "$output" = "unpublished repo-a feature/$WS no-own-commits origin/develop" ]
    ! git -C "$TEST_TEMP_DIR/remotes/repo-a.git" rev-parse -q --verify "feature/$WS"
}

@test "ws-update: --summary and --push take the remote base, not a local develop retired from origin" {
    add_repo repo-a master
    local clone="$TEST_WORKSPACE_ROOT/repo-a"
    local publisher="$TEST_TEMP_DIR/publishers/repo-a"
    git -C "$clone" push --quiet -u origin master:develop
    git -C "$clone" branch --quiet --track develop origin/develop
    git -C "$clone" push --quiet origin --delete develop
    git -C "$clone" fetch --quiet --prune
    printf 'nuevo\n' > "$publisher/nuevo.txt"
    git -C "$publisher" add nuevo.txt
    git -C "$publisher" commit --quiet -m "master: nuevo.txt"
    git -C "$publisher" push --quiet origin master
    local before
    before=$(short_head repo-a)

    run run_update "$WS" --summary

    [ "$status" -eq 0 ]
    [ "$output" = "fast-forward repo-a origin/master $before..$(short_head repo-a)" ]

    run run_update "$WS" --push

    [ "$status" -eq 0 ]
    [ "$output" = "unpublished repo-a feature/$WS no-own-commits origin/master" ]
    ! git -C "$TEST_TEMP_DIR/remotes/repo-a.git" rev-parse -q --verify "feature/$WS"
}

@test "ws-update: --push does not create the remote branch without a base branch to compare with" {
    add_repo repo-a trunk
    commit_on_branch repo-a propio.txt "propio"

    run run_update "$WS" --push

    [ "$status" -eq 2 ]
    [ "$output" = "skipped repo-a no-base-branch" ]
    ! git -C "$TEST_TEMP_DIR/remotes/repo-a.git" rev-parse -q --verify "feature/$WS"
}

@test "ws-update: --push keeps publishing a remote branch without commits of its own" {
    add_repo repo-a
    git -C "$(repo_dir repo-a)" push --quiet origin "feature/$WS"
    local before
    before=$(short_head repo-a)
    publish_on_develop repo-a nuevo.txt "nuevo"
    run_update "$WS" --summary

    run run_update "$WS" --push

    [ "$status" -eq 0 ]
    [ "$output" = "pushed repo-a feature/$WS $before..$(short_head repo-a)" ]
}

@test "ws-update: --push reports up-to-date when there is nothing to publish" {
    add_repo repo-a
    git -C "$(repo_dir repo-a)" push --quiet origin "feature/$WS"

    run run_update "$WS" --push

    [ "$status" -eq 0 ]
    [ "$output" = "up-to-date repo-a feature/$WS" ]
}

@test "ws-update: --push does not publish a repo with a merge in progress" {
    add_repo repo-a
    prepare_conflict repo-a
    run_update "$WS" --summary --keep-conflicts || true

    run run_update "$WS" --push

    [ "$status" -eq 2 ]
    [ "$output" = "skipped repo-a merge-in-progress" ]
    ! git -C "$TEST_TEMP_DIR/remotes/repo-a.git" rev-parse -q --verify "feature/$WS"
}

@test "ws-update: --push does not force a branch that has diverged from the remote" {
    add_repo repo-a
    git -C "$(repo_dir repo-a)" push --quiet origin "feature/$WS"
    git -C "$TEST_TEMP_DIR/publishers/repo-a" fetch --quiet origin
    git -C "$TEST_TEMP_DIR/publishers/repo-a" switch --quiet -c "feature/$WS" "origin/feature/$WS"
    echo "ajeno" > "$TEST_TEMP_DIR/publishers/repo-a/ajeno.txt"
    git -C "$TEST_TEMP_DIR/publishers/repo-a" add ajeno.txt
    git -C "$TEST_TEMP_DIR/publishers/repo-a" commit --quiet -m "ajeno"
    git -C "$TEST_TEMP_DIR/publishers/repo-a" push --quiet origin "feature/$WS"
    commit_on_branch repo-a propio.txt "propio"

    run run_update "$WS" --push

    [ "$status" -eq 2 ]
    [ "$output" = "error repo-a diverged" ]
}

@test "ws-update: --push does not publish a branch that is behind the remote" {
    add_repo repo-a
    commit_on_branch repo-a propio.txt "propio"
    git -C "$(repo_dir repo-a)" push --quiet origin "feature/$WS"
    git -C "$(repo_dir repo-a)" reset --quiet --hard HEAD~1

    run run_update "$WS" --push

    [ "$status" -eq 2 ]
    [ "$output" = "error repo-a behind-remote" ]
}

@test "ws-update: --push reports a push rejected by the server" {
    add_repo repo-a
    commit_on_branch repo-a propio.txt "propio"
    printf '#!/bin/sh\nexit 1\n' > "$TEST_TEMP_DIR/remotes/repo-a.git/hooks/pre-receive"
    chmod +x "$TEST_TEMP_DIR/remotes/repo-a.git/hooks/pre-receive"

    run run_update "$WS" --push

    [ "$status" -eq 2 ]
    [[ "$output" == "error repo-a push-failed "?* ]]
}

@test "ws-update: --push does not publish in offline mode" {
    add_repo repo-a
    commit_on_branch repo-a propio.txt "propio"

    WS_OFFLINE=1 run run_update "$WS" --push

    [ "$status" -eq 2 ]
    [ "$output" = "error repo-a offline" ]
}

@test "ws-update: --push leaves nuba-management out" {
    add_repo repo-a
    create_test_repo "nuba-management" >/dev/null
    git -C "$TEST_WORKSPACE_ROOT/nuba-management" worktree add --quiet \
        -b "wt/$WS" "$TEST_WORKSPACES_DIR/$WS/nuba-management"
    git -C "$(repo_dir repo-a)" push --quiet origin "feature/$WS"

    run run_update "$WS" --push

    [ "$status" -eq 0 ]
    [ "$output" = "up-to-date repo-a feature/$WS" ]
}

# =============================================================================
# Ayuda
# =============================================================================

@test "ws-update: help describes the summary contract" {
    run run_update --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"--summary"* ]]
    [[ "$output" == *"--keep-conflicts"* ]]
    [[ "$output" == *"--push"* ]]
    [[ "$output" == *"unpublished <repo> <rama> no-own-commits <base>"* ]]
}
