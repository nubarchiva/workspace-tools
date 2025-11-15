# Workspace Tools

Sistema de gestión de workspaces con Git worktrees para desarrollo paralelo en múltiples repositorios.

## Estructura de tu Workspace

```
~/wrkspc.nubarchiva/
├── ks-nuba/                    # Repo
├── dga-commons/                # Repo
├── libs/                       # Contenedor de repos
│   ├── dspace/                # Repo
│   ├── marc4j/                # Repo
│   ├── foo-commonj/           # Repo
│   └── ...
├── modules/                    # Contenedor de repos
│   ├── docs/                  # Repo
│   ├── metadata-entities/     # Repo
│   └── ...
├── tools/                      # Contenedor de repos
│   └── workspace-tools/       # Este repo
│       ├── bin/               # Scripts
│       └── README.md
└── workspaces/                 # Se crea automáticamente
    ├── master/
    ├── develop/
    └── features/
```

## Instalación

### Opción 1: Como Repositorio Git (Recomendado)

```bash
cd ~/wrkspc.nubarchiva/tools
git clone <url-del-repo> workspace-tools
cd workspace-tools
./install.sh
```

### Opción 2: Extraer desde Tarball

```bash
cd ~/wrkspc.nubarchiva/tools
tar -xzf workspace-tools.tar.gz
cd workspace-tools
./install.sh
```

### Qué hace install.sh

1. Detecta la ubicación del workspace (2 niveles arriba: `~/wrkspc.nubarchiva`)
2. Crea el directorio `workspaces/` si no existe
3. Configura alias opcionales en tu shell
4. ¡Listo para usar!

## Uso Rápido

Puedes usar el comando unificado `ws` o los scripts individuales:

```bash
cd ~/wrkspc.nubarchiva/tools/workspace-tools

# Comando unificado (recomendado)
./bin/ws new feature mi-feature ks-nuba libs/marc4j
./bin/ws list
./bin/ws switch feature mi-feature
./bin/ws add feature mi-feature modules/docs
./bin/ws clean feature mi-feature

# O scripts individuales (compatibilidad)
./bin/ws-new feature mi-feature ks-nuba libs/marc4j
./bin/ws-list
./bin/ws-switch feature mi-feature
./bin/ws-add feature mi-feature modules/docs
./bin/ws-clean feature mi-feature
```

## Alias Recomendados

Añade a tu `~/.bashrc` o `~/.zshrc`:

```bash
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
```

Después de configurar:

```bash
source ~/.bashrc  # o source ~/.zshrc

# Usar desde cualquier lugar con el comando unificado
ws new feature test ks-nuba libs/marc4j
ws list
ws switch feature test
ws add feature test modules/docs
ws clean feature test

# O con los comandos individuales (compatibilidad)
ws-new feature test ks-nuba libs/marc4j
ws-list
ws-switch feature test
```

## Autocompletado (Opcional)

Para habilitar autocompletado de comandos, subcomandos, tipos de workspace, features y repos:

### Bash

Añade a tu `~/.bashrc`:

```bash
source $WS_TOOLS/completions/ws-completion.bash
```

### Zsh

Añade a tu `~/.zshrc`:

```bash
source $WS_TOOLS/completions/ws-completion.zsh
```

Después ejecuta `source ~/.bashrc` (o `source ~/.zshrc`) para activarlo.

**Características del autocompletado:**
- ✅ Completa subcomandos: `ws <TAB>` → new, add, switch, list, clean, help
- ✅ Completa tipos: `ws new <TAB>` → feature, master, develop
- ✅ Completa features: `ws switch feature <TAB>` → lista features disponibles
- ✅ Completa repos: `ws new feature test <TAB>` → lista repos disponibles
- ✅ Soporta repos en subdirectorios: `libs/marc4j`, `modules/docs`

## Características

- ✅ Workspaces aislados para master, develop y features
- ✅ Un cambio afecta a múltiples repos simultáneamente
- ✅ Soporte para repos en subdirectorios (`libs/*`, `modules/*`, `tools/*`)
- ✅ Añadir repos dinámicamente según necesites
- ✅ Múltiples features en paralelo sin conflictos
- ✅ Optimizado para herramientas de AI (Claude Code, etc.)

## Ejemplos

### Feature con múltiples niveles
```bash
ws-new feature marc-upgrade ks-nuba libs/marc4j modules/metadata-entities

# Estructura creada:
# workspaces/features/marc-upgrade/
# ├── ks-nuba/
# ├── libs/
# │   └── marc4j/
# └── modules/
#     └── metadata-entities/
```

### Feature incremental
```bash
# Empezar con un repo
ws-new feature explore ks-nuba

# Añadir según necesites
ws-add feature explore libs/marc4j
ws-add feature explore modules/docs
```

### Hotfix en librería
```bash
ws-new master libs/marc4j
cd ~/wrkspc.nubarchiva/workspaces/master/libs/marc4j
# hacer fix...
ws-clean master ""
```

## Comandos

Puedes usar el comando unificado `ws` (recomendado) o los comandos individuales para compatibilidad.

### ws new (o ws-new)
Crea un nuevo workspace.

