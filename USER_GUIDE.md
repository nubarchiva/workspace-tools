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
| curl y jq | - | No | Solo para los pull requests de `ws status` |
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

# Aislamiento del repositorio Maven por workspace (opcional)
WS_MAVEN_ISOLATION=false                  # desactivarlo (por defecto activo)
WS_MAVEN_HEAD_BASE="$HOME/.m2/wt"         # base de los heads por workspace
WS_MAVEN_TAIL="$HOME/.m2/repository"      # repositorio compartido (tail)

# Repositorios de entorno: los que el workspace consume pero no desarrolla (opcional, ver ws env)
WS_ENV_REPOS="~/.claude:.ai:tools/workspace-tools"
WS_ENV_FETCH_TTL=300                      # segundos sin repetir fetch en los avisos automáticos
WS_ENV_FETCH_TIMEOUT=5                    # tiempo de espera de cada fetch
WS_ENV_BUSY_CMD="pgrep -x claude"         # PID de las sesiones que usan esos repositorios

# Pull requests en ws status: servidor Bitbucket Server / Data Center (opcional, requiere curl y jq)
WS_BITBUCKET_URL="https://bitbucket.example.com"  # URL base del servidor
WS_BITBUCKET_TOKEN="..."                  # token de acceso HTTP con permiso de lectura
WS_BITBUCKET_HOSTS="bitbucket.example.com git.example.com"  # hosts de los remotos git de ese servidor (por defecto, el de la URL)
WS_BITBUCKET_TIMEOUT=5                    # tiempo de espera de cada consulta
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

### Aislamiento del repositorio Maven por workspace

Cuando varios workspaces construyen los mismos GAV `*-SNAPSHOT` desde código
distinto, sus `mvn install` contra el `~/.m2/repository` compartido se pisan
los artefactos mutuamente (fallo silencioso: el código de un workspace acaba
ejecutándose con jars de otro).

Para evitarlo, `ws new` y `ws add` crean `.mvn/maven.config` en cada repo con
`pom.xml` (requiere Maven >= 3.9):

```
-Dmaven.repo.local=$HOME/.m2/wt/<workspace>/repository
-Dmaven.repo.local.tail=$HOME/.m2/repository
```

- **Escrituras** (`mvn install`, descargas nuevas) van solo al *head* del
  workspace: ningún workspace puede pisar a otro.
- **Lecturas**: primero el head; lo que no esté (terceros ya descargados) se
  lee del *tail* compartido, sin re-descargar ni duplicar disco.
- El fichero se excluye de git automáticamente (`info/exclude` del repo:
  contiene rutas absolutas locales).

**Importante**: hasta poblar el head, los GAV propios se leen del tail
compartido (donde otras sesiones siguen escribiendo). Puebla el head una vez
con `ws mvn <workspace> install -DskipTests -nsu` (respeta `.ws-build-order`)
o crea el workspace con `ws new --bootstrap`.

`ws clean` elimina el head del workspace para liberar disco. Configurable con
`WS_MAVEN_ISOLATION`, `WS_MAVEN_HEAD_BASE` y `WS_MAVEN_TAIL` (ver `~/.wsrc`).

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
- `--bootstrap, -b`: Poblar el repositorio Maven del workspace tras crearlo
  (ejecuta `ws mvn install -DskipTests -nsu`; puede tardar minutos)

**Comportamiento de branches:**
- `master` o `develop`: Usa esas branches existentes
- Otros nombres: Crea branch `feature/<nombre>`

