#compdef ws
# Zsh completion script for ws command

_ws() {
    local -a subcommands workspaces repos

    # Detectar WORKSPACE_ROOT
    local workspace_root="${WS_TOOLS%/tools/workspace-tools}"
    if [[ -z "$workspace_root" ]]; then
        workspace_root=~/wrkspc.nubarchiva
    fi
    local workspaces_dir="$workspace_root/workspaces"

    # Subcomandos disponibles
    subcommands=(
        'new:Crea un nuevo workspace'
        'add:Añade un repo a un workspace existente'
        'switch:Cambia a un workspace y muestra su información'
        'list:Lista todos los workspaces activos'
        'clean:Limpia un workspace'
        'help:Muestra ayuda'
    )

    # Función para obtener workspaces disponibles
    _get_workspaces() {
        local workspaces=()
        if [[ -d "$workspaces_dir" ]]; then
            for workspace_dir in "$workspaces_dir"/*(/N); do
                local ws_name=$(basename "$workspace_dir")
                local branch="master"
                if [[ "$ws_name" == "master" ]]; then
                    branch="master"
                elif [[ "$ws_name" == "develop" ]]; then
                    branch="develop"
                else
                    branch="feature/$ws_name"
                fi
                workspaces+=("$ws_name:branch $branch")
            done
        fi
        _describe 'workspaces' workspaces
    }

    # Función para obtener repos disponibles
    _get_repos() {
        local repos=()

        # Repos en raíz
        for dir in "$workspace_root"/*/.git(N); do
            local repo_name=$(basename $(dirname "$dir"))
            if [[ "$repo_name" != "workspaces" ]]; then
                repos+=("$repo_name:Repo en raíz")
            fi
        done

        # Repos en subdirectorios (libs/*, modules/*, tools/*)
        for dir in "$workspace_root"/*/*/.git(N); do
            local parent_dir=$(basename $(dirname $(dirname "$dir")))
            local repo_name=$(basename $(dirname "$dir"))
            repos+=("$parent_dir/$repo_name:Repo en $parent_dir/")
        done

        _describe 'repos' repos
    }

    # Lógica de completado según posición
    case $CURRENT in
        2)
            # Completar subcomandos
            _describe 'subcommands' subcommands
            ;;
        3)
            # Después del subcomando
            case $words[2] in
                new)
                    # Para 'new', sugerir master/develop o permitir nombre libre
                    _alternative \
                        'special:special names:((master\:"branch master" develop\:"branch develop"))' \
                        'name:workspace name:'
                    ;;
                add|switch|clean)
                    # Completar nombre de workspace existente
                    _get_workspaces
                    ;;
            esac
            ;;
        *)
            # Argumentos adicionales (repos)
            case $words[2] in
                new)
                    # Para 'new', después del nombre vienen los repos
                    _get_repos
                    ;;
                add)
                    # Para 'add', el último argumento es el repo
                    _get_repos
                    ;;
            esac
            ;;
    esac
}

_ws "$@"
