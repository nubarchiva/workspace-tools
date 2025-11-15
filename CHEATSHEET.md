# Workspace Tools - Cheatsheet v2.0

## Comandos Rápidos

### Crear Workspaces
```bash
# Feature con repos en raíz
./tools/new-workspace.sh feature <nombre> ks-nuba dga-commons

# Feature con repos en subdirectorios
./tools/new-workspace.sh feature <nombre> libs/marc4j modules/docs

# Feature mezclando niveles
./tools/new-workspace.sh feature <nombre> ks-nuba libs/marc4j modules/docs

# Master/Develop
./tools/new-workspace.sh master ks-nuba libs/dspace
./tools/new-workspace.sh develop ks-nuba libs/marc4j modules/docs

# Workspace vacío (añadir repos después)
./tools/new-workspace.sh feature <nombre>
```

### Añadir Repos
```bash
# Añadir repo en raíz
./tools/add-repo.sh feature <nombre> ks-nuba

# Añadir repo en subdirectorio
./tools/add-repo.sh feature <nombre> libs/marc4j
./tools/add-repo.sh feature <nombre> modules/docs

# Añadir a master/develop
./tools/add-repo.sh master libs/dspace
./tools/add-repo.sh develop modules/metadata-entities
```

### Listar y Ver
```bash
# Listar todos los workspaces
./tools/list-workspaces.sh

# Ver workspaces disponibles
./tools/switch-workspace.sh

# Ver detalle de workspace
./tools/switch-workspace.sh feature <nombre>
./tools/switch-workspace.sh master
```

### Limpiar
```bash
# Limpiar feature
./tools/cleanup-workspace.sh feature <nombre>

# Limpiar master/develop
./tools/cleanup-workspace.sh master
./tools/cleanup-workspace.sh develop
```

## Estructura de Directorios

```
~/wrkspc.nubarchiva/
├── ks-nuba/                 # Repo en raíz
├── dga-commons/             # Repo en raíz
├── libs/                    # Contenedor
│   ├── dspace/             # Repo
│   ├── marc4j/             # Repo
│   └── foo-commonj/        # Repo
├── modules/                 # Contenedor
│   ├── docs/               # Repo
│   ├── metadata-entities/  # Repo
│   └── diffusion-portal/   # Repo
└── workspaces/
    ├── master/
    ├── develop/
    └── features/
        └── mi-feature/
            ├── ks-nuba/           # Worktree
            ├── libs/
            │   └── marc4j/       # Worktree
            └── modules/
                └── docs/          # Worktree
```

## Especificar Repos

### Siempre Usa Rutas Relativas desde la Raíz

```bash
# ✅ Correcto
./tools/new-workspace.sh feature test libs/marc4j
./tools/add-repo.sh feature test modules/docs

# ❌ Incorrecto
./tools/new-workspace.sh feature test marc4j      # Falta "libs/"
./tools/add-repo.sh feature test docs              # Falta "modules/"
```

## Workflows Típicos

### Feature con Múltiples Niveles
```bash
# 1. Crear
./tools/new-workspace.sh feature full ks-nuba libs/marc4j modules/docs

# 2. Trabajar
cd workspaces/features/full
claude-code .

# 3. Commits
cd ks-nuba && git commit -am "feat: main changes"
cd ../libs/marc4j && git commit -am "feat: lib changes"
cd ../../modules/docs && git commit -am "docs: update"

# 4. Limpiar
cd ~/wrkspc.nubarchiva
./tools/cleanup-workspace.sh feature full
```

### Añadir Repos Dinámicamente
```bash
# Empezar con uno
./tools/new-workspace.sh feature dynamic ks-nuba

# Añadir según necesites
./tools/add-repo.sh feature dynamic libs/marc4j
./tools/add-repo.sh feature dynamic modules/docs

# Ver qué tienes
./tools/switch-workspace.sh feature dynamic
```

### Hotfix en Librería
```bash
# Solo la librería
./tools/new-workspace.sh master libs/marc4j

cd workspaces/master/libs/marc4j
# fix, commit, push

cd ~/wrkspc.nubarchiva
./tools/cleanup-workspace.sh master ""
```

## Patrones Comunes

```bash
# Código principal + una lib
./tools/new-workspace.sh feature name ks-nuba libs/marc4j

# Solo librerías
./tools/new-workspace.sh feature libs-only libs/lib1 libs/lib2

# Solo módulos
./tools/new-workspace.sh feature mods-only modules/mod1 modules/mod2

# Todo mezclado
./tools/new-workspace.sh feature full ks-nuba libs/lib1 modules/mod1
```

## Navegación

```bash
# Ir al workspace
cd ~/wrkspc.nubarchiva/workspaces/features/mi-feature

# Ver estructura
tree -L 2

# Ir a repo en subdirectorio
cd libs/marc4j
# o
cd modules/docs

# Volver a raíz del workspace
cd ~/wrkspc.nubarchiva/workspaces/features/mi-feature
```

## Git Operations

### Status de Todos los Repos
```bash
cd workspaces/features/mi-feature

# Repo por repo
for d in ks-nuba libs/marc4j modules/docs; do
    echo "=== $d ==="
    (cd $d && git status -s)
done
```

