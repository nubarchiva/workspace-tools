#!/usr/bin/env bats
# Tests para ws origins clone - Clonado inicial de repos origen
#
# Los remotos son repositorios locales (file://): las pruebas no tocan la red.

load 'test_helper'

setup() {
    setup_test_environment
    REMOTES="$TEST_TEMP_DIR/remotes"
    mkdir -p "$REMOTES"
    MANIFEST="$TEST_TEMP_DIR/manifest"
}

teardown() {
    teardown_test_environment
}

# Crea un repositorio remoto (bare) con un commit
# Uso: create_remote <nombre>
create_remote() {
    local name="$1"
    git init --quiet --bare --initial-branch=master "$REMOTES/$name.git"
    local work="$TEST_TEMP_DIR/w-$name"
    git init --quiet --initial-branch=master "$work"
    git -C "$work" config user.email "test@test.com"
    git -C "$work" config user.name "Test User"
    echo "# $name" > "$work/README.md"
    git -C "$work" add README.md
    git -C "$work" commit --quiet -m "Initial commit"
    git -C "$work" remote add origin "$REMOTES/$name.git"
    git -C "$work" push --quiet origin master
}

run_clone() {
    env WS_CONFIG_FILE=/dev/null \
        WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT" \
        WORKSPACES_DIR="$TEST_WORKSPACES_DIR" \
        WS_TOOLS="$WS_TOOLS_ROOT" \
        "$WS_TOOLS_ROOT/bin/ws-origins" clone "$@"
}

# =============================================================================
# Ayuda y validación de argumentos
# =============================================================================

@test "ws origins clone: --help muestra el uso" {
    run run_clone --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"ws origins clone"* ]]
}

@test "ws origins clone: opción desconocida falla" {
    run run_clone --que-es-esto
    [ "$status" -eq 1 ]
    [[ "$output" == *"desconocida"* ]]
}

@test "ws origins clone: sin manifiesto explica cómo indicarlo" {
    run run_clone
    [ "$status" -eq 1 ]
    [[ "$output" == *"manifiesto"* ]]
    [[ "$output" == *"--seed"* ]]
}

# =============================================================================
# Clonado
# =============================================================================

@test "ws origins clone: clona los repos del manifiesto" {
    create_remote app
    cat > "$MANIFEST" <<EOF
app  file://$REMOTES/app.git  core  -  -
EOF
    run run_clone --manifest "$MANIFEST"
    [ "$status" -eq 0 ]
    [ -d "$TEST_WORKSPACE_ROOT/app/.git" ]
}

@test "ws origins clone: crea los destinos anidados" {
    create_remote marc4j
    cat > "$MANIFEST" <<EOF
libs/marc4j  file://$REMOTES/marc4j.git  core,libs  -  -
EOF
    run run_clone --manifest "$MANIFEST"
    [ "$status" -eq 0 ]
    [ -d "$TEST_WORKSPACE_ROOT/libs/marc4j/.git" ]
}

@test "ws origins clone: es idempotente, la segunda pasada salta" {
    create_remote app
    cat > "$MANIFEST" <<EOF
app  file://$REMOTES/app.git  core  -  -
EOF
    run_clone --manifest "$MANIFEST"
    run run_clone --manifest "$MANIFEST"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ya clonado"* ]]
}

@test "ws origins clone: un fallo no impide clonar los demás" {
    create_remote app
    cat > "$MANIFEST" <<EOF
roto  file://$REMOTES/no-existe.git  core  -  -
app   file://$REMOTES/app.git        core  -  -
EOF
    run run_clone --manifest "$MANIFEST"
    [ "$status" -eq 1 ]
    [ -d "$TEST_WORKSPACE_ROOT/app/.git" ]
    [[ "$output" == *"Fallidos"* ]]
}

@test "ws origins clone: informa del destino ocupado sin sobrescribirlo" {
    create_remote app
    mkdir -p "$TEST_WORKSPACE_ROOT/app"
    echo "contenido previo" > "$TEST_WORKSPACE_ROOT/app/fichero.txt"
    cat > "$MANIFEST" <<EOF
app  file://$REMOTES/app.git  core  -  -
EOF
    run run_clone --manifest "$MANIFEST"
    [ "$status" -eq 1 ]
    [[ "$output" == *"no está vacío"* ]]
    [ -f "$TEST_WORKSPACE_ROOT/app/fichero.txt" ]
}

