# Workspace Tools

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Shell](https://img.shields.io/badge/Shell-Bash%20%7C%20Zsh-green.svg)](https://www.gnu.org/software/bash/)

Sistema de gestión de workspaces con Git worktrees para desarrollo paralelo en múltiples repositorios.

## Características

- ✅ Workspaces aislados para master, develop y features
- ✅ Un cambio afecta a múltiples repos simultáneamente
- ✅ Soporte para repos en subdirectorios (`libs/*`, `modules/*`, `tools/*`)
- ✅ Ejecutar Maven/Git en todos los repos del workspace
- ✅ Añadir repos dinámicamente según necesites
- ✅ Múltiples features en paralelo sin conflictos
- ✅ Comando unificado con abreviaturas intuitivas
- ✅ Búsqueda parcial de workspaces
- ✅ Autocompletado inteligente (bash y zsh)
- ✅ `ws cd` cambia automáticamente de directorio
- ✅ Shortcuts para operaciones comunes (Maven, Git)

## Estructura de Workspace

```
~/workspace/                    # Tu directorio raíz (configurable)
├── repo1/                      # Repositorio Git
├── repo2/                      # Repositorio Git
├── libs/                       # Contenedor de repos
│   ├── lib1/                   # Repositorio Git
│   └── lib2/                   # Repositorio Git
├── modules/                    # Contenedor de repos
│   ├── module1/                # Repositorio Git
│   └── module2/                # Repositorio Git
├── tools/                      # Contenedor de repos
│   └── workspace-tools/        # Este repo
│       ├── bin/                # Scripts
│       ├── completions/        # Autocompletado
│       ├── setup.sh            # Configuración
│       └── README.md
└── workspaces/                 # Se crea automáticamente
    ├── master/
    ├── develop/
    └── feature-123/            # Ejemplo de workspace
```

## Instalación

### Paso 1: Clonar el repositorio

```bash
cd ~/workspace/tools  # o donde prefieras
git clone https://github.com/your-org/workspace-tools.git
cd workspace-tools
./install.sh
```

### Paso 2: Configurar tu Shell

Añade a tu `~/.bashrc` o `~/.zshrc`:

```bash
source ~/workspace/tools/workspace-tools/setup.sh
```

Después ejecuta:
```bash
source ~/.bashrc  # o source ~/.zshrc
```

**¿Qué hace setup.sh?**
- ✅ Exporta variable `WS_TOOLS`
- ✅ Añade `ws` al PATH
- ✅ Carga función `ws cd` (cambia automáticamente de directorio)
- ✅ Habilita autocompletado (bash o zsh según tu shell)
- ✅ Define shortcuts para Maven y Git

## Uso Rápido

```bash
# Crear workspace
ws new feature-123 repo1 libs/lib1

# Listar workspaces
ws list

# Cambiar a workspace (¡cambia automáticamente de directorio!)
ws cd feature-123

# Añadir repo a workspace
ws add feature-123 modules/module1

# Ejecutar Maven en todos los repos
ws mvn feature-123 clean install

# Ejecutar Git en todos los repos
ws git feature-123 status

# Limpiar workspace
ws clean feature-123
```

## Comandos Principales

### Gestión de Workspaces

| Comando | Descripción | Ejemplo |
|---------|-------------|---------|
| `ws new` | Crear workspace | `ws new feature-123 repo1 libs/lib1` |
| `ws add` | Añadir repo a workspace | `ws add feature-123 modules/module1` |
| `ws list` | Listar workspaces | `ws list` o `ws ls` |
| `ws switch` | Ver detalles de workspace | `ws switch feature-123` |
| `ws cd` | Cambiar a workspace | `ws cd feature-123` |
| `ws rename` | Renombrar workspace | `ws rename old-name new-name` o `ws mv old-name new-name` |
| `ws clean` | Limpiar workspace | `ws clean feature-123` o `ws rm feature-123` |

### Operaciones Multi-Repo

| Comando | Descripción | Ejemplo |
|---------|-------------|---------|
| `ws mvn` | Maven en todos los repos | `ws mvn feature-123 clean install` |
| `ws git` | Git en todos los repos | `ws git feature-123 status` |

### Shortcuts Maven

| Shortcut | Equivalente | Descripción |
|----------|------------|-------------|
| `wmcis <workspace>` | `ws mvn <workspace> -T 1C clean install -DskipTests=true -Denforcer.skip=true` | Clean install sin tests |
| `wmis <workspace>` | `ws mvn <workspace> -T 1C install -DskipTests=true -Denforcer.skip=true` | Install sin tests (sin clean) |
| `wmci <workspace>` | `ws mvn <workspace> -T 1C clean install` | Clean install |
| `wmcl <workspace>` | `ws mvn <workspace> -T 1C clean` | Clean |

### Shortcuts Git

| Shortcut | Equivalente | Descripción |
|----------|-------------|-------------|
| `wgt <workspace>` | `ws git <workspace> status` | Status en todos los repos |
| `wgpa <workspace>` | `ws git <workspace> pull --all` | Pull all en todos los repos |

### Shortcuts de Navegación

| Shortcut | Descripción | Ejemplo |
|----------|-------------|---------|
| `wscd [pattern]` | Navega a un repo del workspace actual con matching parcial | `wscd ks` → navega a ks-nuba |
| `wscd` | Sin argumentos: muestra menú de repos y navega al seleccionado | `wscd` → selecciona de lista |
| `wscd .` | Navega a la raíz del workspace | `wscd .` |

**Características:**
- Matching parcial case-insensitive: `wscd nuba` encuentra `ks-nuba`
- Menú de selección si hay múltiples coincidencias
- Auto-detecta el workspace actual
- Solo funciona desde dentro de un workspace

## Ejemplos de Uso

### Crear feature con múltiples repos

```bash
ws new feature-auth repo1 libs/auth modules/security

# Estructura creada:
# workspaces/feature-auth/
# ├── repo1/
# ├── libs/
# │   └── auth/
# └── modules/
#     └── security/
```

### Ejecutar Maven en todos los proyectos

```bash
# Compilar todos los proyectos
ws mvn feature-auth clean install

# O usar el shortcut
wmci feature-auth

# Con resumen de tiempos al final:
# ═══════════════════════════════════════════════════
# Resumen de ejecución:
# ═══════════════════════════════════════════════════
#   • repo1                                    45.2s
#   • libs/auth                                12.3s
#   • modules/security                         8.7s
# ───────────────────────────────────────────────────
#   Total: 66.2s
```

### Ver estado Git de todos los repos

```bash
# Ver status de todos los repos
ws git feature-auth status

# O usar el shortcut
wgt feature-auth

# Salida:
# ════════════════════════════════════════════════════
# ▶ repo1
# ════════════════════════════════════════════════════
# On branch feature/feature-auth
# nothing to commit, working tree clean
#
# ════════════════════════════════════════════════════
# ▶ libs/auth
# ════════════════════════════════════════════════════
# On branch feature/feature-auth
# Changes not staged for commit:
#   modified:   src/main/java/Auth.java
```

### Workflow típico

```bash
# 1. Crear feature
ws new api-redesign repo1 libs/api

# 2. Cambiar al workspace
ws cd api-redesign

# 3. Compilar y verificar
wmci api-redesign

# 4. Hacer cambios y compilar
# ... editar archivos ...
wmci api-redesign

# 5. Ver cambios en todos los repos
wgt api-redesign

# 6. Commitear en cada repo
cd repo1 && git commit -am "feat: new API design"
cd ../libs/api && git commit -am "feat: update API lib"

# 7. Push
ws git api-redesign push origin feature/api-redesign

# 8. Limpiar cuando termines
ws clean api-redesign
```

## Abreviaturas y Búsqueda Parcial

### Abreviaturas de comandos

```bash
# Automáticas (cualquier prefijo único)
ws n feature-123 repo1      # ws new
ws a feature-123 libs/lib1  # ws add
ws l                        # ws list

# Predefinidas
ws ls                       # ws list
ws cd feature-123           # ws switch
ws rm feature-123           # ws clean
```

### Búsqueda parcial de workspaces

No necesitas escribir el nombre completo:

```bash
ws cd fea       # busca 'fea' en workspaces
ws add auth ... # busca 'auth' en workspaces
```

Si hay múltiples coincidencias, se mostrará un menú interactivo.

## Branches

| Workspace | Branch Name | Descripción |
|-----------|------------|-------------|
| `master` | `master` | Usa branch existente |
| `develop` | `develop` | Usa branch existente |
| Otros (ej: `feature-123`) | `feature/feature-123` | Crea branch automáticamente |

## Configuración Avanzada

### Personalizar el directorio raíz

Por defecto, se detecta automáticamente desde `WS_TOOLS`. Para especificar un directorio diferente:

```bash
# En setup.sh o tu shell rc
export WS_TOOLS=~/my-custom-workspace/tools/workspace-tools
```

### Copiar configuraciones al crear workspaces

El sistema copia automáticamente configuraciones de IDE/AI al crear workspaces:
- `.idea/` (IntelliJ IDEA)
- `.cursor/` (Cursor AI)
- Symlinks a `AI.md`, `.ai/`, `docs/`

## Compatibilidad

- **Bash** 4.0+
- **Zsh** 5.0+
- **macOS** y **Linux**

## Documentación Adicional

- **[USER_GUIDE.md](USER_GUIDE.md)** - Guía de usuario completa (inicio rápido, referencia, ejemplos)

## Contribuir

Las contribuciones son bienvenidas. Por favor:

1. Fork el repositorio
2. Crea una branch para tu feature (`git checkout -b feature/amazing-feature`)
3. Commit tus cambios (`git commit -m 'feat: add amazing feature'`)
4. Push a la branch (`git push origin feature/amazing-feature`)
5. Abre un Pull Request

### Convenciones de commits

Usamos [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: nueva funcionalidad
fix: corrección de bug
docs: cambios en documentación
refactor: refactorización de código
test: añadir o modificar tests
chore: tareas de mantenimiento
```

## Licencia

Este proyecto está licenciado bajo la Licencia Apache 2.0 - ver el archivo [LICENSE](LICENSE) para más detalles.

---

**Versión:** 3.0
**Fecha:** 19 de noviembre de 2025
