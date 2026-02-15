#!/usr/bin/env bats
# Tests for ws-git-utils.sh
# Unit tests for git utility functions

load 'test_helper'

setup() {
    setup_test_environment
    source "$WS_TOOLS_ROOT/bin/ws-colors.sh"
    source "$WS_TOOLS_ROOT/bin/ws-git-utils.sh"
}

teardown() {
    teardown_test_environment
}

# =============================================================================
# Helper: create a repo with a "remote" (bare repo) and tracking branch
# =============================================================================

# Creates origin_repo (bare) + local_repo (clone) with tracking
# Usage: create_repo_with_remote
# Sets: ORIGIN_REPO, LOCAL_REPO, DEFAULT_BRANCH
create_repo_with_remote() {
    ORIGIN_REPO="$TEST_TEMP_DIR/origin.git"
    LOCAL_REPO="$TEST_TEMP_DIR/local"

    # Create bare remote with explicit master branch
    git init --quiet --bare --initial-branch=master "$ORIGIN_REPO"

    # Create local repo, add remote, push
    mkdir -p "$LOCAL_REPO"
    cd "$LOCAL_REPO"
    git init --quiet --initial-branch=master
    git config user.email "test@test.com"
    git config user.name "Test User"
    git remote add origin "$ORIGIN_REPO"
    DEFAULT_BRANCH="master"
    echo "initial" > file.txt
    git add file.txt
    git commit --quiet -m "Initial commit"
    git push --quiet -u origin master 2>/dev/null
    cd - > /dev/null
}

# Creates a "gone" upstream scenario: feature branch pushed then remote deleted
# Must call create_repo_with_remote first
# Usage: create_gone_upstream "feature/branch-name"
create_gone_upstream() {
    local branch_name="$1"
    cd "$LOCAL_REPO"
    git checkout --quiet -b "$branch_name"
    echo "feature work" >> file.txt
    git commit --quiet -am "Feature work on $branch_name"
    git push --quiet -u origin "$branch_name" 2>/dev/null
    # Delete the remote branch (makes it "gone")
    git push --quiet origin --delete "$branch_name" 2>/dev/null
    git fetch --quiet --prune 2>/dev/null
    cd - > /dev/null
}

# =============================================================================
# git_has_upstream
# =============================================================================

@test "git_has_upstream: returns 0 when upstream is valid" {
    create_repo_with_remote

    run git_has_upstream "$LOCAL_REPO"

    [ "$status" -eq 0 ]
}

@test "git_has_upstream: returns non-zero when no upstream configured" {
    local repo_path
    repo_path=$(create_test_repo "no-upstream")

    run git_has_upstream "$repo_path"

    [ "$status" -ne 0 ]
}

@test "git_has_upstream: returns non-zero when upstream is gone" {
    create_repo_with_remote
    create_gone_upstream "feature/test-gone"

    # Verify the branch is actually "gone"
    local branch_status
    branch_status=$(cd "$LOCAL_REPO" && git branch -vv | grep "feature/test-gone")
    [[ "$branch_status" == *"gone"* ]]

    # git_has_upstream must return non-zero for gone upstream
    run git_has_upstream "$LOCAL_REPO"

    [ "$status" -ne 0 ]
}

# =============================================================================
# git_get_upstream_branch
# =============================================================================

@test "git_get_upstream_branch: returns branch name when valid" {
    create_repo_with_remote

    run git_get_upstream_branch "$LOCAL_REPO"

    [ "$status" -eq 0 ]
    [ "$output" = "origin/master" ]
}

@test "git_get_upstream_branch: returns empty when no upstream" {
    local repo_path
    repo_path=$(create_test_repo "no-upstream")

    run git_get_upstream_branch "$repo_path"

    [ -z "$output" ]
}

@test "git_get_upstream_branch: returns empty when upstream is gone" {
    create_repo_with_remote
    create_gone_upstream "feature/gone-test"

    run git_get_upstream_branch "$LOCAL_REPO"

    # Must NOT return the literal "@{u}" or "origin/feature/gone-test"
    [ -z "$output" ]
}

# =============================================================================
# git_count_unpushed_commits
# =============================================================================

@test "git_count_unpushed_commits: returns 0 when synced" {
    create_repo_with_remote

    run git_count_unpushed_commits "$LOCAL_REPO"

    [ "$output" = "0" ]
}

@test "git_count_unpushed_commits: counts local commits" {
    create_repo_with_remote

    cd "$LOCAL_REPO"
    echo "change1" >> file.txt && git commit --quiet -am "Commit 1"
    echo "change2" >> file.txt && git commit --quiet -am "Commit 2"
    cd - > /dev/null

    run git_count_unpushed_commits "$LOCAL_REPO"

    [ "$output" = "2" ]
}

