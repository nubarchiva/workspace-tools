#!/bin/bash
# Script de instalación para workspace-tools

echo "════════════════════════════════════════════════════"
echo "  Workspace Tools - Instalación"
echo "  Versión 2.1"
echo "════════════════════════════════════════════════════"
echo ""

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
echo "   README.md       - Guía completa"
echo "   QUICKSTART.md   - Inicio rápido"
echo "   CHEATSHEET.md   - Referencia rápida"
echo "   EJEMPLOS.md     - Casos de uso prácticos"
echo ""
echo "════════════════════════════════════════════════════"
echo ""
echo "¡Listo para empezar! 🚀"
echo ""
