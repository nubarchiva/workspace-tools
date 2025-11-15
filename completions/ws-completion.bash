#!/bin/bash
# Bash completion script for ws command

_ws_completion() {
    local cur prev words cword
    _init_completion || return

    # Detectar WORKSPACE_ROOT
    local workspace_root="${WS_TOOLS%/tools/workspace-tools}"
    if [ -z "$workspace_root" ]; then
        workspace_root=~/wrkspc.nubarchiva
    fi
    local workspaces_dir="$workspace_root/workspaces"

    # Subcomandos disponibles
    local subcommands="new add switch list clean help"

    # Posición actual en el comando
    case $cword in
        1)
            # Completar subcomandos
            COMPREPLY=($(compgen -W "$subcommands" -- "$cur"))
            ;;
        2)
            # Después del subcomando
            case ${words[1]} in
                new)
                    # Para 'new', el usuario proporciona el nombre
                    # Podríamos sugerir master/develop
                    COMPREPLY=($(compgen -W "master develop" -- "$cur"))
                    ;;
                add|switch|clean)
                    # Completar nombre de workspace existente
                    local workspaces=""
                    if [ -d "$workspaces_dir" ]; then
                        workspaces=$(cd "$workspaces_dir" && ls -d */ 2>/dev/null | sed 's|/||')
                    fi
                    COMPREPLY=($(compgen -W "$workspaces" -- "$cur"))
                    ;;
                list|help)
                    # No hay más argumentos
                    ;;
            esac
            ;;
        *)
            # Argumentos adicionales (repos)
            case ${words[1]} in
                new|add)
                    # Completar nombres de repos disponibles
                    local repos=""

                    # Repos en raíz
                    if [ -d "$workspace_root" ]; then
                        for dir in "$workspace_root"/*/.git; do
                            if [ -d "$dir" ]; then
                                local repo_name=$(basename $(dirname "$dir"))
                                if [ "$repo_name" != "workspaces" ]; then
                                    repos="$repos $repo_name"
                                fi
                            fi
                        done

                        # Repos en subdirectorios (libs/*, modules/*, tools/*)
                        for dir in "$workspace_root"/*/*/.git; do
                            if [ -d "$dir" ]; then
                                local parent_dir=$(basename $(dirname $(dirname "$dir")))
                                local repo_name=$(basename $(dirname "$dir"))
                                repos="$repos $parent_dir/$repo_name"
                            fi
                        done
                    fi

                    COMPREPLY=($(compgen -W "$repos" -- "$cur"))
                    ;;
            esac
            ;;
    esac
}

# Registrar la función de completado
complete -F _ws_completion ws
