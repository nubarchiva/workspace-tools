#!/usr/bin/env bats
# Tests para ws-manifest-utils.sh
# Parseo, composición y diagnóstico del manifiesto de repos origen

load 'test_helper'

setup() {
    setup_test_environment
    source "$WS_TOOLS_ROOT/bin/ws-colors.sh"
    source "$WS_TOOLS_ROOT/bin/ws-manifest-utils.sh"
    manifest_reset
    MANIFEST_FILE="$TEST_TEMP_DIR/manifest"
}

teardown() {
    teardown_test_environment
}

# =============================================================================
# Parseo del formato
# =============================================================================

@test "manifest_load_file: parsea los cinco campos" {
    cat > "$MANIFEST_FILE" <<'EOF'
app  git@example.com:org/app.git  core,apps  -  -
EOF
    manifest_load_file "$MANIFEST_FILE"
    [ "$(manifest_count)" -eq 1 ]
    [ "$(manifest_field "${MANIFEST_ENTRIES[0]}" dest)" = "app" ]
    [ "$(manifest_field "${MANIFEST_ENTRIES[0]}" url)" = "git@example.com:org/app.git" ]
    [ "$(manifest_field "${MANIFEST_ENTRIES[0]}" groups)" = "core,apps" ]
}

@test "manifest_load_file: ignora comentarios y líneas vacías" {
    cat > "$MANIFEST_FILE" <<'EOF'
# un comentario

app  git@example.com:org/app.git  core  -  -

# otro comentario
EOF
    manifest_load_file "$MANIFEST_FILE"
    [ "$(manifest_count)" -eq 1 ]
}

@test "manifest_load_file: admite destinos anidados" {
    cat > "$MANIFEST_FILE" <<'EOF'
libs/marc4j  git@example.com:org/marc4j.git  core,libs  -  -
EOF
    manifest_load_file "$MANIFEST_FILE"
    [ "$(manifest_field "${MANIFEST_ENTRIES[0]}" dest)" = "libs/marc4j" ]
}

@test "manifest_load_file: el motivo admite espacios hasta fin de línea" {
    cat > "$MANIFEST_FILE" <<'EOF'
legacy  https://ej.org/r.git  external  manual  requiere certificado de cliente (mTLS)
EOF
    manifest_load_file "$MANIFEST_FILE"
    [ "$(manifest_field "${MANIFEST_ENTRIES[0]}" note)" = "requiere certificado de cliente (mTLS)" ]
}

@test "manifest_load_file: '-' equivale a campo vacio" {
    cat > "$MANIFEST_FILE" <<'EOF'
app  git@example.com:org/app.git  -  -  -
EOF
    manifest_load_file "$MANIFEST_FILE"
    [ -z "$(manifest_field "${MANIFEST_ENTRIES[0]}" groups)" ]
    [ -z "$(manifest_field "${MANIFEST_ENTRIES[0]}" flags)" ]
}

@test "manifest_load_file: descarta la entrada sin URL" {
    cat > "$MANIFEST_FILE" <<'EOF'
solo-destino
app  git@example.com:org/app.git  core  -  -
EOF
    manifest_load_file "$MANIFEST_FILE"
    [ "$(manifest_count)" -eq 1 ]
}

@test "manifest_load_file: fichero inexistente retorna 1" {
    run manifest_load_file "$TEST_TEMP_DIR/no-existe"
    [ "$status" -eq 1 ]
}

# =============================================================================
# Composición de varios manifiestos (público + privado + personal)
# =============================================================================

@test "manifest_load_file: componer dos manifiestos suma entradas" {
    cat > "$MANIFEST_FILE" <<'EOF'
app  git@example.com:org/app.git  core  -  -
EOF
    cat > "$TEST_TEMP_DIR/privado" <<'EOF'
interno  git@interno.example.com:org/crm.git  private  -  -
EOF
    manifest_load_file "$MANIFEST_FILE"
    manifest_load_file "$TEST_TEMP_DIR/privado"
    [ "$(manifest_count)" -eq 2 ]
}

