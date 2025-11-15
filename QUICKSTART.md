# Inicio Rápido - Workspace Tools

## Instalación (5 minutos)

### 1. Colocar el repositorio

```bash
cd ~/wrkspc.nubarchiva/tools
# Si tienes el tarball:
tar -xzf workspace-tools.tar.gz
# O si clonas desde Git:
git clone <url> workspace-tools

cd workspace-tools
```

### 2. Instalar

```bash
./install.sh
```

Esto:
- Detecta automáticamente tu estructura
- Crea el directorio `workspaces/`
- Configura permisos de los scripts

### 3. Configurar en tu shell (RECOMENDADO)

Añade a tu `~/.bashrc` o `~/.zshrc`:

```bash
source ~/wrkspc.nubarchiva/tools/workspace-tools/setup.sh
```

Luego:
```bash
source ~/.bashrc  # o source ~/.zshrc
```

**Esto configura automáticamente:**
- Variable `WS_TOOLS`
- Comando `ws` en el PATH
- Función `ws cd` (cambia automáticamente de directorio)
- Autocompletado (bash o zsh según tu shell)

## Primer Uso (2 minutos)

### Crear tu primer workspace

```bash
# Crear workspace para feature
ws new test ks-nuba libs/marc4j

# O crear workspace en master/develop
ws new master ks-nuba
ws new develop ks-nuba libs/marc4j
```

### Ver lo que creaste

```bash
ws list
# o con abreviatura:
ws ls
```

### Cambiar al workspace

```bash
# Cambia automáticamente al directorio
ws cd test

# Con búsqueda parcial
ws cd te<TAB>  # autocompletado
```

### Estructura creada

```
~/wrkspc.nubarchiva/workspaces/test/
├── ks-nuba/              # branch: feature/test
└── libs/
    └── marc4j/           # branch: feature/test
```

### Trabajar en el workspace

```bash
# Ya estás en el workspace después de 'ws cd test'
# Abrir con Claude Code o tu editor
claude-code .
# o
code .
```

### Hacer cambios

```bash
cd ks-nuba
# ... hacer cambios ...
git commit -am "feat: mi cambio"
git push origin feature/test

cd ../libs/marc4j
# ... hacer cambios ...
git commit -am "feat: actualizar librería"
git push origin feature/test
```

### Limpiar cuando termines

```bash
ws clean test
# o con abreviatura:
ws rm test
```

## Comandos Esenciales

```bash
# Crear workspace
ws new <nombre> [repo1] [repo2]...
ws n <nombre> [repos...]              # abreviatura

# Ver todos los workspaces
ws list
ws ls                                  # abreviatura

# Cambiar a workspace
ws cd <nombre>                         # cambia automáticamente
ws cd <nombre parcial>                 # búsqueda parcial

# Ver detalle de uno
ws switch <nombre>

# Añadir repos
ws add <nombre> <repo1> [repo2]...
ws a <nombre> <repos...>               # abreviatura

# Limpiar
ws clean <nombre>
ws rm <nombre>                         # abreviatura
```

## Abreviaturas Soportadas

```bash
# Automáticas (cualquier prefijo único)
ws n test ks-nuba      # new
ws a test libs/marc4j  # add
ws l                   # list

# Predefinidas
ws ls                  # list
ws cd test             # switch + cambiar directorio
ws rm test             # clean
ws mk test ks-nuba     # new
```

## Búsqueda Parcial

No necesitas escribir el nombre completo:

```bash
ws cd nuba       # busca 'nuba' en workspaces
ws add fac ...   # busca 'fac' en workspaces
ws rm test       # busca 'test' en workspaces
```

Si hay múltiples coincidencias, se muestra un menú interactivo.

## Especificar Repos

Siempre usa la ruta completa desde `~/wrkspc.nubarchiva`:

```bash
# ✅ Correcto
ws new test ks-nuba              # Repo en raíz
ws new test libs/marc4j          # Repo en libs/
ws new test modules/docs         # Repo en modules/
ws new test tools/otro-tool      # Repo en tools/

# ❌ Incorrecto
ws new test marc4j    # Falta libs/
ws new test docs      # Falta modules/
```

## Casos de Uso Rápidos

### Solo código principal
```bash
ws new ui-update ks-nuba
```

### Código + librería
```bash
ws new marc-work ks-nuba libs/marc4j
```

### Solo librerías
```bash
ws new libs-upgrade libs/marc4j libs/dspace
```

### Full stack
```bash
ws new big-feature ks-nuba libs/marc4j modules/docs
```

### Incremental (añadir repos después)
```bash
ws new explore ks-nuba
ws add explore libs/marc4j
ws add explore modules/docs
```

### Workspace en master o develop
```bash
# Trabajar en master
ws new master ks-nuba libs/dspace
ws cd master
# ... hacer hotfix ...
ws clean master

# Trabajar en develop
ws new develop ks-nuba
ws cd develop
# ... integrar cambios ...
ws clean develop
```

## Autocompletado

Con `setup.sh` cargado, tienes autocompletado en todo:

```bash
ws <TAB>                    # subcomandos: new, add, switch, list, clean
ws new <TAB>                # master, develop, o nombre libre
ws new test <TAB>           # repos disponibles
ws cd <TAB>                 # workspaces existentes
ws add test <TAB>           # repos disponibles
```

## Siguiente Paso

Lee la documentación completa:
- `README.md` - Guía completa
- `EJEMPLOS.md` - 11 casos de uso detallados
- `CHEATSHEET.md` - Referencia rápida

## Ayuda

Todos los comandos tienen ayuda integrada:

```bash
ws                # Sin argumentos muestra ayuda
ws new            # Sin argumentos muestra ayuda
ws add            # Sin argumentos muestra ayuda
ws switch         # Sin argumentos lista workspaces
```

## Troubleshooting

### "Repo no encontrado"
Verifica la ruta:
```bash
cd ~/wrkspc.nubarchiva
ls libs/marc4j/.git   # Debe existir
```

### Ver todos los repos disponibles
```bash
cd ~/wrkspc.nubarchiva
find . -maxdepth 3 -name ".git" -type d | sed 's|/.git||' | sed 's|^\./||'
```

### Autocompletado no funciona
Verifica que hayas cargado setup.sh:
```bash
source ~/wrkspc.nubarchiva/tools/workspace-tools/setup.sh
```

O añádelo permanentemente a tu `~/.bashrc` o `~/.zshrc`.

---

¡Eso es todo! Ya puedes empezar a trabajar con workspaces. 🚀
