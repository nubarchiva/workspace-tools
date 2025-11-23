#!/bin/bash
# Test helper para workspace-tools
# Proporciona setup/teardown y funciones auxiliares para tests

# Directorio del proyecto
export WS_TOOLS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export WS_TOOLS="$WS_TOOLS_ROOT"

# Directorio temporal para tests (se crea en setup, se elimina en teardown)
export TEST_TEMP_DIR=""
export TEST_WORKSPACE_ROOT=""
export TEST_WORKSPACES_DIR=""

# Crear entorno de prueba aislado
setup_test_environment() {
    # Crear directorio temporal único para este test
    # Nota: normalizamos el path para evitar dobles slashes (TMPDIR puede tener trailing /)
    local tmpdir="${TMPDIR:-/tmp}"
    tmpdir="${tmpdir%/}"  # Eliminar trailing slash si existe
    TEST_TEMP_DIR=$(mktemp -d "${tmpdir}/ws-test.XXXXXX")
    TEST_WORKSPACE_ROOT="$TEST_TEMP_DIR/workspace"
    TEST_WORKSPACES_DIR="$TEST_WORKSPACE_ROOT/workspaces"

    # Crear estructura básica
    mkdir -p "$TEST_WORKSPACE_ROOT"
    mkdir -p "$TEST_WORKSPACES_DIR"

    # Sobrescribir variables de entorno para que los scripts usen el entorno de prueba
    export WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT"
    export WORKSPACES_DIR="$TEST_WORKSPACES_DIR"

    # Crear WS_TOOLS temporal que apunte al entorno de prueba pero use los scripts reales
    # Esto es un poco tricky: necesitamos que los scripts lean de TEST pero ejecuten desde WS_TOOLS_ROOT
    export WS_TOOLS="$WS_TOOLS_ROOT"
}

# Limpiar entorno de prueba
teardown_test_environment() {
    if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Crear un repo Git de prueba
# Uso: create_test_repo "nombre" o create_test_repo "subdir/nombre"
# Nota: Crea branch "master" por defecto para compatibilidad
create_test_repo() {
    local repo_path="$TEST_WORKSPACE_ROOT/$1"
    mkdir -p "$repo_path"
    cd "$repo_path"
    git init --quiet --initial-branch=master
    git config user.email "test@test.com"
    git config user.name "Test User"
    # Crear commit inicial para que el repo sea válido
    echo "# Test repo: $1" > README.md
    git add README.md
    git commit --quiet -m "Initial commit"
    cd - > /dev/null
    echo "$repo_path"
}

# Crear un repo con pom.xml (proyecto Maven)
create_maven_repo() {
    local repo_path=$(create_test_repo "$1")
    cat > "$repo_path/pom.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project>
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.test</groupId>
    <artifactId>test-project</artifactId>
    <version>1.0.0</version>
</project>
EOF
    cd "$repo_path"
    git add pom.xml
    git commit --quiet -m "Add pom.xml"
    cd - > /dev/null
    echo "$repo_path"
}

# Verificar que un workspace existe
workspace_exists() {
    local name="$1"
    [[ -d "$TEST_WORKSPACES_DIR/$name" ]]
}

# Verificar que un repo existe en un workspace
repo_in_workspace() {
    local workspace="$1"
    local repo="$2"
    [[ -d "$TEST_WORKSPACES_DIR/$workspace/$repo" ]]
}

# Contar repos en un workspace
count_repos_in_workspace() {
    local workspace="$1"
    local workspace_dir="$TEST_WORKSPACES_DIR/$workspace"
    if [[ ! -d "$workspace_dir" ]]; then
        echo 0
        return
    fi
    find "$workspace_dir" -maxdepth 3 -name ".git" -type d 2>/dev/null | wc -l | tr -d ' '
}

# Obtener la branch actual de un repo
get_current_branch() {
    local repo_path="$1"
    cd "$repo_path"
    git branch --show-current
    cd - > /dev/null
}

# Ejecutar comando ws con entorno de prueba
# Los scripts detectan WORKSPACE_ROOT desde WS_TOOLS, así que necesitamos un wrapper
run_ws() {
    # Crear un script temporal que sobrescriba las variables antes de ejecutar
    local temp_script=$(mktemp)
    cat > "$temp_script" << EOF
#!/bin/bash
export WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT"
export WORKSPACES_DIR="$TEST_WORKSPACES_DIR"
# Hack: modificar WS_TOOLS temporalmente para que los scripts calculen el WORKSPACE_ROOT correcto
# Los scripts hacen: WORKSPACE_ROOT="\${WS_TOOLS%/tools/workspace-tools}"
# Así que si WS_TOOLS=/fake/path/tools/workspace-tools, WORKSPACE_ROOT será /fake/path
# Pero necesitamos que use nuestros scripts reales...

# Solución: ejecutar directamente sobrescribiendo variables en el entorno
cd "$WS_TOOLS_ROOT/bin"
exec env WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT" ./ws "\$@"
EOF
    chmod +x "$temp_script"
    "$temp_script" "$@"
    local exit_code=$?
    rm -f "$temp_script"
    return $exit_code
}

# Cargar funciones de ws-common.sh para tests unitarios
load_ws_common() {
    source "$WS_TOOLS_ROOT/bin/ws-colors.sh"
    source "$WS_TOOLS_ROOT/bin/ws-common.sh"
}

# Assert helpers
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"
    if [[ "$expected" != "$actual" ]]; then
        echo "Assertion failed: $message"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-}"
    if [[ "$haystack" != *"$needle"* ]]; then
        echo "Assertion failed: $message"
        echo "  Expected to contain: $needle"
        echo "  In: $haystack"
        return 1
    fi
}

assert_dir_exists() {
    local dir="$1"
    local message="${2:-Directory should exist: $dir}"
    if [[ ! -d "$dir" ]]; then
        echo "Assertion failed: $message"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist: $file}"
    if [[ ! -f "$file" ]]; then
        echo "Assertion failed: $message"
        return 1
    fi
}
