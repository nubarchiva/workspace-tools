#!/usr/bin/env bats
# Tests para el acceso a nuba-management (ws-common.sh): árbol propio (worktree)
# frente a árbol compartido (symlink)

load 'test_helper'

setup() {
    setup_test_environment
    load_ws_common
}

teardown() {
    stop_foreign_workers
    teardown_test_environment
}

# Arranca un proceso AJENO —reparentado a init, no descendiente de este test— con
# su directorio de trabajo dentro de una ruta. Tiene que ser ajeno: un hijo del
# test lo excluye el propio guardarraíl, que ignora su árbol de procesos.
# Uso: start_foreign_worker <dir>
# Retorna: el PID por stdout
start_foreign_worker() {
    local dir="$1"
    local pidfile="$TEST_TEMP_DIR/foreign.$$.$RANDOM.pid"

    # Doble fork para que el nieto quede colgando de init, y nohup para que la
    # muerte del intermedio no se lo lleve por delante
    ( ( cd "$dir" && exec nohup sh -c 'echo $$ > "$0"; exec sleep 30' "$pidfile" >/dev/null 2>&1 ) & ) &

    local waited=0
    while [ ! -s "$pidfile" ] && [ $waited -lt 50 ]; do
        sleep 0.1
        waited=$((waited + 1))
    done

    cat "$pidfile" 2>/dev/null
}

# Comprueba que el proceso de prueba es realmente ajeno al test: si fuese un
# descendiente, el guardarraíl lo ignoraría y la medición no probaría nada
assert_foreign() {
    local pid="$1"
    local ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    if [ "$ppid" != "1" ]; then
        echo "El proceso de prueba $pid no está reparentado (PPID=$ppid): la medición no vale"
        return 1
    fi
}

stop_foreign_workers() {
    local pidfile pid
    for pidfile in "$TEST_TEMP_DIR"/foreign.*.pid; do
        [ -f "$pidfile" ] || continue
        pid=$(cat "$pidfile" 2>/dev/null)
        [ -n "$pid" ] && kill "$pid" 2>/dev/null
    done
}

# Crea un clon de nuba-management con origin/main, como el del workspace real
# Uso: create_management_clone
create_management_clone() {
    local origin="$TEST_TEMP_DIR/nuba-management-origin.git"
    local clone="$TEST_WORKSPACE_ROOT/nuba-management"

    git init --quiet --bare --initial-branch=main "$origin"
    git clone --quiet "$origin" "$clone"
    git -C "$clone" config user.email "test@test.com"
    git -C "$clone" config user.name "Test User"
    echo "# nuba-management" > "$clone/README.md"
    git -C "$clone" add README.md
    git -C "$clone" commit --quiet -m "Initial commit"
    git -C "$clone" push --quiet origin main
}

# Crea un clon sin origin/main (el caso del clon recién iniciado en local)
create_management_clone_without_origin() {
    local clone="$TEST_WORKSPACE_ROOT/nuba-management"

    mkdir -p "$clone"
    git init --quiet --initial-branch=main "$clone"
    git -C "$clone" config user.email "test@test.com"
    git -C "$clone" config user.name "Test User"
    echo "# nuba-management" > "$clone/README.md"
    git -C "$clone" add README.md
    git -C "$clone" commit --quiet -m "Initial commit"
}

# Crea el directorio de un workspace de prueba
# Uso: create_workspace_dir <nombre>
create_workspace_dir() {
    mkdir -p "$TEST_WORKSPACES_DIR/$1"
    echo "$TEST_WORKSPACES_DIR/$1"
}

# =============================================================================
# management_branch() y management_regime()
# =============================================================================

@test "management_branch: la rama del worktree lleva el nombre del workspace" {
    run management_branch "nuba-8926"
    [ "$status" -eq 0 ]
    [ "$output" = "wt/nuba-8926" ]
}

@test "management_regime: sin acceso a nuba-management" {
    local ws_dir=$(create_workspace_dir "sin-gestion")
    run management_regime "$ws_dir"
    [ "$output" = "ninguno" ]
}

@test "management_regime: symlink es régimen compartido" {
    create_management_clone
    local ws_dir=$(create_workspace_dir "compartido")
    ln -s "$TEST_WORKSPACE_ROOT/nuba-management" "$ws_dir/nuba-management"

    run management_regime "$ws_dir"
    [ "$output" = "compartido" ]
}

@test "management_regime: worktree es régimen propio" {
    create_management_clone
    local ws_dir=$(create_workspace_dir "propio")
    setup_management_access "$ws_dir" "$TEST_WORKSPACE_ROOT"

    run management_regime "$ws_dir"
    [ "$output" = "propio" ]
}