### Push de Todos los Repos
```bash
# Desde el workspace
for d in ks-nuba libs/marc4j modules/docs; do
    echo "Pushing $d..."
    (cd $d && git push origin feature/mi-feature)
done
```

### Ver Worktrees de un Repo
```bash
# Repo en raíz
cd ~/wrkspc.nubarchiva/ks-nuba
git worktree list

# Repo en subdirectorio
cd ~/wrkspc.nubarchiva/libs/marc4j
git worktree list

cd ~/wrkspc.nubarchiva/modules/docs
git worktree list
```

## Nombres de Branches

| Workspace | Branch | Aplica a |
|-----------|--------|----------|
| `feature/name` | `feature/name` | Todos los repos |
| `master` | `master` | Todos los repos |
| `develop` | `develop` | Todos los repos |

## Listar Repos Disponibles

```bash
cd ~/wrkspc.nubarchiva

# Repos en raíz
ls -d */.git 2>/dev/null | sed 's|/.git||'

# Repos en libs/
ls -d libs/*/.git 2>/dev/null | sed 's|/.git||'

# Repos en modules/
ls -d modules/*/.git 2>/dev/null | sed 's|/.git||'

# Todo junto
find . -maxdepth 3 -name ".git" -type d | \
    sed 's|/.git||' | sed 's|^\./||' | sort

# Output ejemplo:
# dga-commons
# ks-nuba
# libs/dspace
# libs/foo-commonj
# libs/marc4j
# modules/diffusion-portal
# modules/docs
# modules/metadata-entities
```

## Alias Recomendados

```bash
# Añade a ~/.bashrc o ~/.zshrc
export WS_ROOT=~/wrkspc.nubarchiva

alias ws-new='$WS_ROOT/tools/new-workspace.sh'
alias ws-add='$WS_ROOT/tools/add-repo.sh'
alias ws-list='$WS_ROOT/tools/list-workspaces.sh'
alias ws-switch='$WS_ROOT/tools/switch-workspace.sh'
alias ws-clean='$WS_ROOT/tools/cleanup-workspace.sh'
alias ws='cd $WS_ROOT'
alias wsf='cd $WS_ROOT/workspaces/features'

# Función helper para status
ws-status() {
    local feature=$1
    cd $WS_ROOT/workspaces/features/$feature
    for d in */; do
        [ -d "$d/.git" ] || [ -f "$d/.git" ] && (
            cd $d
            echo "=== $d ==="
            git status -s
        )
    done
}
```

### Uso con Alias
```bash
# Crear
ws-new feature test ks-nuba libs/marc4j

# Listar
ws-list

# Ver detalle
ws-switch feature test

# Añadir repo
ws-add feature test modules/docs

# Limpiar
ws-clean feature test

# Status de una feature
ws-status test
```

## Troubleshooting

### Repo no encontrado
```bash
# Verifica la ruta
cd ~/wrkspc.nubarchiva
ls libs/marc4j/.git     # Debe existir
ls modules/docs/.git    # Debe existir

# Lista todos los repos
find . -maxdepth 3 -name ".git" -type d | sed 's|/.git||'
```

### Worktree huérfano
```bash
# Para repo en subdirectorio
cd ~/wrkspc.nubarchiva/libs/marc4j
git worktree prune

cd ~/wrkspc.nubarchiva/modules/docs
git worktree prune
```

### Ver estructura del workspace
```bash
cd ~/wrkspc.nubarchiva/workspaces/features/mi-feature
tree -L 3

# O
find . -type d -name ".git" | sed 's|/.git||'
```

## Tips

### ✅ Hacer
- Usar rutas completas: `libs/marc4j`, no `marc4j`
- Documentar el README.md de cada workspace
- Commitear antes de limpiar
- Verificar structure con `tree` o `ls`

### ❌ Evitar
- Usar solo nombre de repo sin path
- Eliminar directorios manualmente
- Trabajar en repos/ directamente
- Olvidar push antes de cleanup

## Integración con AI

### Claude Code - Todo el workspace
```bash
cd workspaces/features/mi-feature
claude-code .
# Ve toda la estructura jerárquica
```

### Claude Code - Solo un repo
```bash
cd workspaces/features/mi-feature/libs/marc4j
claude-code .
# Foco en la librería específica
```

### Cursor / Otros IDEs
```bash
cd workspaces/features/mi-feature
cursor .
# o
idea .
```

## Ejemplos Rápidos

```bash
# Simple: código + lib
ws-new feature quick ks-nuba libs/marc4j

# Solo libs
ws-new feature libs-work libs/marc4j libs/dspace

# Solo modules
ws-new feature docs-update modules/docs modules/diffusion-portal

# Full stack
ws-new feature big-change ks-nuba dga-commons libs/marc4j modules/docs

# Incremental
ws-new feature explore ks-nuba
ws-add feature explore libs/marc4j
ws-add feature explore modules/docs

# Master hotfix
ws-new master libs/marc4j
cd workspaces/master/libs/marc4j
# fix...
ws-clean master ""
```

## Ver También

- **README.md** - Guía completa de instalación y uso
- **EJEMPLOS.md** - 11 casos de uso detallados paso a paso
