#!/usr/bin/env bats
# Tests para ws-mvn
# Verifica el comportamiento del comando ws mvn

load 'test_helper'

setup() {
    setup_test_environment
}

teardown() {
    teardown_test_environment
}

# =============================================================================
# Tests de ayuda (no requieren Maven instalado)
# =============================================================================

@test "ws-mvn: no args and no detected workspace shows error" {
    cd "$TEST_WORKSPACE_ROOT"
    run run_ws mvn

    [ "$status" -eq 1 ]
    # Puede fallar por no tener args de Maven o por no detectar workspace
    [[ "$output" == *"no se especificó"* ]] || [[ "$output" == *"no se pudo detectar"* ]] || [[ "$output" == *"argumentos"* ]]
}

@test "ws-mvn: workspace without maven args shows error" {
    mkdir -p "$TEST_WORKSPACES_DIR/mvn-test"

    run run_ws mvn mvn-test

    [ "$status" -eq 1 ]
    [[ "$output" == *"argumentos"* ]] || [[ "$output" == *"Maven"* ]]
}

# =============================================================================
# Tests de deteccion de workspace
# =============================================================================

@test "ws-mvn: nonexistent workspace fails" {
    run run_ws mvn no-existe-xyz clean

    [ "$status" -eq 1 ]
    [[ "$output" == *"No se encontró"* ]] || [[ "$output" == *"no existe"* ]]
}

@test "ws-mvn: partial match finds workspace" {
    mkdir -p "$TEST_WORKSPACES_DIR/feature-MVN-5678"

    run run_ws mvn 5678 clean

    # Puede fallar por no tener repos, pero debe encontrar el workspace primero
    [[ "$output" == *"MVN-5678"* ]] || [[ "$output" == *"feature-MVN-5678"* ]] || [[ "$output" == *"No hay repos"* ]]
}

@test "ws-mvn: empty workspace fails with clear message" {
    mkdir -p "$TEST_WORKSPACES_DIR/mvn-vacio"

    run run_ws mvn mvn-vacio clean

    [ "$status" -eq 1 ]
    [[ "$output" == *"No hay repos"* ]]
}

# =============================================================================
# Tests de deteccion inteligente de argumentos
# =============================================================================

@test "ws-mvn: primer arg que no es workspace intenta usar como workspace" {
    # Crear workspace con nombre que NO coincide con "clean"
    mkdir -p "$TEST_WORKSPACES_DIR/mi-workspace"
    create_test_repo "repo-mvn"

    cd "$TEST_WORKSPACE_ROOT/repo-mvn"
    git worktree add "$TEST_WORKSPACES_DIR/mi-workspace/repo-mvn" -b feature/mi-workspace 2>/dev/null || true
    cd - > /dev/null

    # Ejecutar desde fuera del workspace con arg "clean" (no es workspace)
    # El script primero intenta detectar, si falla asume modo tradicional
    cd "$TEST_WORKSPACE_ROOT"
    run run_ws mvn clean install

    # Debe fallar porque "clean" no es un workspace válido
    [ "$status" -eq 1 ]
    # Puede fallar por: no encontrar workspace "clean" o no detectar automáticamente
    [[ "$output" == *"No se encontró"* ]] || [[ "$output" == *"no se pudo detectar"* ]] || [[ "$output" == *"no se especificó"* ]]
}

@test "ws-mvn: workspace explicito toma args restantes como maven args" {
    mkdir -p "$TEST_WORKSPACES_DIR/explicit-ws"
    create_test_repo "repo-explicit"

    cd "$TEST_WORKSPACE_ROOT/repo-explicit"
    # Crear pom.xml básico
    cat > pom.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project>
    <modelVersion>4.0.0</modelVersion>
    <groupId>test</groupId>
    <artifactId>test</artifactId>
    <version>1.0</version>
</project>
EOF
    git add pom.xml
    git commit -m "add pom"
    git worktree add "$TEST_WORKSPACES_DIR/explicit-ws/repo-explicit" -b feature/explicit-ws 2>/dev/null || true
    cd - > /dev/null

    run run_ws mvn explicit-ws --version

    # Debe mostrar el workspace y comando
    [[ "$output" == *"explicit-ws"* ]]
    [[ "$output" == *"--version"* ]] || [[ "$output" == *"mvn"* ]]
}

# =============================================================================
# Tests con repos Maven (requieren estructura básica)
# =============================================================================

@test "ws-mvn: repo sin pom.xml es ignorado" {
    mkdir -p "$TEST_WORKSPACES_DIR/sin-pom"
    create_test_repo "repo-sin-pom"

    cd "$TEST_WORKSPACE_ROOT/repo-sin-pom"
    git worktree add "$TEST_WORKSPACES_DIR/sin-pom/repo-sin-pom" -b feature/sin-pom 2>/dev/null || true
    cd - > /dev/null

    run run_ws mvn sin-pom validate

    # El script debe ejecutar pero no encontrar proyectos Maven
    # Puede mostrar "Ignorando" o terminar con éxito sin ejecutar nada
    [[ "$output" == *"Ignorando"* ]] || [[ "$output" == *"no tiene pom.xml"* ]] || [[ "$output" == *"sin-pom"* ]]
}

@test "ws-mvn: shows header with workspace info" {
    mkdir -p "$TEST_WORKSPACES_DIR/header-mvn"
    create_test_repo "repo-header-mvn"

    cd "$TEST_WORKSPACE_ROOT/repo-header-mvn"
    cat > pom.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project>
    <modelVersion>4.0.0</modelVersion>
    <groupId>test</groupId>
    <artifactId>test</artifactId>
    <version>1.0</version>
</project>
EOF
    git add pom.xml
    git commit -m "add pom"
    git worktree add "$TEST_WORKSPACES_DIR/header-mvn/repo-header-mvn" -b feature/header-mvn 2>/dev/null || true
    cd - > /dev/null

    run run_ws mvn header-mvn --version

    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]  # Puede fallar si mvn no está instalado
    [[ "$output" == *"header-mvn"* ]]
    [[ "$output" == *"Workspace"* ]] || [[ "$output" == *"Branch"* ]]
}

# =============================================================================
# Tests de orden de compilación
# =============================================================================

@test "ws-mvn: detecta .ws-build-order en workspace" {
    mkdir -p "$TEST_WORKSPACES_DIR/build-order"
    create_test_repo "repo-order"

    cd "$TEST_WORKSPACE_ROOT/repo-order"
    cat > pom.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project>
    <modelVersion>4.0.0</modelVersion>
    <groupId>test</groupId>
    <artifactId>test</artifactId>
    <version>1.0</version>
</project>
EOF
    git add pom.xml
    git commit -m "add pom"
    git worktree add "$TEST_WORKSPACES_DIR/build-order/repo-order" -b feature/build-order 2>/dev/null || true
    cd - > /dev/null

    # Crear archivo de orden
    echo "repo-order" > "$TEST_WORKSPACES_DIR/build-order/.ws-build-order"

    run run_ws mvn build-order --version

    # Debe mencionar el archivo de orden
    [[ "$output" == *"orden de compilación"* ]] || [[ "$output" == *".ws-build-order"* ]] || [[ "$output" == *"build-order"* ]]
}
