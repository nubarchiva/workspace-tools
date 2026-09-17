#!/usr/bin/env bats
# Tests para el autocompletado de ws (bash y zsh)
#
# Las funciones del sistema de completado se sustituyen por dobles que imprimen lo
# que se ofrecería: así se comprueba el contenido sin una shell interactiva.

load 'test_helper'

setup() {
    setup_test_environment
    mkdir -p "$TEST_WORKSPACES_DIR/feat" "$TEST_WORKSPACES_DIR/main"
}

teardown() {
    teardown_test_environment
}

# Candidatos que ofrece bash para la línea dada; el último argumento es la palabra en curso
# Uso: bash_complete <palabra>...
bash_complete() {
    WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT" WORKSPACES_DIR="$TEST_WORKSPACES_DIR" bash -c '
        _init_completion() {
            words=("${COMP_WORDS[@]}")
            cword=$COMP_CWORD
            cur="${COMP_WORDS[COMP_CWORD]}"
            prev="${COMP_WORDS[COMP_CWORD-1]}"
        }
        complete() { :; }
        source "$1"
        shift
        COMP_WORDS=(ws "$@")
        COMP_CWORD=$#
        _ws_completion
        printf "%s\n" "${COMPREPLY[@]}"
    ' _ "$WS_TOOLS_ROOT/completions/ws-completion.bash" "$@"
}

# Candidatos que ofrece zsh para la línea dada; el último argumento es la palabra en curso
# Uso: zsh_complete <palabra>...
zsh_complete() {
    WORKSPACE_ROOT="$TEST_WORKSPACE_ROOT" WORKSPACES_DIR="$TEST_WORKSPACES_DIR" zsh -f -c '
        compdef() { : }
        _describe() {
            shift
            local name
            for name in "$@"; do
                [[ "$name" == -* ]] && continue
                print -rl -- "${(@P)name}"
            done
        }
        _alternative() { print -rl -- "$@" }
        source "$1"
        shift
        words=(ws "$@")
        CURRENT=${#words}
        _ws
    ' _ "$WS_TOOLS_ROOT/completions/ws-completion.zsh" "$@"
}

require_zsh() {
    command -v zsh >/dev/null 2>&1 || skip "zsh no está instalado"
}

# Comprueba que cada palabra aparece como candidato completo en la salida
# Uso: assert_offers "<salida>" <palabra>...
assert_offers() {
    local output="$1"
    shift
    local word
    for word in "$@"; do
        if ! printf '%s\n' "$output" | grep -qE -- "(^|[ (])$(printf '%s' "$word" | sed 's/[.]/\\./g')(\$|[: \\])"; then
            echo "No se ofrece: $word"
            echo "Salida:"
            echo "$output"
            return 1
        fi
    done
}

# =============================================================================
# bash
# =============================================================================

@test "bash: subcomandos, version y todos los alias" {
    run bash_complete ""
    assert_offers "$output" env version sw del mk create here . h ls cd rm mv st tpl
}

@test "bash: ws env ofrece acciones y opciones" {
    run bash_complete env ""
    assert_offers "$output" status sync --no-fetch --help
}

@test "bash: ws env status y ws env sync ofrecen sus opciones" {
    run bash_complete env status ""
    assert_offers "$output" --no-fetch --help

    run bash_complete env sync ""
    assert_offers "$output" --yes -y --sessions --help
}

@test "bash: ws update ofrece --all y --dry" {
    run bash_complete update ""
    assert_offers "$output" --all -a --dry -d feat

    run bash_complete update feat ""
    assert_offers "$output" --all -a --dry -d
}

@test "bash: ws clean ofrece --force" {
    run bash_complete clean ""
    assert_offers "$output" --force -f feat
}

@test "bash: ws grep ofrece --count" {
    run bash_complete grep patron ""
    assert_offers "$output" -c

    run bash_complete grep patron feat ""
    assert_offers "$output" -c
}

@test "bash: ws origins clone ofrece las formas cortas" {
    run bash_complete origins clone ""
    assert_offers "$output" -g -m -n --help
}

@test "bash: ws mgmt-link ofrece --help" {
    run bash_complete mgmt-link ""
    assert_offers "$output" --help
}

# =============================================================================
# zsh
# =============================================================================

@test "zsh: subcomandos, version y todos los alias" {
    require_zsh
    run zsh_complete ""
    assert_offers "$output" env version sw del mk create here . h ls cd rm mv st tpl
}

@test "zsh: here y . completan workspaces" {
    require_zsh
    run zsh_complete here ""
    assert_offers "$output" feat

    run zsh_complete . ""
    assert_offers "$output" feat
}

@test "zsh: main se describe como rama de integración" {
    require_zsh
    run zsh_complete switch ""
    assert_offers "$output" "main"
    [[ "$output" == *"main:branch main"* ]]
}

@test "zsh: ws env ofrece acciones y opciones" {
    require_zsh
    run zsh_complete env ""
    assert_offers "$output" status sync --no-fetch --help
}

@test "zsh: ws env status y ws env sync ofrecen sus opciones" {
    require_zsh
    run zsh_complete env status ""
    assert_offers "$output" --no-fetch --help

    run zsh_complete env sync ""
    assert_offers "$output" --yes -y --sessions --help
}

@test "zsh: ws update ofrece --all y --dry" {
    require_zsh
    run zsh_complete update ""
    assert_offers "$output" --all -a --dry -d

    run zsh_complete update feat ""
    assert_offers "$output" --all -a --dry -d
}

@test "zsh: ws clean ofrece --force" {
    require_zsh
    run zsh_complete clean ""
    assert_offers "$output" --force -f
}

@test "zsh: ws grep ofrece --count, -w y -E" {
    require_zsh
    run zsh_complete grep patron ""
    assert_offers "$output" -c -w -E

    run zsh_complete grep patron feat ""
    assert_offers "$output" -c
}

@test "zsh: ws origins clone ofrece las formas cortas y --help" {
    require_zsh
    run zsh_complete origins clone ""
    assert_offers "$output" -g -m -n --help
}

@test "zsh: ws mgmt-link ofrece --help" {
    require_zsh
    run zsh_complete mgmt-link ""
    assert_offers "$output" --help
}
