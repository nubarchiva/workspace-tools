#!/bin/bash
# Script de instalación para workspace-tools

# Colores (si el terminal los soporta)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' RESET=''
fi

echo "════════════════════════════════════════════════════"
echo "  Workspace Tools - Instalación"
echo "  Versión 4.1"
echo "════════════════════════════════════════════════════"
echo ""

# ══════════════════════════════════════════════════════════════
# Verificación de requisitos del sistema
# ══════════════════════════════════════════════════════════════

echo "📋 Verificando requisitos del sistema..."
echo ""

REQUIREMENTS_MET=true

# Verificar Bash (requerido para los scripts)
check_bash_version() {
    local bash_path
    local bash_version
    local bash_major
    local bash_minor

    # Buscar bash
    if command -v bash &> /dev/null; then
        bash_path=$(command -v bash)
        bash_version=$(bash --version | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
        bash_major=${bash_version%%.*}
        bash_minor=${bash_version#*.}

        if [[ $bash_major -gt 4 ]] || [[ $bash_major -eq 4 && $bash_minor -ge 0 ]]; then
            echo -e "   ${GREEN}✓${RESET} Bash $bash_version ($bash_path)"
            return 0
        else
            echo -e "   ${RED}✗${RESET} Bash $bash_version - Se requiere 4.0+"
            echo -e "     ${YELLOW}Los scripts requieren Bash 4.0+ para arrays asociativos${RESET}"
            return 1
        fi
    else
        echo -e "   ${RED}✗${RESET} Bash no encontrado - Requerido"
        return 1
    fi
}

# Verificar Git
check_git_version() {
    local git_version
    local git_major
    local git_minor

    if command -v git &> /dev/null; then
        git_version=$(git --version | grep -oE '[0-9]+\.[0-9]+' | head -n1)
        git_major=${git_version%%.*}
        git_minor=${git_version#*.}

        if [[ $git_major -gt 2 ]] || [[ $git_major -eq 2 && $git_minor -ge 15 ]]; then
            echo -e "   ${GREEN}✓${RESET} Git $git_version"
            return 0
        else
            echo -e "   ${RED}✗${RESET} Git $git_version - Se requiere 2.15+"
            echo -e "     ${YELLOW}Git worktrees requieren Git 2.15+${RESET}"
            return 1
        fi
    else
        echo -e "   ${RED}✗${RESET} Git no encontrado - Requerido"
        return 1
    fi
}

# Verificar shell del usuario (informativo)
check_user_shell() {
    local user_shell=$(basename "$SHELL")
    local shell_version

    case "$user_shell" in
        bash)
            shell_version=$(bash --version | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
            local major=${shell_version%%.*}
            if [[ $major -ge 4 ]]; then
                echo -e "   ${GREEN}✓${RESET} Shell: Bash $shell_version"
            else
                echo -e "   ${YELLOW}⚠${RESET} Shell: Bash $shell_version"
                echo -e "     ${YELLOW}Bash 4.0+ recomendado para setup.sh${RESET}"
            fi
            ;;
        zsh)
            shell_version=$(zsh --version | grep -oE '[0-9]+\.[0-9]+' | head -n1)
            local major=${shell_version%%.*}
            if [[ $major -ge 5 ]]; then
                echo -e "   ${GREEN}✓${RESET} Shell: Zsh $shell_version"
            else
                echo -e "   ${YELLOW}⚠${RESET} Shell: Zsh $shell_version"
                echo -e "     ${YELLOW}Zsh 5.0+ recomendado para setup.sh${RESET}"
            fi
            ;;
        *)
            echo -e "   ${YELLOW}⚠${RESET} Shell: $user_shell (no probado)"
            echo -e "     ${YELLOW}Funciones de navegación requieren bash/zsh${RESET}"
            ;;
    esac
}

# Ejecutar verificaciones
if ! check_bash_version; then
    REQUIREMENTS_MET=false
fi

if ! check_git_version; then
    REQUIREMENTS_MET=false
fi

check_user_shell

echo ""

if [[ "$REQUIREMENTS_MET" != "true" ]]; then
    echo -e "${RED}════════════════════════════════════════════════════${RESET}"
    echo -e "${RED}  ✗ Requisitos no cumplidos${RESET}"
    echo -e "${RED}════════════════════════════════════════════════════${RESET}"
    echo ""
    echo "Por favor, instala las versiones requeridas antes de continuar."
    echo ""
    echo "En macOS puedes actualizar Bash con:"
    echo "  brew install bash"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Requisitos del sistema verificados${RESET}"
echo ""

# ══════════════════════════════════════════════════════════════
# Instalación
# ══════════════════════════════════════════════════════════════

# Detectar directorio de instalación (2 niveles arriba)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "📍 Detectando ubicación..."
echo "   Workspace root: $WORKSPACE_ROOT"
echo "   Tools instalados en: $SCRIPT_DIR"
echo ""

# Verificar que estamos en la ubicación correcta
if [[ ! "$SCRIPT_DIR" == */tools/workspace-tools ]]; then
    echo "⚠️  Advertencia: Este script debería estar en:"
    echo "   $WORKSPACE_ROOT/tools/workspace-tools/"
    echo ""
    read -p "¿Continuar de todos modos? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo "❌ Instalación cancelada"
        exit 1
    fi
fi

# Verificar estructura de repos
echo "Verificando estructura de repos..."
echo ""

REPO_COUNT=0
echo "Repos encontrados:"

# Buscar en raíz (1 nivel)
for dir in "$WORKSPACE_ROOT"/*/.git; do
    if [ -d "$dir" ]; then
        repo_name=$(basename $(dirname "$dir"))
        if [ "$repo_name" != "workspaces" ]; then
            echo "  • $repo_name"
            ((REPO_COUNT++))
        fi
    fi
done

# Buscar en subdirectorios (2 niveles - libs/*, modules/*, tools/*)
for dir in "$WORKSPACE_ROOT"/*/*/.git; do
    if [ -d "$dir" ]; then
        parent_dir=$(basename $(dirname $(dirname "$dir")))
        repo_name=$(basename $(dirname "$dir"))
        echo "  • $parent_dir/$repo_name"
        ((REPO_COUNT++))
    fi
done

if [ $REPO_COUNT -eq 0 ]; then
    echo "  ⚠️  No se encontraron repos Git"
    echo ""
    echo "⚠️  ADVERTENCIA: No se detectaron repositorios"
    echo "   Verifica que estés en el directorio correcto"
fi

echo ""
echo "Total: $REPO_COUNT repos detectados"
echo ""

# Crear directorio de workspaces si no existe
WORKSPACES_DIR="$WORKSPACE_ROOT/workspaces"
if [ ! -d "$WORKSPACES_DIR" ]; then
    echo "Creando directorio de workspaces..."
    mkdir -p "$WORKSPACES_DIR"
    echo "✅ Creado: $WORKSPACES_DIR"
else
    echo "✅ Directorio workspaces ya existe"
fi

# Dar permisos de ejecución a los scripts
echo ""
echo "Configurando permisos de ejecución..."
chmod +x "$SCRIPT_DIR/bin/"*
echo "✅ Scripts configurados"

echo ""
echo "════════════════════════════════════════════════════"
echo "✅ Instalación completada"
echo "════════════════════════════════════════════════════"
echo ""

# Mostrar estructura
echo "Estructura instalada:"
echo ""
echo "$WORKSPACE_ROOT/"
echo "├── ks-nuba/                    (repo)"
echo "├── dga-commons/                (repo)"
echo "├── libs/                       (contenedor)"
echo "│   ├── marc4j/                (repo)"
echo "│   └── ..."
echo "├── modules/                    (contenedor)"
echo "│   ├── docs/                  (repo)"
echo "│   └── ..."
echo "├── tools/                      (contenedor)"
echo "│   └── workspace-tools/       (este repo)"
echo "│       ├── bin/               (scripts)"
echo "│       │   ├── ws             (comando unificado)"
echo "│       │   ├── ws-new"
echo "│       │   ├── ws-add"
echo "│       │   ├── ws-list"
echo "│       │   ├── ws-switch"
echo "│       │   └── ws-clean"
echo "│       ├── completions/       (autocompletado)"
echo "│       ├── setup.sh           (configuración)"
echo "│       └── README.md"
echo "└── workspaces/                 (nuevo)"
echo "    ├── master/"
echo "    ├── develop/"
echo "    └── nuba-8400/             (ejemplo)"
echo ""
echo "════════════════════════════════════════════════════"
echo ""
echo "Próximos pasos:"
echo ""
echo "1. Configurar en tu shell (RECOMENDADO):"
echo ""
echo "   Añade esto a tu ~/.bashrc o ~/.zshrc:"
echo ""
cat <<'EOF'
   source ~/wrkspc.nubarchiva/tools/workspace-tools/setup.sh
EOF
echo ""
echo "   Esto configura automáticamente:"
echo "     • Variable WS_TOOLS"
echo "     • Comando 'ws' en el PATH"
echo "     • Función 'ws cd' para cambiar de workspace"
echo "     • Autocompletado (bash o zsh según tu shell)"
echo ""
echo "   Después ejecuta: source ~/.bashrc (o ~/.zshrc)"
echo ""
echo "2. Probar el sistema:"
echo ""
echo "   Con setup.sh cargado podrás usar:"
echo ""
echo "     ws new nuba-8400 ks-nuba libs/marc4j    # crear workspace"
echo "     ws list                                  # listar workspaces"
echo "     ws cd nuba-8400                          # cambiar a workspace"
echo "     ws add nuba-8400 dga-commons             # añadir repo"
echo "     ws clean nuba-8400                       # limpiar workspace"
echo ""
echo "   💡 Soporta abreviaturas:"
echo "     ws n nuba-8400 ks-nuba      # ws new"
echo "     ws ls                        # ws list"
echo "     ws cd nuba-8400              # cambia automáticamente"
echo "     ws rm nuba-8400              # ws clean"
echo ""
echo "   💡 Soporta búsqueda parcial:"
echo "     ws cd nuba       # busca 'nuba' en workspaces"
echo "     ws add fac ...   # busca 'fac' en workspaces"
echo ""
echo "3. O probar sin instalar:"
echo ""
echo "   Desde el directorio tools/workspace-tools:"
echo "     ./bin/ws new test ks-nuba"
echo "     ./bin/ws list"
echo "     ./bin/ws clean test"
echo ""
echo "4. Ver documentación:"
echo "   README.md       - Introducción y uso rápido"
echo "   USER_GUIDE.md   - Referencia completa de comandos"
echo "   NUBARCHIVA.md   - Ejemplos para proyecto nubarchiva"
echo ""
echo "════════════════════════════════════════════════════"
echo ""
echo "¡Listo para empezar! 🚀"
echo ""
