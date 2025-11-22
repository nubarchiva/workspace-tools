#!/bin/bash
# Script para ejecutar todos los tests de workspace-tools
#
# Uso:
#   ./tests/run_tests.sh           # Todos los tests
#   ./tests/run_tests.sh common    # Solo tests de ws-common
#   ./tests/run_tests.sh -v        # Modo verbose
#   ./tests/run_tests.sh --tap     # Output en formato TAP

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Verificar que BATS esta instalado
if ! command -v bats &> /dev/null; then
    echo -e "${RED}Error: BATS no esta instalado${NC}"
    echo ""
    echo "Instalar con:"
    echo "  brew install bats-core"
    echo ""
    exit 1
fi

# Parsear argumentos
BATS_ARGS=""
TEST_FILTER=""
SHOW_SUMMARY=true

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            BATS_ARGS="$BATS_ARGS --verbose-run"
            shift
            ;;
        --tap)
            BATS_ARGS="$BATS_ARGS --formatter tap"
            SHOW_SUMMARY=false
            shift
            ;;
        -t|--timing)
            BATS_ARGS="$BATS_ARGS --timing"
            shift
            ;;
        -h|--help)
            echo "Uso: $0 [opciones] [filtro]"
            echo ""
            echo "Opciones:"
            echo "  -v, --verbose    Modo verbose"
            echo "  --tap            Output en formato TAP"
            echo "  -t, --timing     Mostrar tiempo de cada test"
            echo "  -h, --help       Mostrar esta ayuda"
            echo ""
            echo "Filtros disponibles:"
            echo "  common           Tests de ws-common.sh"
            echo "  new              Tests de ws-new"
            echo "  list             Tests de ws-list"
            echo "  clean            Tests de ws-clean"
            echo "  add              Tests de ws-add"
            echo ""
            echo "Ejemplos:"
            echo "  $0                    # Todos los tests"
            echo "  $0 common             # Solo ws-common"
            echo "  $0 -v new             # ws-new en modo verbose"
            exit 0
            ;;
        *)
            TEST_FILTER="$1"
            shift
            ;;
    esac
done

cd "$PROJECT_ROOT"

echo -e "${BOLD}${CYAN}"
echo "════════════════════════════════════════════════════"
echo "  Workspace Tools - Test Suite"
echo "════════════════════════════════════════════════════"
echo -e "${NC}"

# Determinar que tests ejecutar
if [[ -n "$TEST_FILTER" ]]; then
    TEST_FILE="tests/test_ws_${TEST_FILTER}.bats"
    if [[ ! -f "$TEST_FILE" ]]; then
        echo -e "${RED}Error: No existe el archivo de tests: $TEST_FILE${NC}"
        echo ""
        echo "Tests disponibles:"
        ls tests/test_*.bats 2>/dev/null | sed 's|tests/test_ws_||' | sed 's|.bats||' | sed 's|^|  • |'
        exit 1
    fi
    TEST_FILES="$TEST_FILE"
    echo -e "Ejecutando tests de: ${CYAN}$TEST_FILTER${NC}"
else
    TEST_FILES="tests/test_*.bats"
    echo -e "Ejecutando: ${CYAN}todos los tests${NC}"
fi

echo ""

# Ejecutar tests
if bats $BATS_ARGS $TEST_FILES; then
    echo ""
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}  TODOS LOS TESTS PASARON${NC}"
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════${NC}"
    exit 0
else
    EXIT_CODE=$?
    echo ""
    echo -e "${RED}${BOLD}════════════════════════════════════════════════════${NC}"
    echo -e "${RED}${BOLD}  ALGUNOS TESTS FALLARON${NC}"
    echo -e "${RED}${BOLD}════════════════════════════════════════════════════${NC}"
    exit $EXIT_CODE
fi
