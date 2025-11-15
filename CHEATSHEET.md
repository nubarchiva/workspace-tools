# Workspace Tools - Cheatsheet v2.2

## Configuración Inicial

```bash
# Añade a ~/.bashrc o ~/.zshrc (UNA SOLA LÍNEA)
source ~/wrkspc.nubarchiva/tools/workspace-tools/setup.sh

# Recargar
source ~/.bashrc  # o ~/.zshrc
```

**Esto configura automáticamente:**
- Variable `WS_TOOLS`
- Comando `ws` en el PATH
- Función `ws cd` (cambia automáticamente de directorio)
- Autocompletado (bash o zsh)

## Comandos Rápidos

### Crear Workspaces
```bash
# Feature (crea branch feature/<nombre>)
ws new <nombre> ks-nuba dga-commons
ws new <nombre> libs/marc4j modules/docs
ws new <nombre> ks-nuba libs/marc4j modules/docs

# Master/Develop (usa esas branches)
ws new master ks-nuba libs/dspace
ws new develop ks-nuba libs/marc4j modules/docs

# Workspace vacío (añadir repos después)
ws new <nombre>

# Abreviaturas
ws n <nombre> ks-nuba           # new
ws mk <nombre> libs/marc4j      # new
```

### Añadir Repos
```bash
# Añadir un repo
ws add <nombre> ks-nuba

# Añadir múltiples repos
ws add <nombre> dga-commons libs/marc4j modules/docs

# Con búsqueda parcial
ws add fac libs/marc4j          # encuentra "faceted-search"

# Añadir a master/develop
ws add master libs/dspace
ws add develop modules/metadata-entities

# Abreviatura
ws a <nombre> <repos...>        # add
```

### Cambiar a Workspace
```bash
# Cambia automáticamente al directorio
ws cd <nombre>

# Con búsqueda parcial
ws cd fac                       # busca 'fac' en workspaces

# Con autocompletado
ws cd <TAB>                     # lista workspaces

# Solo ver info (no cambia directorio)
ws switch <nombre>
```

### Listar y Ver
```bash
# Listar todos los workspaces
ws list
ws ls                           # abreviatura

# Ver workspaces disponibles
ws switch                       # sin argumentos

# Ver detalle de workspace
ws switch <nombre>
ws switch fac                   # búsqueda parcial
```

### Limpiar
```bash
# Limpiar workspace (con búsqueda parcial)
ws clean <nombre>
ws clean fac                    # búsqueda parcial

# Limpiar master/develop
ws clean master
ws clean develop

# Abreviaturas
ws rm <nombre>                  # clean
ws del <nombre>                 # clean
```

## Abreviaturas de Comandos

```bash
# Automáticas (cualquier prefijo único)
ws n <nombre> <repos...>        # new
ws a <nombre> <repos...>        # add
ws l                            # list
ws c <nombre>                   # clean
ws cl <nombre>                  # clean

# Predefinidas
ws ls                           # list
ws cd <nombre>                  # switch + cambiar directorio
ws rm <nombre>                  # clean
ws del <nombre>                 # clean
ws mk <nombre> <repos...>       # new
ws create <nombre> <repos...>   # new
ws h                            # help
```

## Búsqueda Parcial

Todos los comandos soportan coincidencia parcial:

```bash
ws cd nuba                      # busca 'nuba' en workspaces
ws add fac libs/marc4j          # busca 'fac' en workspaces
ws rm test                      # busca 'test' en workspaces
ws switch marc                  # busca 'marc' en workspaces
```

Si hay múltiples coincidencias, se muestra un menú interactivo para seleccionar.

## Autocompletado

Con `setup.sh` cargado, el autocompletado funciona en:

```bash
ws <TAB>                        # subcomandos: new, add, switch, list, clean
ws new <TAB>                    # master, develop, o nombre libre
ws new test <TAB>               # repos disponibles
ws cd <TAB>                     # workspaces existentes
ws add test <TAB>               # repos disponibles
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
    └── nuba-8400/          # Feature workspace
        ├── ks-nuba/           # Worktree → feature/nuba-8400
        ├── libs/
        │   └── marc4j/       # Worktree → feature/nuba-8400
        └── modules/
            └── docs/          # Worktree → feature/nuba-8400
```

## Especificar Repos

### Siempre Usa Rutas Relativas desde la Raíz

```bash
# ✅ Correcto
ws new test ks-nuba              # Repo en raíz
ws new test libs/marc4j          # Repo en libs/
ws new test modules/docs         # Repo en modules/
ws new test tools/otro-tool      # Repo en tools/

# ❌ Incorrecto
ws new test marc4j               # Falta "libs/"
ws new test docs                 # Falta "modules/"
```