@test "ws origins clone: avisa si el origin difiere del manifiesto" {
    create_remote app
    create_remote otro
    cat > "$MANIFEST" <<EOF
app  file://$REMOTES/app.git  core  -  -
EOF
    run_clone --manifest "$MANIFEST"
    git -C "$TEST_WORKSPACE_ROOT/app" remote set-url origin "file://$REMOTES/otro.git"
    run run_clone --manifest "$MANIFEST"
    [ "$status" -eq 0 ]
    [[ "$output" == *"origin distinto"* ]]
}

# =============================================================================
# Grupos
# =============================================================================

@test "ws origins clone: --group clona solo ese subconjunto" {
    create_remote app
    create_remote web
    cat > "$MANIFEST" <<EOF
app     file://$REMOTES/app.git  core  -  -
sitio   file://$REMOTES/web.git  web   -  -
EOF
    run run_clone --manifest "$MANIFEST" --group core
    [ "$status" -eq 0 ]
    [ -d "$TEST_WORKSPACE_ROOT/app/.git" ]
    [ ! -d "$TEST_WORKSPACE_ROOT/sitio" ]
}

@test "ws origins clone: --group acumulable" {
    create_remote app
    create_remote web
    cat > "$MANIFEST" <<EOF
app     file://$REMOTES/app.git  core  -  -
sitio   file://$REMOTES/web.git  web   -  -
EOF
    run run_clone --manifest "$MANIFEST" --group core --group web
    [ "$status" -eq 0 ]
    [ -d "$TEST_WORKSPACE_ROOT/app/.git" ]
    [ -d "$TEST_WORKSPACE_ROOT/sitio/.git" ]
}

@test "ws origins clone: avisa de un grupo que no existe" {
    create_remote app
    cat > "$MANIFEST" <<EOF
app  file://$REMOTES/app.git  core  -  -
EOF
    run run_clone --manifest "$MANIFEST" --group nucleo
    [[ "$output" == *"no aparece en el manifiesto"* ]]
}

@test "ws origins clone: --list-groups enumera los grupos" {
    create_remote app
    cat > "$MANIFEST" <<EOF
app  file://$REMOTES/app.git  core,apps  -  -
EOF
    run run_clone --manifest "$MANIFEST" --list-groups
    [ "$status" -eq 0 ]
    [[ "$output" == *"core"* ]]
    [[ "$output" == *"apps"* ]]
}

# =============================================================================
# Flag 'manual'
# =============================================================================

@test "ws origins clone: omite lo marcado 'manual' e informa del motivo" {
    create_remote legacy
    cat > "$MANIFEST" <<EOF
legacy  file://$REMOTES/legacy.git  external  manual  requiere certificado de cliente
EOF
    run run_clone --manifest "$MANIFEST"
    [ "$status" -eq 0 ]
    [ ! -d "$TEST_WORKSPACE_ROOT/legacy" ]
    [[ "$output" == *"requiere certificado de cliente"* ]]
}

@test "ws origins clone: --include-manual lo clona" {
    create_remote legacy
    cat > "$MANIFEST" <<EOF
legacy  file://$REMOTES/legacy.git  external  manual  requiere certificado de cliente
EOF
    run run_clone --manifest "$MANIFEST" --include-manual
    [ "$status" -eq 0 ]
    [ -d "$TEST_WORKSPACE_ROOT/legacy/.git" ]
}

# =============================================================================
# --dry-run
# =============================================================================

@test "ws origins clone: --dry-run no clona nada" {
    create_remote app
    cat > "$MANIFEST" <<EOF
app  file://$REMOTES/app.git  core  -  -
EOF
    run run_clone --manifest "$MANIFEST" --dry-run
    [ "$status" -eq 0 ]
    [ ! -d "$TEST_WORKSPACE_ROOT/app" ]
    [[ "$output" == *"clonaría"* ]]
}

# =============================================================================
# Composición de manifiestos
# =============================================================================