@test "manifest_load_file: a igualdad de destino gana el último cargado" {
    cat > "$MANIFEST_FILE" <<'EOF'
app  git@publico.example.com:org/app.git  core  -  -
EOF
    cat > "$TEST_TEMP_DIR/privado" <<'EOF'
app  git@privado.example.com:org/app.git  core  -  -
EOF
    manifest_load_file "$MANIFEST_FILE"
    manifest_load_file "$TEST_TEMP_DIR/privado"
    [ "$(manifest_count)" -eq 1 ]
    [ "$(manifest_field "${MANIFEST_ENTRIES[0]}" url)" = "git@privado.example.com:org/app.git" ]
}

# =============================================================================
# Grupos y flags
# =============================================================================

@test "manifest_in_groups: selección vacía encaja con cualquier entrada" {
    cat > "$MANIFEST_FILE" <<'EOF'
app  git@example.com:org/app.git  -  -  -
EOF
    manifest_load_file "$MANIFEST_FILE"
    run manifest_in_groups "${MANIFEST_ENTRIES[0]}" ""
    [ "$status" -eq 0 ]
}

@test "manifest_in_groups: encaja si comparte algún grupo" {
    cat > "$MANIFEST_FILE" <<'EOF'
app  git@example.com:org/app.git  core,apps  -  -
EOF
    manifest_load_file "$MANIFEST_FILE"
    run manifest_in_groups "${MANIFEST_ENTRIES[0]}" "web,apps"
    [ "$status" -eq 0 ]
}

@test "manifest_in_groups: no encaja si no comparte ninguno" {
    cat > "$MANIFEST_FILE" <<'EOF'
app  git@example.com:org/app.git  core,apps  -  -
EOF
    manifest_load_file "$MANIFEST_FILE"
    run manifest_in_groups "${MANIFEST_ENTRIES[0]}" "web"
    [ "$status" -eq 1 ]
}

@test "manifest_in_groups: entrada sin grupos queda fuera de toda selección" {
    cat > "$MANIFEST_FILE" <<'EOF'
app  git@example.com:org/app.git  -  -  -
EOF
    manifest_load_file "$MANIFEST_FILE"
    run manifest_in_groups "${MANIFEST_ENTRIES[0]}" "core"
    [ "$status" -eq 1 ]
}

@test "manifest_has_flag: detecta 'manual'" {
    cat > "$MANIFEST_FILE" <<'EOF'
legacy  https://ej.org/r.git  external  manual  motivo
EOF
    manifest_load_file "$MANIFEST_FILE"
    run manifest_has_flag "${MANIFEST_ENTRIES[0]}" manual
    [ "$status" -eq 0 ]
}

@test "manifest_has_flag: no confunde un flag con otro" {
    cat > "$MANIFEST_FILE" <<'EOF'
app  git@example.com:org/app.git  core  otro  -
EOF
    manifest_load_file "$MANIFEST_FILE"
    run manifest_has_flag "${MANIFEST_ENTRIES[0]}" manual
    [ "$status" -eq 1 ]
}

@test "manifest_groups_list: lista sin repetir y ordenada" {
    cat > "$MANIFEST_FILE" <<'EOF'
app          git@example.com:org/app.git     core,apps  -  -
libs/common  git@example.com:org/common.git  core,libs  -  -
EOF
    manifest_load_file "$MANIFEST_FILE"
    run manifest_groups_list
    [ "${lines[0]}" = "apps" ]
    [ "${lines[1]}" = "core" ]
    [ "${lines[2]}" = "libs" ]
    [ "${#lines[@]}" -eq 3 ]
}

# =============================================================================
# Análisis de URLs
# =============================================================================

@test "manifest_url_host: URL ssh:// con puerto" {
    run manifest_url_host "ssh://git@servidor.example.com:7999/proj/repo.git"
    [ "$output" = "servidor.example.com" ]
}

@test "manifest_url_host: URL scp-like" {
    run manifest_url_host "git@github.com:org/repo.git"
    [ "$output" = "github.com" ]
}

@test "manifest_url_host: URL https" {
    run manifest_url_host "https://servidor.example.com/cirepo/repo.git"
    [ "$output" = "servidor.example.com" ]
}

@test "manifest_url_host: una ruta local no tiene host" {
    run manifest_url_host "/ruta/local/repo.git"
    [ -z "$output" ]
}

