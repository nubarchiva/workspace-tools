#!/usr/bin/env bats
# Tests para ws-grep
# Verifica el comportamiento del comando ws grep

load 'test_helper'

setup() {
    setup_test_environment
}

teardown() {
    teardown_test_environment
}

# =============================================================================
# Tests de ayuda
# =============================================================================

@test "ws-grep: -h shows help" {
    run run_ws grep -h

    [ "$status" -eq 0 ]
    [[ "$output" == *"Uso: ws grep"* ]]
}

@test "ws-grep: --help shows help" {
    run run_ws grep --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Uso: ws grep"* ]]
}

@test "ws-grep: help mentions options" {
    run run_ws grep --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"-i"* ]] || [[ "$output" == *"ignore-case"* ]]
    [[ "$output" == *"-l"* ]] || [[ "$output" == *"files-only"* ]]
    [[ "$output" == *"--type"* ]]
}

# =============================================================================
# Tests de validación de argumentos
# =============================================================================

@test "ws-grep: no pattern fails with clear message" {
    run run_ws grep

    [ "$status" -eq 1 ]
    [[ "$output" == *"patrón"* ]] || [[ "$output" == *"Debes especificar"* ]]
}

@test "ws-grep: unknown option fails" {
    run run_ws grep --opcion-invalida "patron"

    [ "$status" -eq 1 ]
    [[ "$output" == *"desconocida"* ]] || [[ "$output" == *"Opción"* ]]
}

# =============================================================================
# Tests de deteccion de workspace
# =============================================================================

@test "ws-grep: nonexistent workspace fails" {
    run run_ws grep "patron" no-existe-xyz

    [ "$status" -eq 1 ]
    [[ "$output" == *"No se encontró"* ]] || [[ "$output" == *"no existe"* ]]
}

@test "ws-grep: no workspace outside workspace fails" {
    cd "$TEST_WORKSPACE_ROOT"
    run run_ws grep "patron"

    [ "$status" -eq 1 ]
    [[ "$output" == *"no se pudo detectar"* ]] || [[ "$output" == *"No se especificó"* ]]
}

@test "ws-grep: partial match finds workspace" {
    mkdir -p "$TEST_WORKSPACES_DIR/feature-GREP-1234"
    create_test_repo "repo-grep"

    cd "$TEST_WORKSPACE_ROOT/repo-grep"
    git worktree add "$TEST_WORKSPACES_DIR/feature-GREP-1234/repo-grep" -b feature/grep-1234 2>/dev/null || true
    cd - > /dev/null

    run run_ws grep "test" 1234

    # Debe encontrar el workspace
    [[ "$output" == *"GREP-1234"* ]] || [[ "$output" == *"feature-GREP-1234"* ]]
}

# =============================================================================
# Tests de busqueda
# =============================================================================

@test "ws-grep: empty workspace fails" {
    mkdir -p "$TEST_WORKSPACES_DIR/grep-vacio"

    run run_ws grep "patron" grep-vacio

    [ "$status" -eq 1 ]
    [[ "$output" == *"No hay repos"* ]]
}

@test "ws-grep: search without results shows message" {
    mkdir -p "$TEST_WORKSPACES_DIR/grep-sin-resultado"
    create_test_repo "repo-busqueda"

    cd "$TEST_WORKSPACE_ROOT/repo-busqueda"
    git worktree add "$TEST_WORKSPACES_DIR/grep-sin-resultado/repo-busqueda" -b feature/grep-sin-resultado 2>/dev/null || true
    cd - > /dev/null

    run run_ws grep "TEXTO_QUE_NO_EXISTE_12345" grep-sin-resultado

    [ "$status" -eq 0 ]
    [[ "$output" == *"No se encontraron"* ]]
}

@test "ws-grep: search with results shows matches" {
    mkdir -p "$TEST_WORKSPACES_DIR/grep-con-resultado"
    create_test_repo "repo-con-texto"

    cd "$TEST_WORKSPACE_ROOT/repo-con-texto"
    echo "TEXTO_BUSCADO_AQUI" > archivo_busqueda.txt
    git add archivo_busqueda.txt
    git commit -m "add search file"
    git worktree add "$TEST_WORKSPACES_DIR/grep-con-resultado/repo-con-texto" -b feature/grep-con-resultado 2>/dev/null || true
    cd - > /dev/null

    run run_ws grep "TEXTO_BUSCADO_AQUI" grep-con-resultado

    [ "$status" -eq 0 ]
    [[ "$output" == *"TEXTO_BUSCADO_AQUI"* ]] || [[ "$output" == *"archivo_busqueda"* ]]
}

# =============================================================================
# Tests de opciones
# =============================================================================

@test "ws-grep: -i searches case-insensitive" {
    mkdir -p "$TEST_WORKSPACES_DIR/grep-case"
    create_test_repo "repo-case"

    cd "$TEST_WORKSPACE_ROOT/repo-case"
    echo "TextoMixto" > archivo.txt
    git add archivo.txt
    git commit -m "add file"
    git worktree add "$TEST_WORKSPACES_DIR/grep-case/repo-case" -b feature/grep-case 2>/dev/null || true
    cd - > /dev/null

    run run_ws grep -i "textomixto" grep-case

    [ "$status" -eq 0 ]
    [[ "$output" == *"TextoMixto"* ]] || [[ "$output" == *"archivo.txt"* ]]
}

@test "ws-grep: --type filters by extension" {
    mkdir -p "$TEST_WORKSPACES_DIR/grep-type"
    create_test_repo "repo-type"

    cd "$TEST_WORKSPACE_ROOT/repo-type"
    echo "BUSCAR_ESTO" > archivo.java
    echo "BUSCAR_ESTO" > archivo.txt
    git add archivo.java archivo.txt
    git commit -m "add files"
    git worktree add "$TEST_WORKSPACES_DIR/grep-type/repo-type" -b feature/grep-type 2>/dev/null || true
    cd - > /dev/null

    run run_ws grep --type java "BUSCAR_ESTO" grep-type

    [ "$status" -eq 0 ]
    [[ "$output" == *".java"* ]]
}

# =============================================================================
# Tests de header y formato
# =============================================================================

@test "ws-grep: shows header with search pattern" {
    mkdir -p "$TEST_WORKSPACES_DIR/grep-header"
    create_test_repo "repo-header"

    cd "$TEST_WORKSPACE_ROOT/repo-header"
    git worktree add "$TEST_WORKSPACES_DIR/grep-header/repo-header" -b feature/grep-header 2>/dev/null || true
    cd - > /dev/null

    run run_ws grep "mi_patron" grep-header

    [ "$status" -eq 0 ]
    [[ "$output" == *"mi_patron"* ]]
    [[ "$output" == *"Buscando"* ]] || [[ "$output" == *"grep-header"* ]]
}
