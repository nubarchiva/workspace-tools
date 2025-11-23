#!/bin/bash
# Script de desinstalación para workspace-tools

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

echo "════════════════════════════════════════════════════"
echo "  Workspace Tools - Desinstalación"
echo "════════════════════════════════════════════════════"
echo ""

# Detectar directorio de instalación
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKSPACES_DIR="$WORKSPACE_ROOT/workspaces"

echo -e "${CYAN}📍 Ubicaciones detectadas:${NC}"
echo "   Herramienta: $SCRIPT_DIR"
echo "   Workspaces:  $WORKSPACES_DIR"
echo ""

# =============================================================================
# Verificar workspaces activos
# =============================================================================

check_active_workspaces() {
    if [ ! -d "$WORKSPACES_DIR" ]; then
        return 0
    fi

    local active_count=0
    local workspaces_with_changes=()
    local workspaces_with_commits=()

    for ws_dir in "$WORKSPACES_DIR"/*; do
        [ ! -d "$ws_dir" ] && continue

        local ws_name=$(basename "$ws_dir")
        ((active_count++))

        # Buscar repos en el workspace
        for repo_dir in "$ws_dir"/*/.git "$ws_dir"/*/*/.git; do
            [ ! -e "$repo_dir" ] && continue

            local repo_path=$(dirname "$repo_dir")

            # Verificar cambios sin commitear
            if (cd "$repo_path" && git status --porcelain 2>/dev/null | grep -q .); then
                workspaces_with_changes+=("$ws_name")
                break
            fi

            # Verificar commits sin pushear
            if (cd "$repo_path" && git log @{u}..HEAD 2>/dev/null | grep -q .); then
                workspaces_with_commits+=("$ws_name")
            fi
        done
    done

    if [ $active_count -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Hay $active_count workspace(s) activo(s):${NC}"
        for ws_dir in "$WORKSPACES_DIR"/*; do
            [ -d "$ws_dir" ] && echo "   • $(basename "$ws_dir")"
        done
        echo ""
    fi

    if [ ${#workspaces_with_changes[@]} -gt 0 ]; then
        echo -e "${RED}❌ ATENCIÓN: Workspaces con cambios SIN COMMITEAR:${NC}"
        printf '   • %s\n' "${workspaces_with_changes[@]}"
        echo ""
        echo -e "${BOLD}Estos cambios se PERDERÁN si continúas.${NC}"
        echo ""
    fi

    if [ ${#workspaces_with_commits[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Workspaces con commits sin pushear:${NC}"
        printf '   • %s\n' "${workspaces_with_commits[@]}"
        echo ""
    fi

    return $active_count
}

# =============================================================================
# Menú de opciones
# =============================================================================

show_menu() {
    echo "¿Qué quieres hacer?"
    echo ""
    echo "  1) ${BOLD}Desinstalar completamente${NC}"
    echo "     - Elimina workspaces (¡CUIDADO con cambios no guardados!)"
    echo "     - Elimina directorio workspace-tools"
    echo ""
    echo "  2) ${BOLD}Desinstalar solo herramientas${NC} (recomendado)"
    echo "     - Mantiene workspaces existentes"
    echo "     - Elimina solo scripts y configuración"
    echo ""
    echo "  3) ${BOLD}Solo limpiar workspaces${NC}"
    echo "     - Elimina todos los workspaces"
    echo "     - Mantiene herramientas instaladas"
    echo ""
    echo "  4) ${BOLD}Mostrar instrucciones manuales${NC}"
    echo "     - No hace cambios"
    echo "     - Muestra qué limpiar manualmente"
    echo ""
    echo "  0) Cancelar"
    echo ""
}

# =============================================================================
# Funciones de desinstalación
# =============================================================================

remove_workspaces() {
    if [ ! -d "$WORKSPACES_DIR" ]; then
        echo "No hay directorio de workspaces"
        return 0
    fi

    local ws_count=0
    for ws_dir in "$WORKSPACES_DIR"/*; do
        [ -d "$ws_dir" ] && ((ws_count++))
    done

    if [ $ws_count -eq 0 ]; then
        echo "No hay workspaces para eliminar"
        return 0
    fi

    echo ""
    echo -e "${RED}⚠️  ADVERTENCIA: Esto eliminará $ws_count workspace(s)${NC}"
    echo ""
    echo -n "Escribe 'ELIMINAR' para confirmar: "
    read -r confirm

    if [ "$confirm" != "ELIMINAR" ]; then
        echo "Cancelado"
        return 1
    fi

    echo ""
    echo "Eliminando workspaces..."

    # Primero, limpiar worktrees de Git para cada repo
    for ws_dir in "$WORKSPACES_DIR"/*; do
        [ ! -d "$ws_dir" ] && continue

        local ws_name=$(basename "$ws_dir")
        echo "  Limpiando: $ws_name"

        # Buscar repos y eliminar worktrees
        for repo_dir in "$ws_dir"/*/.git "$ws_dir"/*/*/.git; do
            [ ! -e "$repo_dir" ] && continue
            [ ! -f "$repo_dir" ] && continue  # Solo archivos .git (worktrees)

            local worktree_path=$(dirname "$repo_dir")
            local main_repo=$(grep "gitdir:" "$repo_dir" 2>/dev/null | cut -d' ' -f2 | sed 's|/\.git/worktrees/.*||')

            if [ -d "$main_repo" ]; then
                (cd "$main_repo" && git worktree remove "$worktree_path" --force 2>/dev/null) || true
            fi
        done
    done

    # Eliminar directorio de workspaces
    rm -rf "$WORKSPACES_DIR"
    echo -e "${GREEN}✅ Workspaces eliminados${NC}"
}

remove_shell_config() {
    echo ""
    echo "Revisando configuración de shell..."

    local shell_files=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile")
    local found_config=0

    for shell_file in "${shell_files[@]}"; do
        if [ -f "$shell_file" ] && grep -q "workspace-tools/setup.sh" "$shell_file"; then
            found_config=1
            echo -e "${YELLOW}  Encontrado en: $shell_file${NC}"
        fi
    done

    if [ $found_config -eq 1 ]; then
        echo ""
        echo "Para completar la desinstalación, elimina manualmente la línea:"
        echo ""
        echo -e "  ${CYAN}source .../workspace-tools/setup.sh${NC}"
        echo ""
        echo "de tu archivo de configuración de shell."
    else
        echo "  No se encontró configuración de shell"
    fi
}

remove_wsrc() {
    if [ -f "$HOME/.wsrc" ]; then
        echo ""
        echo -n "¿Eliminar archivo de configuración ~/.wsrc? [y/N]: "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            rm "$HOME/.wsrc"
            echo -e "${GREEN}✅ ~/.wsrc eliminado${NC}"
        fi
    fi
}

remove_templates() {
    local templates_file="$WORKSPACE_ROOT/.ws-templates"
    if [ -f "$templates_file" ]; then
        echo ""
        echo -n "¿Eliminar archivo de templates .ws-templates? [y/N]: "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            rm "$templates_file"
            echo -e "${GREEN}✅ .ws-templates eliminado${NC}"
        fi
    fi
}

show_manual_instructions() {
    echo ""
    echo "════════════════════════════════════════════════════"
    echo "  Instrucciones de desinstalación manual"
    echo "════════════════════════════════════════════════════"
    echo ""
    echo "1. Eliminar línea de shell config (~/.bashrc o ~/.zshrc):"
    echo ""
    echo -e "   ${CYAN}source .../workspace-tools/setup.sh${NC}"
    echo ""
    echo "2. Eliminar directorio de herramientas:"
    echo ""
    echo -e "   ${CYAN}rm -rf $SCRIPT_DIR${NC}"
    echo ""
    echo "3. Eliminar workspaces (opcional):"
    echo ""
    echo -e "   ${CYAN}rm -rf $WORKSPACES_DIR${NC}"
    echo ""
    echo "4. Eliminar configuración (opcional):"
    echo ""
    echo -e "   ${CYAN}rm ~/.wsrc${NC}"
    echo -e "   ${CYAN}rm $WORKSPACE_ROOT/.ws-templates${NC}"
    echo ""
    echo "5. Limpiar worktrees huérfanos en repos:"
    echo ""
    echo -e "   ${CYAN}cd <repo> && git worktree prune${NC}"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

check_active_workspaces
active_ws=$?

show_menu

echo -n "Opción [0-4]: "
read -r option

case "$option" in
    1)
        echo ""
        echo -e "${RED}═══════════════════════════════════════════════════${NC}"
        echo -e "${RED}  DESINSTALACIÓN COMPLETA${NC}"
        echo -e "${RED}═══════════════════════════════════════════════════${NC}"

        if [ $active_ws -gt 0 ]; then
            echo ""
            echo -e "${RED}¡HAY WORKSPACES ACTIVOS! Verifica que no tienes trabajo sin guardar.${NC}"
        fi

        remove_workspaces || exit 1
        remove_wsrc
        remove_templates
        remove_shell_config

        echo ""
        echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  Desinstalación completada${NC}"
        echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
        echo ""
        echo "Para eliminar completamente la herramienta:"
        echo -e "  ${CYAN}rm -rf $SCRIPT_DIR${NC}"
        echo ""
        ;;

    2)
        echo ""
        echo "═══════════════════════════════════════════════════"
        echo "  DESINSTALAR SOLO HERRAMIENTAS"
        echo "═══════════════════════════════════════════════════"

        remove_wsrc
        remove_templates
        remove_shell_config

        echo ""
        echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  Herramientas desconfiguradas${NC}"
        echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
        echo ""
        echo "Workspaces mantenidos en: $WORKSPACES_DIR"
        echo ""
        echo "Para eliminar la herramienta:"
        echo -e "  ${CYAN}rm -rf $SCRIPT_DIR${NC}"
        echo ""
        ;;

    3)
        echo ""
        echo "═══════════════════════════════════════════════════"
        echo "  LIMPIAR SOLO WORKSPACES"
        echo "═══════════════════════════════════════════════════"

        remove_workspaces
        ;;

    4)
        show_manual_instructions
        ;;

    0|"")
        echo ""
        echo "Cancelado"
        exit 0
        ;;

    *)
        echo "Opción no válida"
        exit 1
        ;;
esac
