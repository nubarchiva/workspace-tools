# Workspace Tools

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Shell](https://img.shields.io/badge/Shell-Bash%20%7C%20Zsh-green.svg)](https://www.gnu.org/software/bash/)
[![Version](https://img.shields.io/badge/version-4.1.0-blue.svg)](CHANGELOG.md)

**Gestión de workspaces con Git worktrees para desarrollo paralelo en proyectos multi-repositorio.**

## El Problema

¿Trabajas con múltiples repositorios que forman parte del mismo proyecto? ¿Necesitas desarrollar features que tocan varios repos a la vez? ¿Cambias frecuentemente entre branches de diferentes tickets?

El flujo tradicional es tedioso:
```bash
cd repo1 && git checkout -b feature/ticket-123
cd ../repo2 && git checkout -b feature/ticket-123
cd ../libs/common && git checkout -b feature/ticket-123
# ... repetir para cada repo
```

Y peor aún, mantener múltiples features en paralelo requiere hacer checkout constantemente, perdiendo contexto y tiempo.

## La Solución

Workspace Tools usa **Git worktrees** para crear copias de trabajo aisladas de tus repos. Cada workspace es un directorio con todos los repos necesarios, cada uno en su propia branch.

```bash
# Crear workspace con 3 repos en un comando
ws new ticket-123 app backend libs/common

# Resultado: directorio aislado con los 3 repos en branch feature/ticket-123
# workspaces/ticket-123/
# ├── app/           → branch feature/ticket-123
# ├── backend/       → branch feature/ticket-123
# └── libs/common/   → branch feature/ticket-123
```

**Beneficios:**
- Múltiples features en paralelo sin conflictos
- Cambio instantáneo entre workspaces (sin git checkout)
- Compilar/testear todos los repos con un comando
- Sin duplicar repos (worktrees comparten el .git)

## Instalación

### Opción 1: Manual

```bash
# Clonar en tu directorio de herramientas
git clone https://github.com/tu-org/workspace-tools.git
cd workspace-tools
./install.sh

# Añadir a tu shell (~/.bashrc o ~/.zshrc)
source /ruta/a/workspace-tools/setup.sh
```

### Opción 2: Homebrew (macOS)

```bash
brew install --build-from-source ./Formula/workspace-tools.rb
```

### Configuración (opcional)

Crea `~/.wsrc` para personalizar rutas:

```bash
# Directorio raíz donde están tus repos
WORKSPACE_ROOT="$HOME/projects/my-project"
```

## Uso Rápido

```bash
# Crear workspace
ws new feature-123 app backend libs/common

# Listar workspaces
ws list

# Cambiar a workspace (cambia de directorio automáticamente)
ws cd feature-123

# Ver estado del workspace actual
ws .

# Añadir más repos
ws add feature-123 libs/utils

# Ejecutar comandos en todos los repos
ws git feature-123 status
ws mvn feature-123 clean install

# Sincronizar con remoto
ws sync

# Limpiar workspace
ws clean feature-123
```

## Comandos Principales

### Gestión de Workspaces

| Comando | Descripción |
|---------|-------------|
| `ws new <nombre> [repos...]` | Crear workspace |
| `ws list` / `ws ls` | Listar workspaces |
| `ws cd <nombre>` | Cambiar a workspace |
| `ws .` / `ws status` | Estado del workspace actual |
| `ws add <nombre> <repos...>` | Añadir repos |
| `ws remove <nombre> <repos...>` | Quitar repos |
| `ws rename <old> <new>` | Renombrar workspace |
| `ws clean <nombre>` | Eliminar workspace |

### Operaciones Multi-Repo

| Comando | Descripción |
|---------|-------------|
| `ws git <nombre> <cmd>` | Git en todos los repos |
| `ws mvn <nombre> <args>` | Maven en todos los repos |
| `ws sync [--fetch\|--rebase]` | Sincronizar con remoto |
| `ws stash [push\|pop\|list]` | Stash coordinado |
| `ws grep <patrón>` | Buscar en todos los repos |

### Templates

```bash
# Definir conjuntos de repos reutilizables
ws templates add frontend app libs/ui
ws templates add backend api libs/common

# Crear workspace desde template
ws new ticket-456 --template frontend
```

### Navegación

```bash
# Navegar entre repos del workspace actual
wscd app          # ir a repo "app"
wscd              # menú interactivo
wscd .            # raíz del workspace
```

## Shortcuts

| Shortcut | Equivalente |
|----------|-------------|
| `wmcis` | `ws mvn clean install -DskipTests` |
| `wmci` | `ws mvn clean install` |
| `wgt` | `ws git status` |
| `wsync` | `ws sync` |
| `wstash` | `ws stash` |
| `wgrep` | `ws grep` |

## Características

- **Aislamiento**: Cada workspace es independiente
- **Eficiencia**: Worktrees no duplican el repo completo
- **Multi-repo**: Opera en todos los repos con un comando
- **Búsqueda parcial**: `ws cd feat` encuentra `feature-123`
- **Auto-detección**: Detecta el workspace actual automáticamente
- **Templates**: Define conjuntos de repos reutilizables
- **Autocompletado**: Soporte para bash y zsh

## Estructura de Proyecto Soportada

```
~/project/                    # Tu proyecto (WORKSPACE_ROOT)
├── app/                      # Repo principal
├── backend/                  # Otro repo
├── libs/                     # Directorio de librerías
│   ├── common/               # Repo
│   └── utils/                # Repo
├── modules/                  # Directorio de módulos
│   └── api/                  # Repo
└── workspaces/               # Creado por workspace-tools
    ├── feature-123/          # Un workspace
    └── feature-456/          # Otro workspace
```

## Requisitos

| Componente | Versión mínima | Notas |
|------------|----------------|-------|
| **Bash** | 4.0+ | Requerido (los scripts usan `#!/bin/bash`) |
| **Git** | 2.15+ | Requerido para worktrees |
| **Zsh** | 5.0+ | Opcional, para usar como shell interactivo |
| **OS** | macOS / Linux | Windows no soportado |

**Nota sobre macOS:** macOS incluye Bash 3.2 por defecto (por licencia GPL). Para usar workspace-tools necesitas instalar Bash 4+:
```bash
brew install bash
```

La verificación de versiones se realiza automáticamente en `install.sh` y `setup.sh`.

## Documentación

- **[USER_GUIDE.md](USER_GUIDE.md)** - Referencia completa de comandos
- **[CHANGELOG.md](CHANGELOG.md)** - Historial de cambios
- **[ROADMAP.md](ROADMAP.md)** - Funcionalidades implementadas y futuras
- **[NUBARCHIVA.md](NUBARCHIVA.md)** - Ejemplos para proyecto nubarchiva

## Contribuir

Las contribuciones son bienvenidas:

1. Fork el repositorio
2. Crea una branch (`git checkout -b feature/nueva-funcionalidad`)
3. Commit con [Conventional Commits](https://www.conventionalcommits.org/)
4. Push y abre un Pull Request

## Licencia

[Apache License 2.0](LICENSE)

---

**Versión:** 4.1.0 | **Actualizado:** Noviembre 2025
