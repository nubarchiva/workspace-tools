# Workspace Tools - Guía de Referencia

Referencia completa de comandos y opciones de Workspace Tools.

---

## Índice

1. [Instalación](#instalación)
2. [Configuración](#configuración)
3. [Comandos](#comandos)
4. [Shortcuts](#shortcuts)
5. [Abreviaturas](#abreviaturas)
6. [Troubleshooting](#troubleshooting)

---

## Instalación

### Requisitos

| Componente | Versión | Obligatorio | Notas |
|------------|---------|-------------|-------|
| Bash | 4.0+ | Sí | Los scripts en `bin/` usan `#!/bin/bash` |
| Git | 2.15+ | Sí | Worktrees requieren esta versión |
| Zsh | 5.0+ | No | Solo si usas Zsh como shell interactivo |
| OS | macOS / Linux | Sí | Windows no soportado |

**Importante:** Aunque uses Zsh como shell interactivo, **Bash 4.0+ debe estar instalado** en el sistema porque todos los scripts lo usan.

**macOS:** Viene con Bash 3.2 por defecto. Instala Bash 4+ con:
```bash
brew install bash
```

La verificación de versiones se realiza automáticamente en `install.sh` y `setup.sh`.

### Instalación Manual

```bash
# 1. Clonar o copiar el repositorio
git clone <url> /ruta/workspace-tools
cd /ruta/workspace-tools

# 2. Ejecutar instalador
./install.sh

# 3. Añadir a ~/.bashrc o ~/.zshrc
source /ruta/workspace-tools/setup.sh

# 4. Recargar shell
source ~/.bashrc  # o ~/.zshrc
```

### Instalación con Homebrew (macOS)

```bash
brew install --build-from-source ./Formula/workspace-tools.rb
```

### Verificar Instalación

```bash
ws --version
ws --help
```

---

## Configuración

### Archivo ~/.wsrc

Crea `~/.wsrc` para configuración personalizada:

```bash
# Directorio raíz del proyecto (donde están los repos)
WORKSPACE_ROOT="$HOME/mi-proyecto"

# Directorio donde crear workspaces (opcional)
WORKSPACES_DIR="$WORKSPACE_ROOT/workspaces"

# Modo debug (opcional)
WS_DEBUG=1

# Archivos a ignorar en ws clean (opcional)
# Por defecto: ".idea .vscode .kiro .cursor .playwright-mcp AI.md .ai docs README.md"
# Los enlaces simbólicos siempre se ignoran automáticamente
WS_CLEAN_IGNORE=".idea .vscode .kiro .cursor .playwright-mcp .claude AI.md .ai docs README.md"
```

### Prioridad de Configuración

1. Variables de entorno (para uso temporal)
2. `~/.wsrc` (configuración permanente)
3. Derivada de ubicación de scripts
4. Fallback por defecto

### Archivo de Templates

Los templates se guardan en `$WORKSPACE_ROOT/.ws-templates`:

```
frontend: app libs/ui modules/portal
backend: api libs/common libs/db
full: app api libs/common libs/ui
```

### Orden de Compilación Maven

Crea `$WORKSPACE_ROOT/.ws-build-order` para definir orden de compilación:

```
libs/common
libs/utils
app
api
```

---

## Comandos

### ws new

Crea un nuevo workspace.

```bash
ws new <nombre> [repos...]
ws new <nombre> --template <template> [repos...]
```

**Opciones:**
- `--template, -t <nombre>`: Usar repos de un template predefinido

**Comportamiento de branches:**
- `master` o `develop`: Usa esas branches existentes
- Otros nombres: Crea branch `feature/<nombre>`

**Ejemplos:**
```bash
ws new feature-123 app libs/common
ws new feature-123 --template frontend
ws new feature-123 -t backend libs/extra
ws new develop app api                    # usa branch develop
```

---

### ws add

Añade repos a un workspace existente.

```bash
ws add <workspace> <repo1> [repo2...]
```

**Ejemplos:**
```bash
ws add feature-123 libs/utils
ws add feature-123 libs/ui modules/api
```

---

### ws remove

Elimina repos de un workspace.

```bash
ws remove <workspace> <repo1> [repo2...]
```

**Verificaciones de seguridad:**
- Advierte si hay cambios sin commitear
- Advierte si hay commits sin pushear

**Ejemplos:**
```bash
ws remove feature-123 libs/utils
```

---

### ws list

Lista todos los workspaces.

```bash
ws list [patrón]
ws ls [patrón]
```

**Ejemplos:**
```bash
ws list                # todos
ws ls                  # alias
ws ls 8089             # filtrar por "8089"
ws ls feature          # filtrar por "feature"
```

**Información mostrada:**
- Nombre del workspace
- Número de repos
- Branch
- Indicadores de sincronización por repo:
  - `↑ N` (amarillo): N commits sin push
  - `← N` (cyan): N commits pusheados pendientes de merge a develop
  - `↓ N` (magenta): N commits nuevos en develop

---

### ws switch / ws cd

Muestra información del workspace y opcionalmente cambia de directorio.

```bash
ws switch <workspace>
ws cd <workspace>
```

**Diferencia:**
- `ws switch`: Solo muestra información
- `ws cd`: Muestra información Y cambia al directorio (requiere setup.sh)

**Ejemplos:**
```bash
ws switch feature-123
ws cd feat              # búsqueda parcial
```

---

### ws status

Muestra estado del workspace actual.

```bash
ws status [workspace]
ws .
ws here
```

**Información mostrada por repo:**
- Branch actual
- Cambios sin commitear
- Indicadores de sincronización:
  - `↑ N`: N commits sin push
  - `← N`: N commits pusheados pendientes de merge a develop
  - `↓ N`: N commits nuevos en develop
  - `↔️`: Sincronizado con develop

**Ejemplos:**
```bash
ws .                    # workspace actual (auto-detección)
ws status               # equivalente
ws status feature-123   # workspace específico
```

---

### ws info

Muestra información del workspace sin cambiar directorio.

```bash
ws info <workspace>
```

---

### ws rename

Renombra un workspace.

```bash
ws rename <nombre-actual> <nombre-nuevo>
ws mv <nombre-actual> <nombre-nuevo>
```

**Verificaciones:**
- Bloquea si hay cambios sin commitear
- Advierte sobre commits sin pushear
- Advierte sobre branches remotas
- Requiere confirmación escribiendo "RENOMBRAR"

**Acciones automáticas:**
- Renombra directorio
- Repara worktrees (`git worktree repair`)
- Renombra branches locales

---

### ws clean

Elimina un workspace.

```bash
ws clean <workspace>
ws rm <workspace>
ws del <workspace>
```

**Verificaciones:**
- Advierte si hay cambios sin commitear
- Advierte si hay commits sin pushear
- Requiere confirmación

**Archivos ignorados:**
- Algunos archivos/directorios se ignoran al decidir si el workspace está vacío
- Por defecto: `.idea`, `.vscode`, `.kiro`, `.cursor`, `.playwright-mcp`, `AI.md`, `.ai`, `docs`, `README.md`, `.DS_Store`
- Los enlaces simbólicos siempre se ignoran
- Configurable via `WS_CLEAN_IGNORE` en `~/.wsrc`

---

### ws git

Ejecuta comando Git en todos los repos del workspace.

```bash
ws git <workspace> <comando> [args...]
```

**Ejemplos:**
```bash
ws git feature-123 status
ws git feature-123 pull --all
ws git feature-123 log --oneline -5
ws git feature-123 push origin feature/feature-123
```

---

### ws mvn

Ejecuta Maven en todos los repos del workspace (que tengan pom.xml).

```bash
ws mvn <workspace> <args...>
```

**Características:**
- Ejecución paralela con `-T 1C`
- Resumen de tiempos por proyecto
- Respeta orden de `.ws-build-order` si existe

**Ejemplos:**
```bash
ws mvn feature-123 clean install
ws mvn feature-123 test
ws mvn feature-123 clean install -DskipTests
```

---

### ws update

Actualiza la branch de trabajo con lo último de develop (merge o rebase).

```bash
ws update [workspace] [opciones]
```

**Opciones:**
- `--all, -a`: Actualizar TODOS los workspaces
- `--dry, -d`: Modo simulación, muestra qué haría sin ejecutar
- `--rebase, -r`: Usar rebase en lugar de merge
- `--from, -f <branch>`: Especificar branch base (default: develop o master)

**Comportamiento:**
- Hace fetch del remoto primero
- Usa origin/develop si existe, sino develop local
- Fallback a master si no existe develop
- Salta repos con cambios sin commitear
- Se detiene si hay conflictos (excepto en modo `--all`)

**Ejemplos:**
```bash
ws update                 # merge develop en workspace actual
ws update --rebase        # rebase sobre develop
ws update --all           # actualizar todos los workspaces
ws update --all --dry     # ver qué actualizaría sin hacerlo
ws update feature-123     # workspace específico
ws update -r --from main  # rebase sobre main
```

---

### ws stash

Gestión coordinada de stash en todos los repos.

```bash
ws stash [acción] [workspace] [mensaje]
```

**Acciones:**
- `push` (default): Stash en repos con cambios
- `pop`: Restaurar último stash
- `list`: Listar stashes de todos los repos
- `clear`: Eliminar todos los stashes
- `show [n]`: Mostrar contenido del stash

**Ejemplos:**
```bash
ws stash                           # push en workspace actual
ws stash push "WIP: login"         # push con mensaje
ws stash pop                       # restaurar
ws stash list                      # ver stashes
ws stash show                      # contenido del último
ws stash clear                     # limpiar (con confirmación)
```

---

### ws grep

Busca texto en todos los repos del workspace.

```bash
ws grep <patrón> [workspace] [opciones]
```

**Opciones:**
- `-i`: Case-insensitive
- `-l`: Solo nombres de archivo
- `-n`: Mostrar números de línea
- `-w`: Palabra completa
- `-E`: Regex extendida
- `--type <ext>`: Filtrar por extensión (java, js, py, etc.)

**Ejemplos:**
```bash
ws grep "TODO"                     # workspace actual
ws grep -i "searchterm"            # case-insensitive
ws grep --type java "class Foo"    # solo archivos .java
ws grep -l "deprecated"            # solo nombres de archivo
ws grep -E "get.*User"             # regex
```

---

### ws templates

Gestión de templates de workspace.

```bash
ws templates [acción] [args...]
ws tpl [acción] [args...]
```

**Acciones:**
- `list` (default): Listar templates
- `add <nombre> <repos...>`: Crear/actualizar template
- `show <nombre>`: Mostrar repos de un template
- `remove <nombre>`: Eliminar template

**Ejemplos:**
```bash
ws templates                       # listar
ws tpl                             # alias
ws templates add frontend app libs/ui
ws templates show frontend
ws templates remove old-template
```

---

### ws prune

Limpia ramas locales huérfanas (cuyo remoto ya no existe).

```bash
ws prune [opciones] [repo...]
```

**Opciones:**
- `--dry-run`: Muestra qué se borraría sin borrar nada
- `--force`: Borra incluso ramas no mergeadas (¡PELIGRO!)
- `--all`: Aplica a todos los repos del workspace

**Comportamiento:**
- Por defecto, solo borra ramas que:
  1. Ya no existen en el remoto (marcadas como `gone`)
  2. Están completamente mergeadas en develop/main
- Con `--force`, borra TODAS las ramas huérfanas (posible pérdida de datos)
- Hace `git fetch --prune` automáticamente antes de analizar

**¿Por qué existen estas ramas?**
- Se crean automáticamente al hacer `git checkout` de una rama remota
- O cuando `ws new` / `ws add` crean worktrees
- Permanecen incluso cuando la rama remota se borra (tras merge de PR)

**Ejemplos:**
```bash
ws prune                    # limpia repo actual (solo mergeadas)
ws prune --dry-run          # ver qué se borraría
ws prune --all              # limpia todos los repos
ws prune --all --dry-run    # ver qué se borraría en todos
ws prune --force ks-nuba    # forzar en repo específico
```

---

### ws origins

Ejecuta comandos en todos los repos origen (en WORKSPACE_ROOT).

```bash
ws origins <subcomando> [args...]
```

**Subcomandos:**
- `git <args>`: Ejecuta git en todos los repos origen
- `list`: Lista todos los repos origen detectados

**Comportamiento:**
- Opera sobre los repos principales (donde está el .git)
- Excluye el directorio workspaces/
- Respeta `.wsignore` para excluir repos específicos
- Útil para actualizar repos en develop/master

**Archivo .wsignore:**

Crea `$WORKSPACE_ROOT/.wsignore` para excluir repos:

```
# Repos externos que no deben participar en operaciones ws origins
external-tools

# Otros repos a ignorar
legacy-project
vendor/external-lib
```

Formato:
- Un repo por línea (ruta relativa desde WORKSPACE_ROOT)
- Comentarios con `#`
- Líneas vacías ignoradas

**Ejemplos:**
```bash
ws origins git pull         # pull en todos los repos origen
ws origins git status       # status de todos
ws origins git fetch        # fetch en todos
ws origins list             # listar repos detectados (muestra ignorados)
```

---

### wscd

Navega entre repos del workspace actual.

```bash
wscd [patrón]
```

**Comportamiento:**
- Sin argumento: Menú interactivo
- Con patrón: Busca repo que coincida (case-insensitive)
- `.`: Raíz del workspace
- `..`: Nivel arriba

**Ejemplos:**
```bash
wscd                    # menú de repos
wscd app                # ir a repo "app"
wscd lib                # ir a repo que contiene "lib"
wscd .                  # raíz del workspace
```

---

## Shortcuts

Definidos en `setup.sh`:

### Maven

| Shortcut | Comando |
|----------|---------|
| `wmcis [ws]` | `ws mvn clean install -DskipTests -Denforcer.skip` |
| `wmis [ws]` | `ws mvn install -DskipTests -Denforcer.skip` |
| `wmci [ws]` | `ws mvn clean install` |
| `wmcl [ws]` | `ws mvn clean` |

### Git

| Shortcut | Comando |
|----------|---------|
| `wgt [ws]` | `ws git status` |
| `wgpa [ws]` | `ws git pull --all` |
| `wstash` | `ws stash` |
| `wgrep` | `ws grep` |

**Nota:** Si no se especifica workspace, usan auto-detección.

---

## Abreviaturas

### Comandos

| Abreviatura | Comando |
|-------------|---------|
| `n`, `mk`, `create` | `new` |
| `a` | `add` |
| `ls` | `list` |
| `cd`, `sw` | `switch` |
| `rm`, `del` | `clean` |
| `mv` | `rename` |
| `.`, `here` | `status` |
| `tpl` | `templates` |
| `h` | `help` |

### Expansión Automática

Cualquier prefijo único de comando se expande automáticamente:

```bash
ws l        # → ws list
ws up       # → ws update
ws sta      # → ws stash (o status si es más único)
```

### Búsqueda Parcial de Workspaces

Todos los comandos soportan coincidencia parcial case-insensitive:

```bash
ws cd feat          # encuentra "feature-123"
ws add api lib      # encuentra workspace "api-redesign"
```

Si hay múltiples coincidencias, muestra menú interactivo.

---

## Troubleshooting

### "Repo no encontrado"

Verificar que la ruta es correcta y relativa a WORKSPACE_ROOT:

```bash
# Correcto
ws add feature-123 libs/common

# Incorrecto
ws add feature-123 common        # falta "libs/"
```

### Listar repos disponibles

```bash
cd $WORKSPACE_ROOT
find . -maxdepth 3 -name ".git" -type d | sed 's|/.git||' | sed 's|^\./||' | sort
```

### Autocompletado no funciona

Verificar que setup.sh está cargado:

```bash
source /ruta/workspace-tools/setup.sh
```

### ws cd no cambia directorio

`ws cd` requiere que `setup.sh` esté cargado (define la función shell).

### Ver configuración actual

```bash
echo "WORKSPACE_ROOT: $WORKSPACE_ROOT"
echo "WORKSPACES_DIR: $WORKSPACES_DIR"
echo "WS_TOOLS: $WS_TOOLS"
```

### Activar modo debug

```bash
export WS_DEBUG=1
ws list
```

---

## Ver También

- **[README.md](README.md)** - Introducción y uso rápido
- **[CHANGELOG.md](CHANGELOG.md)** - Historial de cambios
- **[ROADMAP.md](ROADMAP.md)** - Funcionalidades implementadas y futuras
