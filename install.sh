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
    mkdir -p "$WORKSPACES_DIR/features"
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
echo "│       │   ├── ws-new"
echo "│       │   ├── ws-add"
echo "│       │   ├── ws-list"
echo "│       │   ├── ws-switch"
echo "│       │   └── ws-clean"
echo "│       └── README.md"
echo "└── workspaces/                 (nuevo)"
echo "    ├── master/"
echo "    ├── develop/"
echo "    └── features/"
echo ""
echo "════════════════════════════════════════════════════"
echo ""
echo "Próximos pasos:"
echo ""
echo "1. Probar los scripts directamente:"
echo "   cd $SCRIPT_DIR"
echo "   ./bin/ws-new feature test ks-nuba"
echo "   ./bin/ws-list"
echo "   ./bin/ws-clean feature test"
echo ""
echo "2. O configurar alias (RECOMENDADO):"
echo ""
echo "   Añade esto a tu ~/.bashrc o ~/.zshrc:"
echo ""
cat <<'EOF'
   # Workspace Tools
   export WS_TOOLS=~/wrkspc.nubarchiva/tools/workspace-tools
   
   # Comando principal (recomendado)
   alias ws='$WS_TOOLS/bin/ws'

   # Navegación rápida
   alias wscd='cd ~/wrkspc.nubarchiva'
   alias wsf='cd ~/wrkspc.nubarchiva/workspaces/features'

   # Comandos individuales (opcional, para compatibilidad)
   alias ws-new='$WS_TOOLS/bin/ws-new'
   alias ws-add='$WS_TOOLS/bin/ws-add'
   alias ws-list='$WS_TOOLS/bin/ws-list'
   alias ws-switch='$WS_TOOLS/bin/ws-switch'
   alias ws-clean='$WS_TOOLS/bin/ws-clean'
EOF
echo ""
echo "   OPCIONAL - Habilitar autocompletado (recomendado):"
echo ""
echo "   Para Bash, añade:"
echo "     source \$WS_TOOLS/completions/ws-completion.bash"
echo ""
echo "   Para Zsh, añade:"
echo "     source \$WS_TOOLS/completions/ws-completion.zsh"
echo ""
echo "   Después ejecuta: source ~/.bashrc (o ~/.zshrc)"
echo ""
echo "   Con los alias configurados podrás usar desde cualquier lugar:"
echo "     ws new feature test ks-nuba libs/marc4j"
echo "     ws list"
echo "     ws switch feature test"
echo ""
echo "   O con los comandos individuales:"
echo "     ws-new feature test ks-nuba libs/marc4j"
echo "     ws-list"
echo "     ws-switch feature test"
echo ""
echo "3. Ver documentación:"
echo "   README.md      - Guía completa"
echo "   EJEMPLOS.md    - Casos de uso prácticos"
echo "   CHEATSHEET.md  - Referencia rápida"
echo ""
echo "════════════════════════════════════════════════════"
echo ""
echo "¡Listo para empezar! 🚀"
echo ""
echo "Primeros comandos de prueba:"
echo "  ./bin/ws new feature test ks-nuba    # comando unificado"
echo "  ./bin/ws list                        # listar workspaces"
echo "  ./bin/ws help                        # ver ayuda"
