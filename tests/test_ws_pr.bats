#!/usr/bin/env bats
# Tests para los pull requests de ws status (ws-pr-utils.sh)
#
# El servidor lo simula un curl falso: las pruebas no tocan la red.

load 'test_helper'

setup() {
    setup_test_environment
    unset WS_BITBUCKET_URL WS_BITBUCKET_TOKEN WS_BITBUCKET_HOSTS WS_BITBUCKET_TIMEOUT WS_OFFLINE
    source "$WS_TOOLS_ROOT/bin/ws-colors.sh"
    source "$WS_TOOLS_ROOT/bin/ws-pr-utils.sh"
    FAKEBIN="$TEST_TEMP_DIR/fakebin"
    export FAKE_CURL_LOG="$TEST_TEMP_DIR/curl.log"
    export FAKE_CURL_BODY="$TEST_TEMP_DIR/body.json"
    export FAKE_CURL_STDIN="$TEST_TEMP_DIR/curl.stdin"
    export FAKE_CURL_CODE=200
    export FAKE_CURL_RC=0
    echo '{"size":0,"values":[]}' > "$FAKE_CURL_BODY"
    create_fake_curl
}

teardown() {
    teardown_test_environment
}

# curl falso: registra los argumentos y en FAKE_CURL_STDIN la entrada estándar,
# copia FAKE_CURL_BODY al fichero de -o, imprime FAKE_CURL_CODE y sale con FAKE_CURL_RC
create_fake_curl() {
    mkdir -p "$FAKEBIN"
    cat > "$FAKEBIN/curl" << 'FAKE'
#!/bin/bash
echo "$*" >> "$FAKE_CURL_LOG"
cat >> "$FAKE_CURL_STDIN"
[ "$FAKE_CURL_RC" -ne 0 ] && exit "$FAKE_CURL_RC"
out=""
while [ $# -gt 0 ]; do
    [ "$1" = "-o" ] && out="$2"
    shift
done
cp "$FAKE_CURL_BODY" "$out"
printf '%s' "$FAKE_CURL_CODE"
FAKE
    chmod +x "$FAKEBIN/curl"
    export PATH="$FAKEBIN:$PATH"
}

configure_server() {
    export WS_BITBUCKET_URL="http://bb.test:7990"
    export WS_BITBUCKET_TOKEN="secreto"
}

# Respuesta con dos pull requests de la rama: uno abierto y uno integrado
given_two_pull_requests() {
    cat > "$FAKE_CURL_BODY" << 'JSON'
{"size":2,"values":[
 {"id":12,"state":"OPEN","fromRef":{"displayId":"feature/ws-pr"},"toRef":{"displayId":"develop"},
  "links":{"self":[{"href":"http://bb.test:7990/projects/NUBA/repos/repo-a/pull-requests/12"}]}},
 {"id":7,"state":"MERGED","fromRef":{"displayId":"feature/ws-pr"},"toRef":{"displayId":"master"},
  "links":{"self":[{"href":"http://bb.test:7990/projects/NUBA/repos/repo-a/pull-requests/7"}]}}
]}
JSON
}

# Workspace ws-pr con repo-a en la rama feature/ws-pr y remoto del servidor
given_workspace_on_server() {
    create_test_repo "repo-a" > /dev/null
    git -C "$TEST_WORKSPACE_ROOT/repo-a" worktree add --quiet \
        "$TEST_WORKSPACES_DIR/ws-pr/repo-a" -b feature/ws-pr
    git -C "$TEST_WORKSPACE_ROOT/repo-a" remote add origin "ssh://git@bb.test:7999/nuba/repo-a.git"
}

# =============================================================================
# pr_repo_coordinates
# =============================================================================

@test "pr_repo_coordinates: ssh URL with port gives upper-case project and repo" {
    configure_server
    run pr_repo_coordinates "ssh://git@bb.test:7999/nuba/ks-nuba.git"
    [ "$status" -eq 0 ]
    [ "$output" = $'NUBA\tks-nuba' ]
}

@test "pr_repo_coordinates: scp-like and http /scm/ URLs are recognised" {
    configure_server
    run pr_repo_coordinates "git@bb.test:nuba/dga-commons.git"
    [ "$output" = $'NUBA\tdga-commons' ]
    run pr_repo_coordinates "https://user@bb.test/scm/nuba/dph-nuba.git"
    [ "$output" = $'NUBA\tdph-nuba' ]
}

@test "pr_repo_coordinates: personal project keeps its case" {
    configure_server
    run pr_repo_coordinates "ssh://git@bb.test:7999/~jdoe/notes.git"
    [ "$output" = $'~jdoe\tnotes' ]
}

@test "pr_repo_coordinates: remote from another host is not the server's" {
    configure_server
    run pr_repo_coordinates "git@github.com:nubarchiva/workspace-tools.git"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "pr_repo_coordinates: WS_BITBUCKET_HOSTS accepts host aliases" {
    configure_server
    export WS_BITBUCKET_HOSTS="bb.test stash"
    run pr_repo_coordinates "ssh://git@stash:7999/nuba/ks-nuba.git"
    [ "$status" -eq 0 ]
    [ "$output" = $'NUBA\tks-nuba' ]
}

# =============================================================================
# pr_list_branch
# =============================================================================

@test "pr_list_branch: queries outgoing pull requests of the branch in any state" {
    configure_server
    given_two_pull_requests
    run pr_list_branch NUBA repo-a feature/ws-pr
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = $'12\tOPEN\tdevelop\thttp://bb.test:7990/projects/NUBA/repos/repo-a/pull-requests/12' ]
    [ "${lines[1]}" = $'7\tMERGED\tmaster\thttp://bb.test:7990/projects/NUBA/repos/repo-a/pull-requests/7' ]

    local call
    call=$(cat "$FAKE_CURL_LOG")
    [[ "$call" == *"http://bb.test:7990/rest/api/latest/projects/NUBA/repos/repo-a/pull-requests"* ]]
    [[ "$call" == *"at=refs/heads/feature/ws-pr"* ]]
    [[ "$call" == *"direction=OUTGOING"* ]]
    [[ "$call" == *"state=ALL"* ]]
    [[ "$call" == *"-K -"* ]]
    [[ "$call" != *"secreto"* ]]
    [ "$(cat "$FAKE_CURL_STDIN")" = 'header = "Authorization: Bearer secreto"' ]
}

@test "pr_list_branch: no pull requests prints nothing and succeeds" {
    configure_server
    run pr_list_branch NUBA repo-a feature/ws-pr
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "pr_list_branch: follows the redirect of a renamed repository" {
    # Con curl real contra un servidor efímero en 127.0.0.1: un repositorio
    # renombrado responde con una redirección al slug nuevo
    local port=$((20000 + RANDOM % 10000))
    export WS_BITBUCKET_URL="http://127.0.0.1:$port"
    export WS_BITBUCKET_TOKEN="secreto"
    PATH="${PATH#"$FAKEBIN":}"

    python3 - "$port" "$TEST_TEMP_DIR" << 'PY' &
import socket, sys
port, tmp = int(sys.argv[1]), sys.argv[2]
body = b'{"size":1,"values":[{"id":9,"state":"OPEN","toRef":{"displayId":"develop"},"links":{"self":[{"href":"http://x/9"}]}}]}'
srv = socket.socket(); srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("127.0.0.1", port)); srv.listen(2); srv.settimeout(10)
for i in range(2):
    conn, _ = srv.accept(); conn.settimeout(5)
    request = conn.recv(8192)
    open("%s/request-%d.txt" % (tmp, i), "wb").write(request)
    target = request.split(b" ")[1].decode().replace("/repos/viejo/", "/repos/nuevo/")
    if i == 0:
        conn.sendall(b"HTTP/1.1 307 Temporary Redirect\r\nLocation: " + target.encode() + b"\r\nContent-Length: 0\r\n\r\n")
    else:
        conn.sendall(b"HTTP/1.1 200 OK\r\nContent-Length: %d\r\n\r\n" % len(body) + body)
    conn.close()
PY
    sleep 1

    run pr_list_branch NUBA viejo feature/ws-pr
    wait
    [ "$status" -eq 0 ]
    [ "$output" = $'9\tOPEN\tdevelop\thttp://x/9' ]
    grep -q "/repos/nuevo/pull-requests" "$TEST_TEMP_DIR/request-1.txt"
    grep -q "Authorization: Bearer secreto" "$TEST_TEMP_DIR/request-1.txt"
}

@test "pr_list_branch: rejected token reports the cause" {
    configure_server
    export FAKE_CURL_CODE=401
    run pr_list_branch NUBA repo-a feature/ws-pr
    [ "$status" -eq 1 ]
    [ "$output" = "token rechazado (HTTP 401)" ]
}

@test "pr_list_branch: unknown repository reports the cause" {
    configure_server
    export FAKE_CURL_CODE=404
    run pr_list_branch NUBA repo-a feature/ws-pr
    [ "$status" -eq 1 ]
    [ "$output" = "repositorio no encontrado en el servidor (HTTP 404)" ]
}

@test "pr_list_branch: connection failure reports the cause" {
    configure_server
    export FAKE_CURL_RC=7
    run pr_list_branch NUBA repo-a feature/ws-pr
    [ "$status" -eq 1 ]
    [ "$output" = "no se puede conectar con el servidor" ]
}

# =============================================================================
# pr_print_repo
# =============================================================================

@test "pr_print_repo: server failure is not retried for the following repos" {
    configure_server
    given_workspace_on_server
    export FAKE_CURL_RC=28
    output=$(pr_print_repo "$TEST_WORKSPACES_DIR/ws-pr/repo-a" feature/ws-pr; \
             pr_print_repo "$TEST_WORKSPACES_DIR/ws-pr/repo-a" feature/ws-pr)
    [ "$(grep -c "Pull requests sin comprobar: sin respuesta en 5 s" <<< "$output")" -eq 2 ]
    [ "$(wc -l < "$FAKE_CURL_LOG" | tr -d ' ')" -eq 1 ]
}

@test "pr_print_repo: several pull requests on the branch print only the most recent" {
    configure_server
    given_workspace_on_server
    given_two_pull_requests
    run pr_print_repo "$TEST_WORKSPACES_DIR/ws-pr/repo-a" feature/ws-pr
    [ "${#lines[@]}" -eq 1 ]
    [[ "$output" == *"PR #12"* ]]
}

@test "pr_print_repo: repo whose remote is not the server's prints nothing" {
    configure_server
    given_workspace_on_server
    git -C "$TEST_WORKSPACE_ROOT/repo-a" remote set-url origin "git@github.com:acme/repo-a.git"
    run pr_print_repo "$TEST_WORKSPACES_DIR/ws-pr/repo-a" feature/ws-pr
    [ -z "$output" ]
    [ ! -f "$FAKE_CURL_LOG" ]
}

# =============================================================================
# ws status
# =============================================================================

@test "ws status: shows the most recent pull request of the workspace branch" {
    configure_server
    given_workspace_on_server
    given_two_pull_requests
    run run_ws status ws-pr
    [ "$status" -eq 0 ]
    [[ "$output" == *"PR #12 OPEN → develop http://bb.test:7990/projects/NUBA/repos/repo-a/pull-requests/12"* ]]
    [[ "$output" != *"PR #7"* ]]
}

@test "ws status: says so when the branch has no pull requests" {
    configure_server
    given_workspace_on_server
    run run_ws status ws-pr
    [ "$status" -eq 0 ]
    [[ "$output" == *"Sin pull requests"* ]]
}

@test "ws status: without a declared server nothing is queried" {
    given_workspace_on_server
    run run_ws status ws-pr
    [ "$status" -eq 0 ]
    [[ "$output" != *"ull request"* ]]
    [ ! -f "$FAKE_CURL_LOG" ]
}

@test "ws status: offline mode does not query the server" {
    configure_server
    given_workspace_on_server
    export WS_OFFLINE=1
    run run_ws status ws-pr
    [ "$status" -eq 0 ]
    [[ "$output" != *"ull request"* ]]
    [ ! -f "$FAKE_CURL_LOG" ]
}

@test "ws status: repo on a branch other than the workspace's is not queried" {
    configure_server
    given_workspace_on_server
    git -C "$TEST_WORKSPACES_DIR/ws-pr/repo-a" checkout --quiet -b otra-rama
    run run_ws status ws-pr
    [ "$status" -eq 0 ]
    [[ "$output" != *"ull request"* ]]
    [ ! -f "$FAKE_CURL_LOG" ]
}

@test "ws switch: does not show pull requests" {
    configure_server
    given_workspace_on_server
    given_two_pull_requests
    run run_ws switch ws-pr
    [ "$status" -eq 0 ]
    [[ "$output" != *"PR #12"* ]]
    [ ! -f "$FAKE_CURL_LOG" ]
}