@test "manifest_url_port: toma el puerto de la URL" {
    run manifest_url_port "ssh://git@servidor.example.com:7999/proj/repo.git"
    [ "$output" = "7999" ]
}

@test "manifest_url_port: 22 si la URL ssh no lo lleva" {
    run manifest_url_port "ssh://git@servidor.example.com/proj/repo.git"
    [ "$output" = "22" ]
}

@test "manifest_url_port: 443 para https sin puerto" {
    run manifest_url_port "https://github.com/org/repo.git"
    [ "$output" = "443" ]
}

@test "manifest_url_port: 80 para http sin puerto" {
    run manifest_url_port "http://servidor.example.com/repo.git"
    [ "$output" = "80" ]
}

@test "manifest_url_port: 22 para la forma scp-like" {
    run manifest_url_port "git@github.com:org/repo.git"
    [ "$output" = "22" ]
}

@test "manifest_diagnose: un https sin conexión no habla del puerto 22" {
    run manifest_diagnose "https://github.com/org/repo.git" "fatal: unable to access: Failed to connect to github.com port 443: Connection timed out"
    [[ "$output" == *"443"* ]]
    [[ "$output" != *"puerto 22"* ]]
}

@test "manifest_diagnose: un https sin conexión menciona las variables de proxy" {
    run manifest_diagnose "https://github.com/org/repo.git" "fatal: unable to access: Failed to connect to github.com port 443: Connection timed out"
    [[ "$output" == *"https_proxy"* ]]
}

@test "manifest_diagnose: un ssh sin conexión no menciona variables de proxy" {
    run manifest_diagnose "ssh://git@srv.example.com:7999/p/r.git" "ssh: connect to host srv.example.com port 7999: Connection timed out"
    [[ "$output" == *"7999"* ]]
    [[ "$output" != *"https_proxy"* ]]
}

@test "manifest_distinct_hosts: un host aparece una sola vez" {
    cat > "$MANIFEST_FILE" <<'EOF'
a  ssh://git@srv.example.com:7999/p/a.git  core  -  -
b  ssh://git@srv.example.com:7999/p/b.git  core  -  -
c  git@github.com:org/c.git                core  -  -
EOF
    manifest_load_file "$MANIFEST_FILE"
    local out
    out=$(printf '%s\n' "${MANIFEST_ENTRIES[@]}" | manifest_distinct_hosts | cut -f1)
    [ "$(echo "$out" | wc -l | tr -d ' ')" -eq 2 ]
}

# =============================================================================
# Diagnóstico de errores
# =============================================================================

@test "manifest_diagnose: nombre que no resuelve" {
    run manifest_diagnose "ssh://git@srv.example.com:7999/p/r.git" "ssh: Could not resolve hostname srv.example.com"
    [[ "$output" == *"no resuelve"* ]]
}

@test "manifest_diagnose: host key desconocida propone ssh-keyscan con el puerto" {
    run manifest_diagnose "ssh://git@srv.example.com:7999/p/r.git" "Host key verification failed."
    [[ "$output" == *"ssh-keyscan -p 7999 srv.example.com"* ]]
}

@test "manifest_diagnose: clave rechazada" {
    run manifest_diagnose "ssh://git@srv.example.com:7999/p/r.git" "git@srv: Permission denied (publickey)."
    [[ "$output" == *"rechaza la clave"* ]]
    [[ "$output" == *"ssh-add -l"* ]]
}

@test "manifest_diagnose: HTTPS sin credenciales" {
    run manifest_diagnose "https://srv.example.com/p/r.git" "fatal: could not read Username for 'https://srv.example.com': terminal prompts disabled"
    [[ "$output" == *"credenciales"* ]]
}

@test "manifest_diagnose: certificado de cliente sugiere marcarlo 'manual'" {
    run manifest_diagnose "https://srv.example.com/p/r.git" "SSL certificate problem: unable to get local issuer certificate"
    [[ "$output" == *"manual"* ]]
}

@test "manifest_diagnose: red bloqueada menciona cortafuegos o proxy" {
    run manifest_diagnose "ssh://git@srv.example.com:7999/p/r.git" "ssh: connect to host srv.example.com port 7999: Connection timed out"
    [[ "$output" == *"proxy"* ]]
}