## Workflows Típicos

### Feature con Múltiples Repos
```bash
# 1. Crear
ws new full ks-nuba libs/marc4j modules/docs

# 2. Cambiar al workspace
ws cd full

# 3. Trabajar
claude-code .

# 4. Commits
cd ks-nuba && git commit -am "feat: main changes"
cd ../libs/marc4j && git commit -am "feat: lib changes"
cd ../../modules/docs && git commit -am "docs: update"

# 5. Limpiar
ws clean full
```

### Añadir Repos Dinámicamente
```bash
# Empezar con uno
ws new dynamic ks-nuba

# Añadir según necesites
ws add dyn libs/marc4j           # búsqueda parcial "dyn" → "dynamic"
ws add dynamic modules/docs

# Ver qué tienes
ws switch dyn
```

### Hotfix en Librería
```bash
# Solo la librería
ws new master libs/marc4j

# Cambiar y trabajar
ws cd master
cd libs/marc4j
# fix, commit, push

# Limpiar
ws clean master
```

## Patrones Comunes

```bash
# Código principal + una lib
ws new name ks-nuba libs/marc4j

# Solo librerías
ws new libs-only libs/lib1 libs/lib2

# Solo módulos
ws new mods-only modules/mod1 modules/mod2

# Todo mezclado
ws new full ks-nuba libs/lib1 modules/mod1
```

## Git Operations

### Status de Todos los Repos
```bash
# Cambiar al workspace
ws cd mi-feature

# Repo por repo
for d in ks-nuba libs/marc4j modules/docs; do
    echo "=== $d ==="
    (cd $d && git status -s)
done
```

### Push de Todos los Repos
```bash
# Desde el workspace
ws cd mi-feature

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

| Workspace | Branch | Creación |
|-----------|--------|----------|
| `master` | `master` | Usa branch existente |
| `develop` | `develop` | Usa branch existente |
| Otros (ej: `nuba-8400`) | `feature/nuba-8400` | Crea branch automáticamente |

## Listar Repos Disponibles

```bash
cd ~/wrkspc.nubarchiva

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
ws cd mi-feature
tree -L 3

# O
find . -type d -name ".git" | sed 's|/.git||'
```

### Autocompletado no funciona
```bash
# Verificar que setup.sh está cargado
source ~/wrkspc.nubarchiva/tools/workspace-tools/setup.sh

# Añadir permanentemente a ~/.bashrc o ~/.zshrc
echo 'source ~/wrkspc.nubarchiva/tools/workspace-tools/setup.sh' >> ~/.zshrc
```

## Tips

### ✅ Hacer
- Usar rutas completas: `libs/marc4j`, no `marc4j`
- Usar `ws cd` para navegar automáticamente
- Usar búsqueda parcial para ahorrar tiempo
- Documentar el README.md de cada workspace
- Commitear antes de limpiar
- Verificar estructura con `ws switch <nombre>`

### ❌ Evitar
- Usar solo nombre de repo sin path
- Eliminar directorios manualmente
- Trabajar en repos/ directamente
- Olvidar push antes de cleanup

## Integración con AI

### Claude Code - Todo el workspace
```bash
ws cd mi-feature
claude-code .
# Ve toda la estructura jerárquica
```

### Claude Code - Solo un repo
```bash
ws cd mi-feature
cd libs/marc4j
claude-code .
# Foco en la librería específica
```

### Cursor / Otros IDEs
```bash
ws cd mi-feature
cursor .
# o
idea .
```

## Ejemplos Rápidos

```bash
# Simple: código + lib
ws new quick ks-nuba libs/marc4j
ws cd quick

# Solo libs
ws new libs-work libs/marc4j libs/dspace
ws cd libs

# Solo modules
ws new docs-update modules/docs modules/diffusion-portal
ws cd docs

# Full stack
ws new big-change ks-nuba dga-commons libs/marc4j modules/docs
ws cd big

# Incremental
ws new explore ks-nuba
ws add exp libs/marc4j          # búsqueda parcial "exp"
ws add explore modules/docs
ws cd explore

# Master hotfix
ws new master libs/marc4j
ws cd master
cd libs/marc4j
# fix...
ws clean master
```

## Ver También

- **README.md** - Guía completa de instalación y uso
- **QUICKSTART.md** - Inicio rápido
- **EJEMPLOS.md** - 11 casos de uso detallados paso a paso
