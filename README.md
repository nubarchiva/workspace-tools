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
│       ├── completions/       # Autocompletado
│       ├── setup.sh           # Configuración
│       └── README.md
└── workspaces/                 # Se crea automáticamente
    ├── master/
    ├── develop/
    └── nuba-8400/             # Ejemplo de workspace
```

## Instalación

### Paso 1: Obtener Workspace Tools

#### Opción 1: Como Repositorio Git (Recomendado)

```bash
cd ~/wrkspc.nubarchiva/tools
git clone <url-del-repo> workspace-tools
cd workspace-tools
./install.sh
```

#### Opción 2: Extraer desde Tarball

```bash
cd ~/wrkspc.nubarchiva/tools
tar -xzf workspace-tools.tar.gz
cd workspace-tools
./install.sh
```

### Paso 2: Configurar tu Shell

Añade a tu `~/.bashrc` o `~/.zshrc`:

```bash
source ~/wrkspc.nubarchiva/tools/workspace-tools/setup.sh
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

## Uso Rápido

Con `setup.sh` cargado, usa `ws` desde cualquier lugar:

```bash
# Crear workspace
ws new nuba-8400 ks-nuba libs/marc4j

# Listar workspaces
ws list

# Cambiar a workspace (¡cambia automáticamente de directorio!)
ws cd nuba-8400

# Añadir repo a workspace
ws add nuba-8400 modules/docs

# Limpiar workspace
ws clean nuba-8400
```

### Abreviaturas Soportadas

```bash
# Automáticas (cualquier prefijo único)
ws n nuba-8400 ks-nuba      # ws new
ws a nuba-8400 libs/marc4j  # ws add
ws l                         # ws list

# Predefinidas
ws ls                        # ws list
ws cd nuba-8400              # ws switch (cambia directorio)
ws rm nuba-8400              # ws clean
ws mk test ks-nuba           # ws new
```

### Búsqueda Parcial

No necesitas escribir el nombre completo del workspace:

```bash
ws cd nuba       # busca 'nuba' en workspaces
ws add fac ...   # busca 'fac' en workspaces
ws rm test       # busca 'test' en workspaces
```

Si hay múltiples coincidencias, se mostrará un menú interactivo para seleccionar.

## Características

- ✅ Workspaces aislados para master, develop y features
- ✅ Un cambio afecta a múltiples repos simultáneamente
- ✅ Soporte para repos en subdirectorios (`libs/*`, `modules/*`, `tools/*`)
- ✅ Añadir repos dinámicamente según necesites
- ✅ Múltiples features en paralelo sin conflictos
- ✅ Comando unificado con abreviaturas intuitivas
- ✅ Búsqueda parcial de workspaces
- ✅ Autocompletado inteligente (bash y zsh)
- ✅ `ws cd` cambia automáticamente de directorio
- ✅ Optimizado para herramientas de AI (Claude Code, etc.)

## Comandos

### ws new

Crea un nuevo workspace.

```bash
# Sintaxis
ws new <nombre> [repo1] [repo2] ...

# Nombres especiales: master, develop
# Otros nombres crean workspace en branch feature/<nombre>

# Ejemplos
ws new nuba-8400 ks-nuba                        # feature/nuba-8400
ws new nuba-8400 ks-nuba libs/marc4j modules/docs
ws new master ks-nuba libs/dspace               # branch master
ws new develop                                   # branch develop
```

### ws add

Añade uno o más repos a un workspace existente.

```bash
# Sintaxis
ws add <nombre|patrón> <repo1> [repo2] [repo3] ...

# Ejemplos
ws add nuba-8400 libs/marc4j
ws add nuba-8400 dga-commons libs/marc4j modules/docs    # múltiples repos
ws add nuba libs/marc4j                                   # búsqueda parcial
ws add master tools/workspace-tools
```

### ws list

Lista todos los workspaces activos con su estado.

```bash
ws list
# o con abreviatura
ws ls
```

### ws switch (ws cd)

Muestra información detallada de un workspace y opcionalmente cambia a él.

```bash
# Ver workspaces disponibles
ws switch

# Ver detalle de uno específico
ws switch nuba-8400
ws switch nuba                    # búsqueda parcial

# Cambiar al workspace (¡cambia el directorio!)
ws cd nuba-8400                   # equivalente a ws switch + cd automático
ws cd nuba                        # con búsqueda parcial
```

💡 **Diferencia entre `ws switch` y `ws cd`:**
- `ws switch` muestra información del workspace
- `ws cd` muestra información Y cambia automáticamente al directorio

