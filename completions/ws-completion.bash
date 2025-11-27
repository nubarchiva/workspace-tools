#!/bin/bash
# Bash completion script for ws command

_ws_completion() {
    local cur prev words cword
    _init_completion || return

    # Detectar WORKSPACE_ROOT
    local workspace_root="${WORKSPACE_ROOT:-${WS_TOOLS%/tools/workspace-tools}}"
    if [ -z "$workspace_root" ]; then
        workspace_root=~/wrkspc.nubarchiva
    fi
    local workspaces_dir="${WORKSPACES_DIR:-$workspace_root/workspaces}"

    # Subcomandos disponibles (incluyendo aliases)
    local subcommands="new add remove switch list clean mvn git update stash grep templates status rename info origins help"
    local aliases="ls cd rm mv st tpl"

    # Función para obtener workspaces
    _get_workspaces() {
        if [ -d "$workspaces_dir" ]; then
            cd "$workspaces_dir" && ls -d */ 2>/dev/null | sed 's|/||'
        fi
    }

    # Función para obtener repos
    _get_repos() {
        local repos=""
        if [ -d "$workspace_root" ]; then
            # Repos en raíz
            for dir in "$workspace_root"/*/.git; do
                if [ -d "$dir" ]; then
                    local repo_name=$(basename "$(dirname "$dir")")
                    if [ "$repo_name" != "workspaces" ]; then
                        repos="$repos $repo_name"
                    fi
                fi
            done
            # Repos en subdirectorios
            for dir in "$workspace_root"/*/*/.git; do
                if [ -d "$dir" ]; then
                    local parent_dir=$(basename "$(dirname "$(dirname "$dir")")")
                    local repo_name=$(basename "$(dirname "$dir")")
                    repos="$repos $parent_dir/$repo_name"
                fi
            done
        fi
        echo "$repos"
    }

    # Función para obtener templates
    _get_templates() {
        local templates_file="$workspace_root/.ws-templates"
        if [ -f "$templates_file" ]; then
            cut -d':' -f1 "$templates_file" 2>/dev/null
        fi
    }

    # Posición actual en el comando
    case $cword in
        1)
            # Completar subcomandos y aliases
            COMPREPLY=($(compgen -W "$subcommands $aliases" -- "$cur"))
            ;;
        2)
            # Después del subcomando
            case ${words[1]} in
                new|mk|create)
                    # Sugerir master/develop o --template
                    COMPREPLY=($(compgen -W "master develop --template -t" -- "$cur"))
                    ;;
                add|a|switch|cd|sw|clean|rm|del|remove|status|st|.|here|rename|mv|info)
                    # Completar nombre de workspace existente
                    local workspaces=$(_get_workspaces)
                    COMPREPLY=($(compgen -W "$workspaces" -- "$cur"))
                    ;;
                mvn|git)
                    # Completar workspace o auto-detectar
                    local workspaces=$(_get_workspaces)
                    COMPREPLY=($(compgen -W "$workspaces" -- "$cur"))
                    ;;
                update)
                    # Workspace o opciones
                    local workspaces=$(_get_workspaces)
                    COMPREPLY=($(compgen -W "$workspaces --rebase -r --from -f" -- "$cur"))
                    ;;
                stash)
                    # Acciones de stash
                    COMPREPLY=($(compgen -W "push pop list clear show" -- "$cur"))
                    ;;
                grep)
                    # Patrón (el usuario escribe)
                    ;;
                templates|tpl)
                    # Acciones de templates
                    COMPREPLY=($(compgen -W "list add show remove" -- "$cur"))
                    ;;
                origins)
                    # Subcomandos de origins
                    COMPREPLY=($(compgen -W "git list" -- "$cur"))
                    ;;
                list|ls)
                    # Filtro opcional (workspaces existentes)
                    local workspaces=$(_get_workspaces)
                    COMPREPLY=($(compgen -W "$workspaces" -- "$cur"))
                    ;;
                help|h|--help|-h)
                    # Sin argumentos
                    ;;
            esac
            ;;
        3)
            # Tercer argumento
            case ${words[1]} in
                new|mk|create)
                    if [[ "${words[2]}" == "--template" || "${words[2]}" == "-t" ]]; then
                        # Completar templates
                        local templates=$(_get_templates)
                        COMPREPLY=($(compgen -W "$templates" -- "$cur"))
                    else
                        # Repos
                        local repos=$(_get_repos)
                        COMPREPLY=($(compgen -W "$repos --template -t" -- "$cur"))
                    fi
                    ;;
                add|a)
                    # Repos
                    local repos=$(_get_repos)
                    COMPREPLY=($(compgen -W "$repos" -- "$cur"))
                    ;;
                remove)
                    # Repos del workspace (simplificado: todos los repos)
                    local repos=$(_get_repos)
                    COMPREPLY=($(compgen -W "$repos" -- "$cur"))
                    ;;
                rename|mv)
                    # Nuevo nombre (el usuario escribe)
                    ;;
                mvn)
                    # Argumentos Maven comunes
                    COMPREPLY=($(compgen -W "clean install test package compile -DskipTests" -- "$cur"))
                    ;;
                git)
                    # Comandos Git comunes
                    COMPREPLY=($(compgen -W "status pull push fetch log diff checkout branch" -- "$cur"))
                    ;;
                update)
                    # Opciones
                    COMPREPLY=($(compgen -W "--rebase -r --from -f" -- "$cur"))
                    ;;
                stash)
                    # Workspace o mensaje
                    local workspaces=$(_get_workspaces)
                    COMPREPLY=($(compgen -W "$workspaces" -- "$cur"))
                    ;;
                grep)
                    # Workspace u opciones
                    local workspaces=$(_get_workspaces)
                    COMPREPLY=($(compgen -W "$workspaces -i -l -n -w -E --type" -- "$cur"))
                    ;;
                templates|tpl)
                    case ${words[2]} in
                        show|remove)
                            local templates=$(_get_templates)
                            COMPREPLY=($(compgen -W "$templates" -- "$cur"))
                            ;;
                        add)
                            # Nombre del template (el usuario escribe)
                            ;;
                    esac
                    ;;
                origins)
                    if [[ "${words[2]}" == "git" ]]; then
                        # Comandos Git comunes
                        COMPREPLY=($(compgen -W "status pull push fetch log diff" -- "$cur"))
                    fi
                    ;;
            esac
            ;;
        *)
            # Argumentos adicionales
            case ${words[1]} in
                new|mk|create|add|a)
                    # Repos adicionales
                    local repos=$(_get_repos)
                    COMPREPLY=($(compgen -W "$repos" -- "$cur"))
                    ;;
                templates|tpl)
                    if [[ "${words[2]}" == "add" ]]; then
                        # Repos para el template
                        local repos=$(_get_repos)
                        COMPREPLY=($(compgen -W "$repos" -- "$cur"))
                    fi
                    ;;
                grep)
                    # Opciones de grep
                    COMPREPLY=($(compgen -W "-i -l -n -w -E --type" -- "$cur"))
                    ;;
            esac
            ;;
    esac
}

# Registrar la función de completado
complete -F _ws_completion ws