# =============================================================================
# setup_management_access() - montaje de un workspace nuevo
# =============================================================================

@test "setup_management_access: crea un worktree en la rama wt/<workspace>" {
    create_management_clone
    local ws_dir=$(create_workspace_dir "nueva-feature")

    run setup_management_access "$ws_dir" "$TEST_WORKSPACE_ROOT"
    [ "$status" -eq 0 ]
    assert_contains "$output" "worktree"

    [ ! -L "$ws_dir/nuba-management" ]
    assert_dir_exists "$ws_dir/nuba-management"
    assert_file_exists "$ws_dir/nuba-management/README.md"
    assert_equals "wt/nueva-feature" "$(get_current_branch "$ws_dir/nuba-management")"
}

@test "setup_management_access: el worktree tiene índice propio" {
    create_management_clone
    local ws_a=$(create_workspace_dir "ws-a")
    local ws_b=$(create_workspace_dir "ws-b")
    setup_management_access "$ws_a" "$TEST_WORKSPACE_ROOT"
    setup_management_access "$ws_b" "$TEST_WORKSPACE_ROOT"

    echo "de a" > "$ws_a/nuba-management/solo-de-a.md"
    git -C "$ws_a/nuba-management" add solo-de-a.md

    # El fichero que a ha preparado no aparece en el árbol de b
    run git -C "$ws_b/nuba-management" status --porcelain
    [ -z "$output" ]
}

@test "setup_management_access: sin origin/main cae al symlink, diciendo por qué" {
    create_management_clone_without_origin
    local ws_dir=$(create_workspace_dir "sin-origin")

    run setup_management_access "$ws_dir" "$TEST_WORKSPACE_ROOT"
    [ "$status" -eq 0 ]
    assert_contains "$output" "compartido"
    assert_contains "$output" "origin/main"

    [ -L "$ws_dir/nuba-management" ]
}

@test "setup_management_access: sin clon principal no hace nada" {
    local ws_dir=$(create_workspace_dir "sin-clon")

    run setup_management_access "$ws_dir" "$TEST_WORKSPACE_ROOT"
    [ "$status" -eq 0 ]
    [ ! -e "$ws_dir/nuba-management" ]
}

@test "setup_management_access: no toca un acceso ya montado" {
    create_management_clone
    local ws_dir=$(create_workspace_dir "ya-montado")
    ln -s "$TEST_WORKSPACE_ROOT/nuba-management" "$ws_dir/nuba-management"

    run setup_management_access "$ws_dir" "$TEST_WORKSPACE_ROOT"
    [ "$status" -eq 0 ]

    # Sigue siendo el symlink: no se ha anidado nada dentro
    [ -L "$ws_dir/nuba-management" ]
    [ ! -e "$ws_dir/nuba-management/nuba-management" ]
}

@test "setup_management_access: reutiliza la rama wt/<workspace> si ya existe" {
    create_management_clone
    local ws_dir=$(create_workspace_dir "con-rama")
    git -C "$TEST_WORKSPACE_ROOT/nuba-management" branch "wt/con-rama" main

    run setup_management_access "$ws_dir" "$TEST_WORKSPACE_ROOT"
    [ "$status" -eq 0 ]
    assert_equals "wt/con-rama" "$(get_current_branch "$ws_dir/nuba-management")"
}

# =============================================================================
# management_switch_to_worktree() - migración perezosa
# =============================================================================

@test "management_switch_to_worktree: convierte el symlink en worktree, en la misma ruta" {
    create_management_clone
    local ws_dir=$(create_workspace_dir "a-migrar")
    ln -s "$TEST_WORKSPACE_ROOT/nuba-management" "$ws_dir/nuba-management"

    run management_switch_to_worktree "$ws_dir" "$TEST_WORKSPACE_ROOT"
    [ "$status" -eq 0 ]

    [ ! -L "$ws_dir/nuba-management" ]
    assert_dir_exists "$ws_dir/nuba-management"
    assert_equals "wt/a-migrar" "$(get_current_branch "$ws_dir/nuba-management")"
    # La ruta relativa de siempre sigue resolviendo
    assert_file_exists "$ws_dir/nuba-management/README.md"
}

@test "management_switch_to_worktree: no toca un workspace con procesos vivos" {
    create_management_clone
    local ws_dir=$(create_workspace_dir "ocupado")
    ln -s "$TEST_WORKSPACE_ROOT/nuba-management" "$ws_dir/nuba-management"

    local intruso=$(start_foreign_worker "$ws_dir")
    assert_foreign "$intruso"

    run management_switch_to_worktree "$ws_dir" "$TEST_WORKSPACE_ROOT"

    [ "$status" -eq 2 ]
    [ -L "$ws_dir/nuba-management" ]
}