@test "ws origins clone: compone varios manifiestos y el último gana" {
    create_remote publico
    create_remote privado
    cat > "$MANIFEST" <<EOF
app  file://$REMOTES/publico.git  core  -  -
EOF
    cat > "$TEST_TEMP_DIR/manifest-privado" <<EOF
app  file://$REMOTES/privado.git  core  -  -
EOF
    run run_clone --manifest "$MANIFEST" --manifest "$TEST_TEMP_DIR/manifest-privado"
    [ "$status" -eq 0 ]
    run git -C "$TEST_WORKSPACE_ROOT/app" remote get-url origin
    [[ "$output" == *"privado.git"* ]]
}

# =============================================================================
# --seed
# =============================================================================

@test "ws origins clone: --seed clona el repositorio del manifiesto y lo usa" {
    create_remote app
    # Repositorio que lleva el manifiesto dentro
    git init --quiet --bare --initial-branch=master "$REMOTES/mgmt.git"
    local work="$TEST_TEMP_DIR/w-mgmt"
    git init --quiet --initial-branch=master "$work"
    git -C "$work" config user.email "test@test.com"
    git -C "$work" config user.name "Test User"
    cat > "$work/.ws-manifest" <<EOF
app  file://$REMOTES/app.git  core  -  -
EOF
    git -C "$work" add .ws-manifest
    git -C "$work" commit --quiet -m "Manifiesto"
    git -C "$work" remote add origin "$REMOTES/mgmt.git"
    git -C "$work" push --quiet origin master

    run run_clone --seed "file://$REMOTES/mgmt.git"
    [ "$status" -eq 0 ]
    [ -f "$TEST_WORKSPACE_ROOT/mgmt/.ws-manifest" ]
    [ -d "$TEST_WORKSPACE_ROOT/app/.git" ]
}

@test "ws origins clone: --seed con --manifest relativo lo busca dentro del clon sembrado" {
    create_remote app
    create_remote web
    git init --quiet --bare --initial-branch=master "$REMOTES/mgmt.git"
    local work="$TEST_TEMP_DIR/w-mgmt"
    git init --quiet --initial-branch=master "$work"
    git -C "$work" config user.email "test@test.com"
    git -C "$work" config user.name "Test User"
    mkdir -p "$work/manifests"
    cat > "$work/manifests/proyecto.conf" <<EOF
app    file://$REMOTES/app.git  core  -  -
sitio  file://$REMOTES/web.git  web   -  -
EOF
    git -C "$work" add -A
    git -C "$work" commit --quiet -m "Manifiesto"
    git -C "$work" remote add origin "$REMOTES/mgmt.git"
    git -C "$work" push --quiet origin master

    run run_clone --seed "file://$REMOTES/mgmt.git" --manifest manifests/proyecto.conf --group core
    [ "$status" -eq 0 ]
    [ -d "$TEST_WORKSPACE_ROOT/app/.git" ]
    [ ! -d "$TEST_WORKSPACE_ROOT/sitio" ]
}

@test "ws origins clone: --seed sin manifiesto dentro dice dónde ha buscado" {
    git init --quiet --bare --initial-branch=master "$REMOTES/vacio.git"
    local work="$TEST_TEMP_DIR/w-vacio"
    git init --quiet --initial-branch=master "$work"
    git -C "$work" config user.email "test@test.com"
    git -C "$work" config user.name "Test User"
    echo "sin manifiesto" > "$work/README.md"
    git -C "$work" add README.md
    git -C "$work" commit --quiet -m "Sin manifiesto"
    git -C "$work" remote add origin "$REMOTES/vacio.git"
    git -C "$work" push --quiet origin master

    run run_clone --seed "file://$REMOTES/vacio.git"
    [ "$status" -eq 1 ]
    [[ "$output" == *".ws-manifest"* ]]
}

# =============================================================================
# Modo offline
# =============================================================================

@test "ws origins clone: el modo offline lo impide con un mensaje claro" {
    create_remote app
    cat > "$MANIFEST" <<EOF
app  file://$REMOTES/app.git  core  -  -
EOF
    run env WS_CONFIG_FILE=/dev/null \
        WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT" \
        WS_TOOLS="$WS_TOOLS_ROOT" \
        WS_OFFLINE=1 \
        "$WS_TOOLS_ROOT/bin/ws-origins" clone --manifest "$MANIFEST"
    [ "$status" -eq 1 ]
    [[ "$output" == *"offline"* ]]
}