```bash
# Sintaxis
ws new <tipo> <nombre> [repo1] [repo2] ...
# o
ws-new <tipo> <nombre> [repo1] [repo2] ...

# Tipos: feature, master, develop

# Ejemplos
ws new feature mi-feature ks-nuba
ws new feature full ks-nuba libs/marc4j modules/docs
ws new master ks-nuba libs/dspace
ws new develop
```

### ws add (o ws-add)
Añade un repo a un workspace existente.

```bash
# Sintaxis
ws add <tipo> <nombre|patrón> <repo>
# o
ws-add <tipo> <nombre|patrón> <repo>

# Ejemplos
ws add feature mi-feature libs/marc4j
ws add feature fac modules/docs          # coincidencia parcial
ws add master tools/workspace-tools
```

### ws list (o ws-list)
Lista todos los workspaces activos con su estado.

```bash
ws list
# o
ws-list
```

### ws switch (o ws-switch)
Muestra información detallada de un workspace.

```bash
# Ver workspaces disponibles
ws switch
# o sin argumentos
ws-switch

# Ver detalle de uno específico
ws switch feature mi-feature
ws switch feature fac                    # coincidencia parcial
ws switch master
```

### ws clean (o ws-clean)
Limpia un workspace (elimina worktrees, mantiene branches).

```bash
ws clean feature mi-feature
ws clean feature fac                     # coincidencia parcial
ws clean master
ws clean develop
```

💡 **Búsqueda parcial**: Todos los comandos que aceptan nombre de workspace soportan coincidencia parcial. Si hay múltiples coincidencias, se mostrará un menú interactivo.

## Especificar Repos

**Siempre usa rutas relativas desde `~/wrkspc.nubarchiva`:**

```bash
# ✅ Correcto
ws-new feature test ks-nuba                    # Repo en raíz
ws-new feature test libs/marc4j                # Repo en libs/
ws-new feature test modules/docs               # Repo en modules/
ws-new feature test tools/workspace-tools      # Repo en tools/

# ❌ Incorrecto
ws-new feature test marc4j      # Falta "libs/"
ws-new feature test docs        # Falta "modules/"
```

## Estructura de Workspaces

Los workspaces mantienen la jerarquía de subdirectorios:

```
workspaces/features/mi-feature/
├── ks-nuba/                    # Worktree → feature/mi-feature
├── libs/
│   ├── marc4j/                # Worktree → feature/mi-feature
│   └── dspace/                # Worktree → feature/mi-feature
├── modules/
│   └── docs/                  # Worktree → feature/mi-feature
└── tools/
    └── otro-tool/             # Worktree → feature/mi-feature
```

## Branches

| Workspace | Branch Name | Aplica a |
|-----------|------------|----------|
| `feature/nombre` | `feature/nombre` | Todos los repos del workspace |
| `master` | `master` | Todos los repos del workspace |
| `develop` | `develop` | Todos los repos del workspace |

## Workflow Típico

```bash
# 1. Crear feature con los repos necesarios
ws-new feature nueva-busqueda ks-nuba libs/marc4j

# 2. Trabajar
cd ~/wrkspc.nubarchiva/workspaces/features/nueva-busqueda
claude-code .  # o tu editor preferido

# 3. Hacer commits en cada repo
cd ks-nuba
git commit -am "feat: implement search"

cd ../libs/marc4j
git commit -am "feat: extend MARC parser"

# 4. Push
cd ks-nuba && git push origin feature/nueva-busqueda
cd ../libs/marc4j && git push origin feature/nueva-busqueda

# 5. Limpiar cuando termines
ws-clean feature nueva-busqueda
```

## Integración con AI Tools

### Claude Code
```bash
# Todo el workspace
cd ~/wrkspc.nubarchiva/workspaces/features/mi-feature
claude-code .

# Un repo específico
cd ~/wrkspc.nubarchiva/workspaces/features/mi-feature/libs/marc4j
claude-code .
```

### Documentar para AI
Cada workspace tiene un `README.md` donde puedes documentar:
- Objetivo del cambio
- Repos involucrados y su rol
- Contexto técnico
- Checklist

Esto ayuda a las herramientas de AI a entender el contexto.

## Troubleshooting

### Ver repos disponibles
```bash
cd ~/wrkspc.nubarchiva
find . -maxdepth 3 -name ".git" -type d | sed 's|/.git||' | sed 's|^\./||' | sort
```

### Limpiar worktrees huérfanos
```bash
# En cualquier repo
cd ~/wrkspc.nubarchiva/<path-to-repo>
git worktree list
git worktree prune
```

### Verificar workspaces
```bash
ws-list
# o
cd ~/wrkspc.nubarchiva/workspaces
tree -L 3
```

## Actualizar

Si este repo tiene actualizaciones:

```bash
cd ~/wrkspc.nubarchiva/tools/workspace-tools
git pull
```

## Documentación Adicional

- **EJEMPLOS.md** - 11 casos de uso detallados paso a paso
- **CHEATSHEET.md** - Referencia rápida de comandos

## Licencia

Uso interno para el proyecto NubArchiva.

---

**Versión:** 2.1  
**Fecha:** 15 de noviembre de 2025  
**Autor:** José Antonio