@test "management_switch_to_worktree: no hace nada si ya es árbol propio" {
    create_management_clone
    local ws_dir=$(create_workspace_dir "ya-propio")
    setup_management_access "$ws_dir" "$TEST_WORKSPACE_ROOT"

    run management_switch_to_worktree "$ws_dir" "$TEST_WORKSPACE_ROOT"
    [ "$status" -eq 1 ]
    assert_equals "propio" "$(management_regime "$ws_dir")"
}

@test "management_switch_to_worktree: sin origin/main deja el symlink como estaba" {
    create_management_clone_without_origin
    local ws_dir=$(create_workspace_dir "sin-origin")
    ln -s "$TEST_WORKSPACE_ROOT/nuba-management" "$ws_dir/nuba-management"

    run management_switch_to_worktree "$ws_dir" "$TEST_WORKSPACE_ROOT"
    [ "$status" -eq 1 ]
    [ -L "$ws_dir/nuba-management" ]
}

# =============================================================================
# management_switch_to_shared() - vuelta atrás
# =============================================================================

@test "management_switch_to_shared: restituye el symlink y libera la ruta del worktree" {
    create_management_clone
    local ws_dir=$(create_workspace_dir "vuelta")
    setup_management_access "$ws_dir" "$TEST_WORKSPACE_ROOT"

    run management_switch_to_shared "$ws_dir" "$TEST_WORKSPACE_ROOT"
    [ "$status" -eq 0 ]

    [ -L "$ws_dir/nuba-management" ]
    assert_file_exists "$ws_dir/nuba-management/README.md"

    # git ya no registra el worktree, así que la ruta vuelve a estar disponible
    run git -C "$TEST_WORKSPACE_ROOT/nuba-management" worktree list
    [[ "$output" != *"$ws_dir"* ]]
}

@test "management_switch_to_shared: tras la vuelta atrás se puede volver a migrar" {
    create_management_clone
    local ws_dir=$(create_workspace_dir "ida-y-vuelta")
    setup_management_access "$ws_dir" "$TEST_WORKSPACE_ROOT"
    management_switch_to_shared "$ws_dir" "$TEST_WORKSPACE_ROOT"

    run management_switch_to_worktree "$ws_dir" "$TEST_WORKSPACE_ROOT"
    [ "$status" -eq 0 ]
    assert_equals "wt/ida-y-vuelta" "$(get_current_branch "$ws_dir/nuba-management")"
}

@test "management_switch_to_shared: la rama conserva los commits del worktree" {
    create_management_clone
    local ws_dir=$(create_workspace_dir "con-commits")
    setup_management_access "$ws_dir" "$TEST_WORKSPACE_ROOT"

    echo "trabajo" > "$ws_dir/nuba-management/trabajo.md"
    git -C "$ws_dir/nuba-management" add trabajo.md
    git -C "$ws_dir/nuba-management" commit --quiet -m "Añadir trabajo"

    management_switch_to_shared "$ws_dir" "$TEST_WORKSPACE_ROOT"

    run git -C "$TEST_WORKSPACE_ROOT/nuba-management" log --oneline "wt/con-commits"
    assert_contains "$output" "Añadir trabajo"
}

# =============================================================================
# workspace_live_pids() - el guardarraíl de sesiones vivas
# =============================================================================

@test "workspace_live_pids: no se cuenta a sí mismo ni a su árbol de procesos" {
    local ws_dir=$(create_workspace_dir "vacio")

    cd "$ws_dir"
    run workspace_live_pids "$ws_dir"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "workspace_live_pids: encuentra un proceso ajeno trabajando dentro" {
    local ws_dir=$(create_workspace_dir "con-inquilino")

    local intruso=$(start_foreign_worker "$ws_dir")
    assert_foreign "$intruso"

    run workspace_live_pids "$ws_dir"

    [ "$status" -eq 0 ]
    assert_contains "$output" "$intruso"
}

@test "workspace_live_pids: cuenta también los que trabajan en un subdirectorio" {
    local ws_dir=$(create_workspace_dir "con-repo")
    mkdir -p "$ws_dir/ks-nuba/src"

    local intruso=$(start_foreign_worker "$ws_dir/ks-nuba/src")
    assert_foreign "$intruso"

    run workspace_live_pids "$ws_dir"

    assert_contains "$output" "$intruso"
}

@test "workspace_live_pids: no confunde un workspace con otro de nombre parecido" {
    local ws_dir=$(create_workspace_dir "feature")
    local vecino=$(create_workspace_dir "feature-2")

    local intruso=$(start_foreign_worker "$vecino")
    assert_foreign "$intruso"

    run workspace_live_pids "$ws_dir"

    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
