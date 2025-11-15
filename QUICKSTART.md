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

### 3. Configurar alias (opcional pero recomendado)

Añade a tu `~/.bashrc` o `~/.zshrc`:

```bash
export WS_TOOLS=~/wrkspc.nubarchiva/tools/workspace-tools

alias ws-new='$WS_TOOLS/bin/ws-new'
alias ws-add='$WS_TOOLS/bin/ws-add'
alias ws-list='$WS_TOOLS/bin/ws-list'
alias ws-switch='$WS_TOOLS/bin/ws-switch'
alias ws-clean='$WS_TOOLS/bin/ws-clean'
alias ws='cd ~/wrkspc.nubarchiva'
alias wsf='cd ~/wrkspc.nubarchiva/workspaces/features'
```

Luego:
```bash
source ~/.bashrc  # o source ~/.zshrc
```

## Primer Uso (2 minutos)

### Crear tu primera feature

```bash
# Con alias configurados:
ws-new feature test ks-nuba libs/marc4j

# Sin alias:
cd ~/wrkspc.nubarchiva/tools/workspace-tools
./bin/ws-new feature test ks-nuba libs/marc4j
```

### Ver lo que creaste

```bash
ws-list
# Verás: feature/test con 2 repos
```

### Trabajar en la feature

```bash
cd ~/wrkspc.nubarchiva/workspaces/features/test

# Estructura:
# ├── ks-nuba/
# └── libs/
#     └── marc4j/

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
ws-clean feature test
```

## Comandos Esenciales

```bash
# Crear workspace
ws-new feature <nombre> <repo1> [repo2] [repo3]...

# Ver todos los workspaces
ws-list

# Ver detalle de uno
ws-switch feature <nombre>

# Añadir repo
ws-add feature <nombre> <repo>

# Limpiar
ws-clean feature <nombre>
```

## Especificar Repos

Siempre usa la ruta completa desde `~/wrkspc.nubarchiva`:

```bash
# ✅ Correcto
ws-new feature test ks-nuba              # Repo en raíz
ws-new feature test libs/marc4j          # Repo en libs/
ws-new feature test modules/docs         # Repo en modules/
ws-new feature test tools/otro-tool      # Repo en tools/

# ❌ Incorrecto
ws-new feature test marc4j    # Falta libs/
ws-new feature test docs      # Falta modules/
```

## Casos de Uso Rápidos

### Solo código principal
```bash
ws-new feature ui-update ks-nuba
```

### Código + librería
```bash
ws-new feature marc-work ks-nuba libs/marc4j
```

### Solo librerías
```bash
ws-new feature libs-upgrade libs/marc4j libs/dspace
```

### Full stack
```bash
ws-new feature big-feature ks-nuba libs/marc4j modules/docs
```

### Incremental (añadir repos después)
```bash
ws-new feature explore ks-nuba
ws-add feature explore libs/marc4j
ws-add feature explore modules/docs
```

## Siguiente Paso

Lee la documentación completa:
- `README.md` - Guía completa
- `EJEMPLOS.md` - 11 casos de uso detallados
- `CHEATSHEET.md` - Referencia rápida

## Ayuda

Todos los comandos tienen ayuda integrada:

```bash
ws-new          # Sin argumentos muestra ayuda
ws-add          # Sin argumentos muestra ayuda
ws-switch       # Sin argumentos lista workspaces
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

---

¡Eso es todo! Ya puedes empezar a trabajar con workspaces. 🚀