### ws clean (ws rm)

Limpia un workspace (elimina worktrees, mantiene branches).

```bash
ws clean nuba-8400
ws clean nuba                     # búsqueda parcial
ws rm nuba-8400                   # con alias
ws clean master
ws clean develop
```

⚠️ **Este comando:**
- Elimina los directorios de worktree
- Mantiene las branches en los repos principales
- NO elimina commits ni cambios commiteados

## Especificar Repos

**Siempre usa rutas relativas desde `~/wrkspc.nubarchiva`:**

```bash
# ✅ Correcto
ws new test ks-nuba                    # Repo en raíz
ws new test libs/marc4j                # Repo en libs/
ws new test modules/docs               # Repo en modules/
ws new test tools/workspace-tools      # Repo en tools/

# ❌ Incorrecto
ws new test marc4j      # Falta "libs/"
ws new test docs        # Falta "modules/"
```

## Estructura de Workspaces

Los workspaces mantienen la jerarquía de subdirectorios:

```
workspaces/nuba-8400/
├── ks-nuba/                    # Worktree → feature/nuba-8400
├── libs/
│   ├── marc4j/                # Worktree → feature/nuba-8400
│   └── dspace/                # Worktree → feature/nuba-8400
├── modules/
│   └── docs/                  # Worktree → feature/nuba-8400
└── tools/
    └── otro-tool/             # Worktree → feature/nuba-8400
```

## Branches

| Workspace | Branch Name | Creación |
|-----------|------------|----------|
| `master` | `master` | Usa branch existente |
| `develop` | `develop` | Usa branch existente |
| Otros (ej: `nuba-8400`) | `feature/nuba-8400` | Crea branch automáticamente |

## Ejemplos

### Feature con múltiples repos

```bash
ws new marc-upgrade ks-nuba libs/marc4j modules/metadata-entities

# Estructura creada:
# workspaces/marc-upgrade/
# ├── ks-nuba/
# ├── libs/
# │   └── marc4j/
# └── modules/
#     └── metadata-entities/
```

### Feature incremental

```bash
# Empezar con un repo
ws new explore ks-nuba

# Añadir según necesites
ws add explore libs/marc4j
ws add explore modules/docs
```

### Hotfix en librería

```bash
ws new master libs/marc4j
ws cd master
cd libs/marc4j
# hacer fix...
git commit -am "fix: critical bug"
git push origin master
cd ~
ws clean master
```

## Workflow Típico

```bash
# 1. Crear feature con los repos necesarios
ws new nueva-busqueda ks-nuba libs/marc4j

# 2. Cambiar al workspace
ws cd nueva-busqueda

# 3. Abrir con tu editor
claude-code .  # o tu editor preferido

# 4. Hacer commits en cada repo
cd ks-nuba
git commit -am "feat: implement search"

cd ../libs/marc4j
git commit -am "feat: extend MARC parser"

# 5. Push
cd ks-nuba && git push origin feature/nueva-busqueda
cd ../libs/marc4j && git push origin feature/nueva-busqueda

# 6. Limpiar cuando termines
ws clean nueva-busqueda
```

## Integración con AI Tools

### Claude Code

```bash
# Todo el workspace
ws cd mi-feature
claude-code .

# Un repo específico
ws cd mi-feature
cd libs/marc4j
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
ws list
# o
cd ~/wrkspc.nubarchiva/workspaces
tree -L 3
```

### Desinstalar

Elimina la línea de `~/.bashrc` o `~/.zshrc`:

```bash
# Elimina esto:
source ~/wrkspc.nubarchiva/tools/workspace-tools/setup.sh
```

Después ejecuta `source ~/.bashrc` (o `~/.zshrc`).

## Actualizar

Si este repo tiene actualizaciones:

```bash
cd ~/wrkspc.nubarchiva/tools/workspace-tools
git pull
```

## Compatibilidad con Versión Anterior

Los scripts individuales siguen funcionando para compatibilidad:

```bash
# En lugar de:
ws new test ks-nuba

# Puedes usar:
ws-new test ks-nuba

# Pero requieren que hayas cargado setup.sh o configurado el PATH manualmente
```

## Documentación Adicional

- **QUICKSTART.md** - Guía de inicio rápido
- **EJEMPLOS.md** - 11 casos de uso detallados paso a paso
- **CHEATSHEET.md** - Referencia rápida de comandos

## Licencia

Uso interno para el proyecto NubArchiva.

---

**Versión:** 2.2
**Fecha:** 16 de noviembre de 2025
**Autor:** José Antonio
