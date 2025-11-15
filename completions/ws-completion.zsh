#compdef ws
# Zsh completion script for ws command

_ws() {
    local -a subcommands workspace_types features repos
    
    # Detectar WORKSPACE_ROOT
    local workspace_root="${WS_TOOLS%/tools/workspace-tools}"
    if [[ -z "$workspace_root" ]]; then
        workspace_root=~/wrkspc.nubarchiva
    fi
    local workspaces_dir="$workspace_root/workspaces"
    
    # Subcomandos disponibles
    subcommands=(
        'new:Crear un nuevo workspace'
        'add:Añadir un repo a un workspace existente'
        'switch:Cambiar a un workspace y mostrar su información'
        'list:Listar todos los workspaces activos'
        'clean:Limpiar un workspace'
        'help:Mostrar ayuda'
    )
    
    # Tipos de workspace
    workspace_types=(
        'feature:Workspace para desarrollo de features'
        'master:Workspace para master'
        'develop:Workspace para develop'
    )
    
    # Función para obtener features disponibles
    _get_features() {
        local features=()
        if [[ -d "$workspaces_dir/features" ]]; then
            for feature_dir in "$workspaces_dir/features"/*(/N); do
                features+=($(basename "$feature_dir"))
            done
        fi
        _describe 'features' features
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
                new|add|switch|clean)
                    # Completar tipo de workspace
                    _describe 'workspace types' workspace_types
                    ;;
            esac
            ;;
        4)
            # Después del tipo de workspace
            case $words[2] in
                new)
                    # Para 'new', el usuario proporciona el nombre
                    _message 'nombre del workspace'
                    ;;
                add|switch|clean)
                    # Completar nombre de feature existente (para feature)
                    if [[ "$words[3]" == "feature" ]]; then
                        _get_features
                    fi
                    ;;
            esac
            ;;
        *)
            # Argumentos adicionales (repos)
            case $words[2] in
                new)
                    # Para 'new', después del nombre vienen los repos
                    if [[ "$words[3]" == "feature" ]] || [[ "$words[3]" == "master" ]] || [[ "$words[3]" == "develop" ]]; then
                        _get_repos
                    fi
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