@test "git_count_unpushed_commits: counts commits when upstream is gone" {
    create_repo_with_remote

    cd "$LOCAL_REPO"
    git checkout --quiet -b feature/unpushed-gone
    echo "local work" >> file.txt && git commit --quiet -am "Local commit"
    git push --quiet -u origin feature/unpushed-gone 2>/dev/null
    # Add another commit after push
    echo "more work" >> file.txt && git commit --quiet -am "Unpushed commit"
    # Delete the remote branch
    git push --quiet origin --delete feature/unpushed-gone 2>/dev/null
    git fetch --quiet --prune 2>/dev/null
    cd - > /dev/null

    run git_count_unpushed_commits "$LOCAL_REPO"

    # With upstream gone, falls back to base branch comparison
    # Should count commits ahead of master (2: "Local commit" + "Unpushed commit")
    [ "$output" = "2" ]
}

# =============================================================================
# git_count_unpulled_commits
# =============================================================================

@test "git_count_unpulled_commits: returns 0 when synced" {
    create_repo_with_remote

    run git_count_unpulled_commits "$LOCAL_REPO"

    [ "$output" = "0" ]
}

@test "git_count_unpulled_commits: returns 0 when upstream is gone" {
    create_repo_with_remote
    create_gone_upstream "feature/pull-gone"

    run git_count_unpulled_commits "$LOCAL_REPO"

    # With upstream gone, should return 0 (not error out)
    [ "$output" = "0" ]
}

# =============================================================================
# git_repo_status - regression test for gone upstream
# =============================================================================

@test "git_repo_status: gone upstream reports no upstream" {
    create_repo_with_remote
    create_gone_upstream "feature/status-gone"

    run git_repo_status "$LOCAL_REPO"

    # Format: uncommitted:unpushed:unpulled:has_upstream:branch:upstream
    # has_upstream (field 4) must be 0 when upstream is gone
    local has_upstream
    has_upstream=$(echo "$output" | cut -d: -f4)
    [ "$has_upstream" = "0" ]

    # upstream_branch (field 6) must be empty
    local upstream_branch
    upstream_branch=$(echo "$output" | cut -d: -f6)
    [ -z "$upstream_branch" ]
}

@test "git_repo_status: gone upstream still counts unpushed via base branch" {
    create_repo_with_remote
    create_gone_upstream "feature/count-gone"

    run git_repo_status "$LOCAL_REPO"

    # unpushed (field 2) should be > 0 (counted against master)
    local unpushed
    unpushed=$(echo "$output" | cut -d: -f2)
    [ "$unpushed" -gt 0 ]
}

# =============================================================================
# get_sync_status - regression test for gone upstream
# =============================================================================

@test "get_sync_status: gone upstream counts commits as unpushed" {
    create_repo_with_remote
    create_gone_upstream "feature/sync-gone"

    run get_sync_status "$LOCAL_REPO"

    # Format: unpushed:pending_merge:behind
    local unpushed
    unpushed=$(echo "$output" | cut -d: -f1)
    [ "$unpushed" -gt 0 ]

    # pending_merge must be 0 (no valid upstream to compare)
    local pending_merge
    pending_merge=$(echo "$output" | cut -d: -f2)
    [ "$pending_merge" = "0" ]
}

# =============================================================================
# git_has_uncommitted_changes
# =============================================================================

@test "git_has_uncommitted_changes: clean repo returns 1" {
    local repo_path
    repo_path=$(create_test_repo "clean-repo")

    run git_has_uncommitted_changes "$repo_path"

    [ "$status" -eq 1 ]
}

@test "git_has_uncommitted_changes: dirty repo returns 0" {
    local repo_path
    repo_path=$(create_test_repo "dirty-repo")
    echo "change" >> "$repo_path/README.md"

    run git_has_uncommitted_changes "$repo_path"

    [ "$status" -eq 0 ]
}

@test "git_has_uncommitted_changes: nonexistent path returns 1" {
    run git_has_uncommitted_changes "/nonexistent/path"

    [ "$status" -eq 1 ]
}

# =============================================================================
# git_get_base_branch
# =============================================================================

@test "git_get_base_branch: finds master in local repo" {
    local repo_path
    repo_path=$(create_test_repo "base-test")

    run git_get_base_branch "$repo_path"

    [ "$status" -eq 0 ]
    [ "$output" = "master" ]
}

@test "git_get_base_branch: prefers origin/develop over others" {
    create_repo_with_remote

    # Create develop branch on remote
    cd "$LOCAL_REPO"
    git checkout --quiet -b develop
    git push --quiet -u origin develop 2>/dev/null
    git checkout --quiet master
    cd - > /dev/null

    run git_get_base_branch "$LOCAL_REPO"

    [ "$status" -eq 0 ]
    [ "$output" = "origin/develop" ]
}
