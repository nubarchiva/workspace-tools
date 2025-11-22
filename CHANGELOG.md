# Changelog

Todos los cambios notables en Workspace Tools se documentarán en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/),
y este proyecto adhiere a [Semantic Versioning](https://semver.org/lang/es/).

## [Unreleased]

### Añadido
- **Módulo `ws-git-utils.sh`** - Funciones de utilidad Git centralizadas
  - `git_has_uncommitted_changes()` - Verifica cambios sin commitear
  - `git_count_uncommitted_changes()` - Cuenta archivos modificados
  - `git_has_unpushed_commits()` - Verifica commits sin pushear
  - `git_count_unpushed_commits()` - Cuenta commits pendientes
  - `git_has_upstream()` - Verifica si tiene branch remota
  - `git_get_base_branch()` - Encuentra branch base (origin/develop, etc.)
  - `git_repo_status()` - Estado completo en formato parseable
  - Refactorizados para usar el módulo: ws-list, ws-switch, ws-clean, ws-remove
- **`ws sync`** - Sincroniza todos los repos con el remoto
  - `ws sync` - Pull en todos los repos del workspace actual
  - `ws sync --fetch` - Solo fetch (no merge)
  - `ws sync --rebase` - Pull con rebase
  - Auto-detección de workspace desde directorio actual
  - Salta repos con cambios sin commitear (no pierde trabajo)
- **`ws stash`** - Gestión coordinada de stash en todos los repos
  - `ws stash` / `ws stash push "mensaje"` - Stash en repos con cambios
  - `ws stash pop` - Pop del stash más reciente en todos los repos
  - `ws stash list` - Lista stashes de todos los repos
  - `ws stash clear` - Elimina todos los stashes (con confirmación)
  - `ws stash show [n]` - Muestra contenido del stash n
  - Auto-detección de workspace desde directorio actual
- **`ws templates`** - Gestión de templates de workspace (conjuntos predefinidos de repos)
  - `ws templates` / `ws templates list` - Lista templates disponibles
  - `ws templates add <nombre> <repos...>` - Crea o actualiza un template
  - `ws templates show <nombre>` - Muestra repos de un template
  - `ws templates remove <nombre>` - Elimina un template
  - Alias: `ws tpl`
  - Archivo de configuración: `$WORKSPACE_ROOT/.ws-templates`
- **`ws new --template`** - Crear workspace desde template
  - `ws new feature-123 --template frontend` - Usa repos del template
  - `ws new feature-123 -t backend libs/extra` - Template + repos adicionales
  - Combina repos del template con repos especificados (sin duplicados)
- **`ws grep`** - Búsqueda multi-repo de texto o patrones
  - `ws grep "patrón"` - Busca en todos los repos del workspace actual
  - `ws grep -i "todo" --type java` - Case-insensitive, solo archivos .java
  - Opciones: -i (case-insensitive), -l (solo archivos), -n (números de línea)
  - Opciones: -w (palabra completa), -E (regex extendida), --type <ext>
  - Auto-detección de workspace desde directorio actual
  - Shortcut: `wgrep`
- **CI con GitHub Actions** (`.github/workflows/ci.yml`)
  - Tests automatizados en Ubuntu y macOS
  - Análisis estático con ShellCheck
  - Ejecutado en push y pull requests a main/master/develop
- **`ws rename <actual> <nuevo>`** (alias: `ws mv`) - Renombra workspaces de forma segura
  - Verificaciones: bloquea si hay cambios sin commitear, advierte sobre commits sin pushear y branches remotas
  - Actualiza automáticamente worktrees (`git worktree repair`) y branches locales
  - Confirmación explícita escribiendo "RENOMBRAR" con resumen completo de cambios

### Cambiado
- **ws-rename refactorizado** para mejorar mantenibilidad
  - Dividido en funciones pequeñas con responsabilidad única
  - Usa `git_repo_status()` del módulo ws-git-utils.sh
  - Eliminado código duplicado (loop de verificación estaba duplicado)
  - Reducido de 466 a 438 líneas manteniendo toda la funcionalidad
  - Estructura clara: validación → verificación → resumen → ejecución
- **Manejo de errores estandarizado**: Uso consistente de `die()` para errores fatales
  - Scripts refactorizados: ws-mvn, ws-git, ws-clean, ws-remove, ws-rename
  - Simplifica el código: `die "mensaje"` en vez de `error "❌ mensaje"; exit 1`

### Corregido
- **ws-rename**: Salto de línea en mensaje de confirmación final
- **Quoting de variables**: Todas las asignaciones de paths ahora usan comillas dobles
  - `WORKSPACE_DIR="$WORKSPACES_DIR/$WORKSPACE_NAME"` (antes sin comillas)
  - Afecta: ws-new, ws-add, ws-switch, ws-mvn, ws-git, ws-clean, ws-remove, ws-repo-path
  - Previene problemas con nombres de directorios que contengan espacios

## [4.0.0] - 2025-11-25

### Añadido
- **Infraestructura de tests** con BATS (Bash Automated Testing System)
  - 67 tests cubriendo: ws-new, ws-add, ws-list, ws-clean, ws-common
  - Tests automatizados ejecutables con `./tests/run_tests.sh`
  - Test helpers reutilizables en `tests/test_helper.bash`
- **Archivo de configuración `~/.wsrc`**
  - Permite configurar `WORKSPACE_ROOT`, `WORKSPACES_DIR`, `WS_DEBUG`
  - Ejemplo en `config/wsrc.example`
  - Prioridad: env vars > .wsrc > derivada de WS_TOOLS > fallback
- Documentación de configuración en USER_GUIDE.md

### Cambiado
- **Refactoring mayor: inicialización centralizada**
  - Nuevo módulo `bin/ws-init.sh` centraliza toda la lógica de inicialización
  - Todos los scripts migrados para usar `source ws-init.sh`
  - Elimina ~15-20 líneas de boilerplate duplicado en cada script
  - Código más limpio y mantenible
- **`detect_current_workspace()`** ahora respeta `WORKSPACES_DIR` del entorno
  - Permite testing aislado de la función
  - Prioridad: WORKSPACES_DIR > WORKSPACE_ROOT > WS_TOOLS > fallback

### Corregido
- **ws-add**: `WORKSPACES_DIR` se usaba antes de definirse (bug silencioso)
- **Tests**: Normalización de paths para evitar doble slash con TMPDIR

## [3.2.0] - 2025-11-20

### Añadido
- **`wscd [patrón]`** - Navegación rápida entre repos del workspace actual
  - Matching parcial case-insensitive para encontrar repos
  - Menú interactivo si hay múltiples coincidencias o sin argumentos
  - `wscd .` navega a raíz del workspace
  - `wscd ..` navega un nivel arriba
  - Auto-detecta workspace desde cualquier directorio
- Documentación de `wscd` en README.md

### Corregido
- **wscd**: Menús interactivos ahora usan `/dev/tty` para mostrar inmediatamente
  - Antes: menú aparecía solo después de presionar enter (buffering)
  - Ahora: menú aparece instantáneamente con interacción directa

## [3.1.0] - 2025-11-20

### Añadido
- **Auto-detección de workspace** en `ws mvn`, `ws git`, `ws add`
  - Ejecuta comandos sin especificar workspace cuando estás dentro de uno
  - Ejemplos: `wmci`, `ws git status`, `ws add ks-nuba`
  - Sigue permitiendo especificación explícita para trabajar en otros workspaces
- **`ws status` / `ws .` / `ws here`** - Ver estado del workspace actual
  - Auto-detecta workspace sin necesidad de especificar nombre
  - No muestra README.md (solo en `ws switch`)
  - Rutas relativas en sugerencias de navegación (legibles vs absolutas)
- **ROADMAP.md** - Documento con mejoras planificadas y priorizadas
- **`wmis`** - Shortcut Maven para `install` sin `clean` ni tests

### Corregido
- **Auto-detección**: Asignar argumentos correctamente cuando `wmci`, `wmcis`, etc. se ejecutan sin workspace explícito
- **ws-status**: Rutas relativas vs absolutas (antes eran ilegibles)

## [3.0.0] - 2025-11-19

### Añadido
- **Sistema de colores** para mejorar legibilidad
  - Verde: éxito y confirmaciones
  - Rojo: errores
  - Amarillo: warnings
  - Cyan: nombres de workspaces/repos
  - Dim: información secundaria
  - Headers decorados con marcos
  - Soporte para terminales sin color (graceful degradation)
- **Filtro en `ws list`** - Lista workspaces con patrón de búsqueda
  - `ws ls 8089` - solo workspaces que contienen "8089"
  - Muestra contador: "Mostrando: X de Y workspaces"

### Corregido
- **ws-list, ws-remove**: Detección de commits sin pushear
  - Antes: repos sin upstream mostraban TODOS los commits históricos (falso positivo)
  - Ahora: compara contra `origin/develop`, `origin/master`, `develop`, o `master`
  - Solo cuenta commits únicos de la branch actual

## [2.1.0] - 2025-11-17 a 2025-11-19

### Añadido
- **`ws mvn <workspace> <args>`** - Ejecuta Maven en todos los repos del workspace
  - Busca `pom.xml` en cada repo
  - Ejecución paralela con `-T 1C`
  - Resumen de tiempos de ejecución por proyecto
  - Se detiene en primer error
  - Ignora repos sin `pom.xml`
- **Shortcuts Maven** para desarrollo rápido:
  - `wmcis <workspace>` - Clean install sin tests
  - `wmci <workspace>` - Clean install
  - `wmcl <workspace>` - Clean
- **`ws git <workspace> <comando>`** - Ejecuta Git en todos los repos
  - Ejecuta cualquier comando git en todos los repos
  - Muestra output separado por repo
  - Se detiene en primer error
- **Shortcuts Git**:
  - `wgt <workspace>` - Status en todos los repos
  - `wgpa <workspace>` - Pull all en todos los repos
- **`ws remove <workspace> <repo1> [repo2...]`** - Elimina repos de workspace
  - Verifica cambios sin commitear antes de eliminar
  - Verifica commits sin pushear
  - Elimina worktree de Git
  - Muestra warnings si hay cambios pendientes
- **Detección de commits pendientes** en `ws list`
  - Muestra ⚠️ si hay commits locales sin pushear
  - Detecta repos con commits pero sin branch remota

### Corregido
- **ws-list**: Detectar repos con commits locales pero sin branch remota configurada
- **ws-clean**: Ignorar archivos de configuración (README.md, .idea, .vscode, .kiro, .cursor, AI.md, .ai, docs) al verificar si workspace está vacío
  - Antes: workspaces sin repos no se eliminaban completamente
  - Ahora: se eliminan aunque tengan archivos de configuración

## [2.0.0] - 2025-11-16

### Añadido
- **setup.sh** - Script de inicialización con funciones de shell
  - Exporta `WS_TOOLS` para que scripts detecten su ubicación
  - Carga autocompletado para bash/zsh
  - Define shortcuts como funciones (no aliases)
- **Configuración IDE/AI** al crear workspaces
  - Copia `.idea/` (IntelliJ IDEA) al workspace
  - Symlinks a documentación AI: `AI.md`, `.ai/`, `docs/`
  - SSOT (Single Source of Truth) para documentación
  - Variable `CONFIG_REFERENCE_DIR` para personalizar origen
- **Alias `ws cd`** para `ws switch` con navegación automática
  - `ws cd <workspace>` cambia al directorio automáticamente

### Cambiado
- **BREAKING**: Sintaxis simplificada
  - Antes: `ws new features/nombre`
  - Ahora: `ws new nombre` (crea `feature/nombre` automáticamente)
  - `master` y `develop` usan esas branches directamente
  - Otros nombres crean `feature/<nombre>`
- **Workspace config**: Eliminada copia de `.kiro/` y `.vscode/`
  - Solo `.idea/` se copia (específico de sesión)
  - `.kiro/` y `.vscode/` mejor como symlinks globales

### Corregido
- **Compatibilidad bash/zsh** mejorada en todos los scripts
  - Arrays indexados correctamente (bash 0-based, zsh 1-based)
  - Detección de shell con `$BASH_SOURCE` vs `$0`
  - Variables expandidas correctamente en ambos shells
- **Autocompletado Zsh**: Corregido completado de comandos y workspaces
- **ws-clean**: Elimina workspaces vacíos incluso si solo queda `README.md`
- **ws-add, ws-clean**: Eliminado `set -e` para mejor manejo de errores
- **setup.sh**: Eliminar alias `ws` antes de definir función (evita conflictos)

## [1.0.0] - 2025-11-15

### Añadido
- **Scripts iniciales** de workspace management
  - `ws-new` - Crear workspaces con múltiples repos
  - `ws-add` - Añadir repos a workspace existente (soporte para múltiples repos)
  - `ws-list` - Listar workspaces activos con información de repos
  - `ws-switch` - Cambiar entre workspaces y mostrar su estado
  - `ws-clean` - Eliminar workspaces completos
- **Comando unificado `ws`** como dispatcher principal
  - Mapea subcomandos a scripts individuales
  - Función de ayuda integrada
  - Validación de subcomandos
- **Búsqueda parcial de workspaces** con selector interactivo
  - Matching case-insensitive
  - Menú numerado si hay múltiples coincidencias
  - Lista de workspaces disponibles si no hay coincidencias
- **Abreviaturas de comandos**
  - `ls` → `list`
  - `rm/del` → `clean`
  - `cd/sw` → `switch`
  - `mk/create` → `new`
  - Expansión automática por coincidencia parcial
- **Autocompletado** para bash y zsh
  - Completa comandos principales
  - Completa nombres de workspaces
  - Completa abreviaturas
- **Documentación completa**
  - README.md - Guía completa del proyecto
  - QUICKSTART.md - Inicio rápido
  - CHEATSHEET.md - Referencia rápida de comandos
  - EJEMPLOS.md - Casos de uso detallados

### Corregido
- **Instalación**: Ruta de `WORKSPACE_ROOT` correcta para crear workspaces en ubicación esperada

---

## Notas de versiones

### v3.x - UX y Productividad
Enfoque en experiencia de usuario y productividad diaria:
- Auto-detección para reducir fricción
- Sistema de colores para mejorar legibilidad
- Navegación rápida entre repos
- Comandos más cortos (`ws .`, `wscd`)

### v2.x - Operaciones Multi-Repo
Capacidades para trabajar con múltiples repos simultáneamente:
- Maven y Git en todos los repos
- Gestión de configuraciones IDE/AI
- Refactoring de sintaxis

### v1.x - Fundación
Scripts básicos y arquitectura inicial:
- Git worktrees para workspaces aislados
- Búsqueda parcial y selección interactiva
- Comando unificado `ws`

---

[Unreleased]: https://github.com/tu-usuario/workspace-tools/compare/v3.2.0...HEAD
[3.2.0]: https://github.com/tu-usuario/workspace-tools/compare/v3.1.0...v3.2.0
[3.1.0]: https://github.com/tu-usuario/workspace-tools/compare/v3.0.0...v3.1.0
[3.0.0]: https://github.com/tu-usuario/workspace-tools/compare/v2.1.0...v3.0.0
[2.1.0]: https://github.com/tu-usuario/workspace-tools/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/tu-usuario/workspace-tools/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/tu-usuario/workspace-tools/releases/tag/v1.0.0
