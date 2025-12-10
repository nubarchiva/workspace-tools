#compdef ws
# Zsh completion script for ws command

_ws() {
    local -a subcommands workspaces repos templates

    # Detectar WORKSPACE_ROOT
    local workspace_root="${WORKSPACE_ROOT:-${WS_TOOLS%/tools/workspace-tools}}"
    if [[ -z "$workspace_root" ]]; then
        workspace_root=~/wrkspc.nubarchiva
    fi
    local workspaces_dir="${WORKSPACES_DIR:-$workspace_root/workspaces}"

    # Subcomandos disponibles con descripciones
    subcommands=(
        'new:Crea un nuevo workspace'
        'add:Añade repos a un workspace existente'
        'remove:Elimina repos de un workspace'
        'switch:Cambia a un workspace y muestra su información'
        'list:Lista todos los workspaces activos'
        'clean:Elimina un workspace completo'
        'mvn:Ejecuta Maven en todos los repos'
        'git:Ejecuta Git en todos los repos'
        'update:Actualiza con develop (merge/rebase)'
        'stash:Gestiona stash coordinado'
        'grep:Busca texto en todos los repos'
        'templates:Gestiona templates de repos'
        'status:Muestra estado del workspace actual'
        'rename:Renombra un workspace'
        'info:Muestra información del workspace'
        'origins:Operaciones en repos origen'
        'mode:Gestiona modo online/offline'
        'help:Muestra ayuda'
        # Aliases
        'ls:Alias de list'
        'cd:Alias de switch'
        'rm:Alias de clean'
        'mv:Alias de rename'
        'st:Alias de status'
        'tpl:Alias de templates'
    )

    # Función para obtener workspaces disponibles
    _get_workspaces() {
        local -a workspaces=()
        if [[ -d "$workspaces_dir" ]]; then
            for workspace_dir in "$workspaces_dir"/*(/N); do
                local ws_name=${workspace_dir:t}
                local branch="feature/$ws_name"
                [[ "$ws_name" == "master" ]] && branch="master"
                [[ "$ws_name" == "develop" ]] && branch="develop"
                workspaces+=("$ws_name:branch $branch")
            done
        fi
        _describe 'workspaces' workspaces
    }

    # Función para obtener repos disponibles
    _get_repos() {
        local -a repos=()

        # Repos en raíz
        for dir in "$workspace_root"/*/.git(N); do
            local repo_name=${dir:h:t}
            [[ "$repo_name" != "workspaces" ]] && repos+=("$repo_name:Repo en raíz")
        done

        # Repos en subdirectorios
        for dir in "$workspace_root"/*/*/.git(N); do
            local parent_dir=${dir:h:h:t}
            local repo_name=${dir:h:t}
            repos+=("$parent_dir/$repo_name:Repo en $parent_dir/")
        done

        _describe 'repos' repos
    }

    # Función para obtener templates
    _get_templates() {
        local -a templates=()
        local templates_file="$workspace_root/.ws-templates"
        if [[ -f "$templates_file" ]]; then
            while IFS=: read -r name repos_list; do
                [[ -n "$name" ]] && templates+=("$name:$repos_list")
            done < "$templates_file"
        fi
        _describe 'templates' templates
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
                new|mk|create)
                    _alternative \
                        'special:special names:((master\:"branch master" develop\:"branch develop"))' \
                        'options:options:((--template\:"-t Usar template" -t\:"Usar template"))' \
                        'name:workspace name:'
                    ;;
                add|a|switch|cd|sw|clean|rm|del|remove|status|st|rename|mv|info)
                    _get_workspaces
                    ;;
                mvn|git)
                    _get_workspaces
                    ;;
                update)
                    _alternative \
                        'workspaces:workspace:_get_workspaces' \
                        'options:options:((--rebase\:"-r Usar rebase" -r\:"Usar rebase" --from\:"-f Branch base" -f\:"Branch base"))'
                    ;;
                stash)
                    local -a stash_actions=(
                        'push:Guardar cambios'
                        'pop:Restaurar cambios'
                        'list:Listar stashes'
                        'clear:Eliminar todos'
                        'show:Mostrar contenido'
                    )
                    _describe 'stash actions' stash_actions
                    ;;
                grep)
                    # El usuario escribe el patrón
                    ;;
                templates|tpl)
                    local -a tpl_actions=(
                        'list:Listar templates'
                        'add:Crear template'
                        'show:Mostrar template'
                        'remove:Eliminar template'
                    )
                    _describe 'template actions' tpl_actions
                    ;;
                origins)
                    local -a origins_actions=(
                        'git:Ejecutar git en repos origen'
                        'list:Listar repos origen'
                    )
                    _describe 'origins actions' origins_actions
                    ;;
                list|ls)
                    # Filtro opcional
                    _get_workspaces
                    ;;
                mode)
                    local -a mode_opts=(
                        'offline:Forzar modo sin conexión'
                        'online:Modo normal (auto-detecta)'
                    )
                    _describe 'mode options' mode_opts
                    ;;
            esac
            ;;
        4)
            # Tercer argumento
            case $words[2] in
                new|mk|create)
                    if [[ "$words[3]" == "--template" || "$words[3]" == "-t" ]]; then
                        _get_templates
                    else
                        _alternative \
                            'repos:repo:_get_repos' \
                            'options:options:((--template\:"-t Usar template" -t\:"Usar template"))'
                    fi
                    ;;
                add|a|remove)
                    _get_repos
                    ;;
                rename|mv)
                    # Nuevo nombre (el usuario escribe)
                    ;;
                mvn)
                    local -a mvn_goals=(
                        'clean:Limpiar'
                        'install:Instalar'
                        'test:Tests'
                        'package:Empaquetar'
                        'compile:Compilar'
                        '-DskipTests:Sin tests'
                    )
                    _describe 'maven goals' mvn_goals
                    ;;
                git)
                    local -a git_cmds=(
                        'status:Estado'
                        'pull:Descargar'
                        'push:Subir'
                        'fetch:Fetch'
                        'log:Historial'
                        'diff:Diferencias'
                        'checkout:Cambiar branch'
                        'branch:Branches'
                    )
                    _describe 'git commands' git_cmds
                    ;;
                update)
                    local -a update_opts=(
                        '--rebase:Usar rebase'
                        '-r:Usar rebase'
                        '--from:Branch base'
                        '-f:Branch base'
                    )
                    _describe 'update options' update_opts
                    ;;
                stash)
                    _get_workspaces
                    ;;
                grep)
                    _alternative \
                        'workspaces:workspace:_get_workspaces' \
                        'options:options:((-i\:"Case insensitive" -l\:"Solo archivos" -n\:"Números de línea" --type\:"Tipo de archivo"))'
                    ;;
                templates|tpl)
                    case $words[3] in
                        show|remove)
                            _get_templates
                            ;;
                        add)
                            # Nombre del template (el usuario escribe)
                            ;;
                    esac
                    ;;
                origins)
                    if [[ "$words[3]" == "git" ]]; then
                        local -a git_cmds=(
                            'status:Estado'
                            'pull:Descargar'
                            'push:Subir'
                            'fetch:Fetch'
                            'log:Historial'
                            'diff:Diferencias'
                        )
                        _describe 'git commands' git_cmds
                    fi
                    ;;
            esac
            ;;
        *)
            # Argumentos adicionales
            case $words[2] in
                new|mk|create|add|a)
                    _get_repos
                    ;;
                templates|tpl)
                    if [[ "$words[3]" == "add" ]]; then
                        _get_repos
                    fi
                    ;;
                grep)
                    local -a grep_opts=(
                        '-i:Case insensitive'
                        '-l:Solo archivos'
                        '-n:Números de línea'
                        '-w:Palabra completa'
                        '-E:Regex extendida'
                        '--type:Tipo de archivo'
                    )
                    _describe 'grep options' grep_opts
                    ;;
            esac
            ;;
    esac
}

# Registrar la función de completado
compdef _ws ws