**Aislamiento Maven:** en cada repo con `pom.xml` se crea `.mvn/maven.config`
con un repositorio head propio del workspace (ver [Aislamiento del repositorio
Maven por workspace](#aislamiento-del-repositorio-maven-por-workspace)).

**Ejemplos:**
```bash
ws new feature-123 app libs/common
ws new feature-123 --template frontend
ws new feature-123 -t backend libs/extra
ws new feature-123 --bootstrap app        # crea y puebla el head Maven
ws new develop app api                    # usa branch develop
```

---

### ws add

Añade repos a un workspace existente.

```bash
ws add <workspace> <repo1> [repo2...]
```

**Aislamiento Maven:** los repos añadidos con `pom.xml` reciben su
`.mvn/maven.config` apuntando al head del workspace. Recuerda poblar el head
(`ws mvn <workspace> install -DskipTests -nsu`) para que los GAV del repo
añadido no se lean del tail compartido.

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

Los dos avisan en una línea si algún repositorio de entorno va por detrás de su
remoto o no se ha podido comprobar (ver [ws env](#ws-env)).

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

Si hay repositorios de entorno declarados, muestra además su estado en el
apartado **Entorno** (ver [ws env](#ws-env)).

**Pull requests:** si hay un servidor Bitbucket declarado en `~/.wsrc`
(`WS_BITBUCKET_URL` y `WS_BITBUCKET_TOKEN`), cada repo que esté en la rama del
workspace muestra el pull request más reciente cuyo origen es esa rama, en
cualquier estado:

```
   🔀 PR #42 OPEN ✅ → develop https://bitbucket.example.com/projects/PROJ/repos/api/pull-requests/42
```

- Solo se consultan los repos cuyo remoto `origin` apunta a un host de
  `WS_BITBUCKET_HOSTS` (por defecto, el host de `WS_BITBUCKET_URL`)
- Si la rama tiene varios, solo se muestra el más reciente
- El indicador tras el estado es la construcción del commit del pull request:
  ✅ correcta, ❌ fallida, ⏳ en curso. Sin construcciones no aparece nada, y si
  el servidor no da ese dato el pull request se muestra igual
- Sin pull requests se indica «Sin pull requests»; si la consulta falla, se
  indica el motivo (token rechazado, servidor inaccesible, repositorio no encontrado…).
  Un fallo de conexión o de credenciales no se repite en los repos siguientes
- No se consulta en modo offline, en workspaces de rama de integración
  (`master`, `main`, `develop`) ni en `ws switch` / `ws info`

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

**Aislamiento Maven:** elimina también el repositorio head del workspace
(`~/.m2/wt/<workspace>/`) para liberar disco.

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
- Ejecuta `mvn` desde la raíz de cada repo, aplicando su `.mvn/maven.config`
  (aislamiento del repositorio Maven por workspace)

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
- `clone [opciones]`: Clona los repos declarados en un manifiesto (ver más abajo)
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

### ws origins clone

Clona en WORKSPACE_ROOT los repositorios declarados en un manifiesto. Es el paso
previo a todo lo demás: `ws new` crea worktrees sobre repos ya clonados, y en una
máquina recién instalada todavía no hay ninguno.

```bash
ws origins clone [opciones]
```

**Opciones:**
- `--group, -g <g1,g2>`: clona solo esos grupos (acumulable)
- `--manifest, -m <ruta>`: manifiesto a usar (acumulable, se componen en orden)
- `--seed <url>`: clona primero el repositorio que contiene el manifiesto y lo lee de ahí
- `--include-manual`: clona también lo marcado `manual`
- `--dry-run`: muestra qué haría, sin clonar ni consultar la red
- `--list-groups`: lista los grupos declarados en el manifiesto

**Comportamiento:**
- No pregunta nada: sirve en flujo desatendido
- Idempotente: un repositorio ya clonado se salta
- El fallo de uno no detiene a los demás; el código de salida es distinto de 0 si hubo alguno
- Al terminar informa de qué clonó, qué saltó, qué omitió y qué falló
- Nunca sobrescribe: si el destino existe y no está vacío, lo reporta y sigue
- Si un repositorio ya clonado tiene un `origin` distinto al del manifiesto, lo destaca sin tocarlo

**Comprobación previa:**

Antes de descargar nada comprueba cada servidor una vez y traduce el fallo a su
causa, con el remedio concreto:

| Síntoma | Qué dice |
|---------|----------|
| El nombre no resuelve | Sugiere usar el FQDN en vez de un alias de `/etc/hosts` |
| Host key desconocida | Da el `ssh-keyscan -p <puerto> <host>` literal |
| Clave rechazada | Recuerda dar de alta la pública y comprobar `ssh-add -l` |
| HTTPS sin credenciales | Pide configurar un credential helper o usar SSH |
| Certificado de cliente | Sugiere marcar ese repositorio como `manual` |
| Conexión bloqueada | Apunta a cortafuegos o proxy |

Un servidor inaccesible marca sus repositorios como fallidos con esa explicación,
y el resto se clona igualmente.

**El manifiesto:**

No viene con la herramienta: la lista de repositorios es de tu proyecto.
Una línea por repositorio, cinco campos:

```
# destino        url                                    grupos      flags   motivo
app              git@example.com:org/app.git            core,apps   -       -
libs/common      git@example.com:org/common.git         core,libs   -       -
modules/portal   git@example.com:org/module-portal.git  modules     -       -
legacy-archive   https://interno.example.org/a.git      external    manual  requiere certificado de cliente
```

El destino es la ruta relativa a WORKSPACE_ROOT y admite anidamiento. Es un campo
propio, y no se deriva de la URL, porque el directorio de trabajo no siempre se
llama como el repositorio.

Dónde se busca, por orden de precedencia:

1. `--manifest <ruta>`
2. `WS_MANIFEST` en `~/.wsrc` (lista separada por `:`)
3. `<clon de --seed>/.ws-manifest`
4. `$WORKSPACE_ROOT/.ws-manifest`

Y siempre, si existe, `~/.ws-manifest.local`.

**Composición: público + privado + personal**

Se pueden componer varios manifiestos: se cargan en orden y, a igualdad de
destino, gana el último. Eso permite separar por visibilidad sin duplicar nada,
que es lo que necesita un proyecto con parte abierta y parte cerrada:

```bash
ws origins clone --manifest manifiesto-publico --manifest manifiesto-privado
```

A quien solo trabaje con la parte abierta le basta el manifiesto público. Los
repositorios propios de cada uno van en `~/.ws-manifest.local`, que nunca se
comparte y se compone siempre el último.

Formato completo y comentado: `config/manifest.example`.

**Ejemplos:**
```bash
ws origins clone                              # todo el manifiesto
ws origins clone --group core                 # solo el núcleo
ws origins clone --dry-run                    # ver el plan
ws origins clone --list-groups                # qué grupos hay
ws origins clone --seed <url>                 # primer arranque, máquina limpia
```

---

### ws env

Comprueba y sincroniza los repositorios de entorno: los que el workspace consume
pero no desarrolla, como la configuración de los asistentes, las directrices, el
tooling o la gestión compartidos. `ws update` no los toca.

```bash
ws env [status] [--no-fetch]
ws env sync [--yes] [--sessions]
```

Cada usuario los declara en `~/.wsrc`. La herramienta no presupone ninguno:

```bash
WS_ENV_REPOS="~/.claude:.ai:tools/workspace-tools"
```

Las rutas van separadas por `:` y pueden ser absolutas, empezar por `~` o ser
relativas a `WORKSPACE_ROOT`. Cada una debe ser la raíz de un repositorio git;
cualquier otra cosa se lista como «sin comprobar» y no impide tratar las demás.

**Acciones:**

| Acción | Qué hace |
|--------|----------|
| `status` (por defecto) | Hace fetch y muestra, por repositorio, si está al día, por detrás o divergido, con el hash y la fecha de su último commit. No toca el árbol de trabajo. Sale con 1 si alguno va por detrás, ha divergido o no se ha podido comprobar |
| `sync` | Avanza con fast-forward los que van por detrás e informa del salto de hash, del número de commits y de los ficheros cambiados. Termina con el estado final de cada repositorio |

El hash y la fecha permiten comparar dos máquinas: si coinciden, tienen el mismo
contenido.

**Siempre fast-forward.** Un repositorio divergido (commits locales y remotos a la
vez) falla sin mezclar nada. Se resuelve a mano en ese repositorio.

**Contenido local pendiente.** Un commit local cuyo cambio ya está en el remoto con
otro hash (el original de un `cherry-pick`) no cuenta como pendiente. Si ningún
commit local aporta nada, el estado lo dice: `divergido (↑2 ↓8, sin contenido local
pendiente)`. Ese repositorio se realinea sin perder trabajo, pero la herramienta no
lo hace por su cuenta.

**Aviso automático.** `ws switch`, `ws cd` e `ws info` avisan en una línea si algún
repositorio va por detrás o no se ha podido comprobar:

```
⚠️  Entorno desactualizado: ~/.claude ↓3 → ws env sync
ℹ️  Entorno sin comprobar: .ai (sin respuesta del remoto en 5 s)
```

Para no pagar un fetch en cada cambio de workspace, el aviso reutiliza el último
fetch correcto mientras tenga menos de `WS_ENV_FETCH_TTL` segundos (300 por
defecto). La hora de ese fetch se guarda en `.git/ws-env-last-fetch` de cada
repositorio. Respeta `ws mode offline`, que se informa como «sin comprobar».

Los fetch no son interactivos: no piden contraseña ni confirmación. Cuando uno
falla, el aviso dice la causa: «el agente SSH no ha firmado» (un agente que necesita
aprobación manual, como Touch ID), «el servidor rechaza la clave SSH», «el nombre
del servidor no resuelve», «sin conexión con el servidor», «sin respuesta del
remoto en 5 s», entre otras.

**Sesiones vivas.** Un proceso ya arrancado no ve los cambios, o los ve a medias.
La herramienta no sabe qué procesos usan esos repositorios: se le dice con
`WS_ENV_BUSY_CMD`, una orden que imprime sus PID al principio de cada línea.

```bash
WS_ENV_BUSY_CMD="pgrep -x claude"
```

Si hay algo que actualizar y alguna sesión viva, `sync` lo avisa y pide
confirmación `[s/N]`. Sin terminal interactiva cancela, salvo con `--yes`. La
sesión que lanza la orden no cuenta, ni sus procesos padre. Sin
`WS_ENV_BUSY_CMD`, `sync` avisa de que no puede saberlo.

**Opciones:**
- `--no-fetch` (status): usa solo los datos locales
- `--yes`, `-y` (sync): actualiza aunque haya sesiones vivas
- `--sessions` (sync): lista las sesiones vivas con su línea de órdenes

**Ejemplos:**
```bash
ws env                      # estado del entorno
ws env status --no-fetch    # sin consultar los remotos
ws env sync                 # actualizar
ws env sync --sessions      # ver qué sesiones no verán los cambios
ws env sync --yes           # flujo desatendido
```

---

### ws mgmt-link

Muestra o cambia cómo llega un workspace al repositorio de gestión
`nuba-management`.

```bash
ws mgmt-link [--worktree|--symlink] [--force] [workspace]
```

Hay dos regímenes:

| Régimen        | Qué es                                      | Consecuencia                                                         |
|----------------|---------------------------------------------|----------------------------------------------------------------------|
| **propio**     | worktree de git en la rama `wt/<workspace>` | árbol e índice solo suyos: se commitea y publica con git normal       |
| **compartido** | symlink al clon principal                    | árbol e índice de todos: un commit sin `--` se lleva ficheros ajenos   |

El propio es el régimen actual. `ws new` lo monta así, y un workspace que aún use
el symlink se convierte solo la próxima vez que se entre en él con `ws cd`,
siempre que no haya procesos trabajando dentro: cambiarle el acceso a una sesión
en marcha le rompe el trabajo en curso. El symlink queda como salida cuando no
hay un clon del que colgar el worktree (sin `origin/main`, por ejemplo).

En cualquier comando, el régimen se reconoce así:

```bash
[ -L nuba-management ] && echo compartido || echo propio
```

**Vuelta atrás**: `--symlink` elimina el worktree, hace `git worktree prune` y
restituye el symlink. Avisa (y no hace nada) si el worktree tiene cambios sin
commitear o commits sin publicar; `--force` lo hace de todas formas. La rama
`wt/<workspace>` se conserva en el clon principal, así que los commits no se
pierden.

**Ejemplos:**
```bash
ws mgmt-link                                  # régimen del workspace actual
ws mgmt-link --worktree nuba-8926             # migrar a árbol propio
ws mgmt-link --symlink                        # vuelta atrás
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
- **ROADMAP.md** - Funcionalidades implementadas y futuras; vive en el repositorio de gestión, `nuba-management/implementations/workspace-tools/ROADMAP.md`
