# Workspace Tools - Guía de Usuario

Guía completa para usar Workspace Tools: inicio rápido, referencia de comandos y ejemplos prácticos.

---

## 📚 Índice

1. [Inicio Rápido](#inicio-rápido) - Instalar y empezar en 5 minutos
2. [Referencia Rápida](#referencia-rápida) - Cheatsheet de comandos
3. [Ejemplos Prácticos](#ejemplos-prácticos) - Casos de uso reales

---

# Inicio Rápido

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
- Shortcuts: `wmcis`, `wmci`, `wscd`
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

### Navegar al workspace

```bash
# Cambiar al directorio del workspace (ambos hacen lo mismo con setup.sh)
ws cd test                      # cambia al workspace
ws switch test                  # cambia al workspace (equivalente)

# Ver estado del workspace actual
cd ~/workspaces/test/ks-nuba
ws .              # atajo ultra-corto
ws status         # equivalente

# Opción 4: Navegar entre repos (desde dentro del workspace)
wscd ks           # navega a ks-nuba
wscd libs         # navega a libs/marc4j (si coincide)
wscd .            # navega a raíz del workspace
```

### Trabajar en el workspace

```bash
# Abrir con tu editor
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
ws ls 8089                             # filtrar por patrón

# Ver estado del workspace actual
ws .                                   # atajo ultra-corto
ws status                              # desde dentro del workspace
ws status <nombre>                     # especificar workspace

# Ver información del workspace (sin cambiar directorio)
ws info <nombre>                       # muestra info completa

# Cambiar a workspace
ws cd <nombre>                         # cambia automáticamente
ws cd <nombre parcial>                 # búsqueda parcial

# Navegar entre repos (desde dentro del workspace)
wscd <patrón>                          # busca repo y navega
wscd                                   # menú de repos
wscd .                                 # raíz del workspace

# Ver detalle (equivalente a ws info, pero con cd funciona como ws cd)
ws switch <nombre>

# Renombrar workspace
ws rename <actual> <nuevo>
ws mv <actual> <nuevo>                 # alias

# Añadir repos
ws add <nombre> <repo1> [repo2]...
ws a <nombre> <repos...>               # abreviatura

# Eliminar repos de workspace
ws remove <nombre> <repo1> [repo2]...

# Ejecutar Maven en todos los repos
ws mvn <nombre> clean install
wmcis <nombre>                         # shortcut: clean install sin tests
wmci <nombre>                          # shortcut: clean install
wmis <nombre>                          # shortcut: install sin tests ni clean

# Ejecutar Git en todos los repos
ws git <nombre> status
wgt <nombre>                           # shortcut: status
wgpa <nombre>                          # shortcut: pull --all

# Limpiar
ws clean <nombre>
ws rm <nombre>                         # abreviatura
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

---

# Referencia Rápida

## Comandos Básicos

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
ws add fac libs/marc4j          # encuentra workspace con "fac"

# Abreviatura
ws a <nombre> <repos...>        # add
```

### Eliminar Repos
```bash
# Eliminar uno o varios repos del workspace
ws remove <nombre> ks-nuba
ws remove <nombre> libs/marc4j modules/docs

# Con verificaciones de seguridad (cambios pendientes, commits sin pushear)
```

### Navegación
```bash
# Ver info del workspace (SIN cambiar directorio)
ws info <nombre>
ws info fac                     # búsqueda parcial

# Cambiar al workspace
ws cd <nombre>
ws cd fac                       # búsqueda parcial

# Ver estado del workspace actual
ws .                            # atajo ultra-corto
ws status                       # equivalente
ws here                         # alias

# Navegar entre repos (desde dentro del workspace)
wscd ks                         # navega a repo que contiene "ks"
wscd                            # menú interactivo
wscd .                          # raíz del workspace
wscd ..                         # nivel arriba

# Ver detalle (equivalente a ws info, pero con cd funciona como ws cd)
ws switch <nombre>
```

### Renombrar
```bash
# Renombrar workspace completo
ws rename old-name new-name
ws mv old-name new-name         # alias

# Verificaciones exhaustivas:
# - Bloquea si hay cambios sin commitear
# - Advierte sobre commits sin pushear
# - Advierte sobre branches remotas
# - Confirmación explícita escribiendo "RENOMBRAR"
```

### Listar y Limpiar
```bash
# Listar todos
ws list
ws ls                           # abreviatura

# Filtrar workspaces
ws ls 8089                      # solo los que contienen "8089"
ws ls NUBA                      # solo los que contienen "NUBA"

# Limpiar workspace
ws clean <nombre>
ws clean fac                    # búsqueda parcial
ws rm <nombre>                  # abreviatura
ws del <nombre>                 # abreviatura
```

### Operaciones Multi-Repo
```bash
# Maven en todos los repos
ws mvn <nombre> clean install
ws mvn <nombre> test

# Git en todos los repos
ws git <nombre> status
ws git <nombre> pull --all
ws git <nombre> log --oneline -5
```

## Shortcuts

### Maven
```bash
wmcis <nombre>     # clean install -DskipTests
wmis <nombre>      # install -DskipTests (sin clean)
wmci <nombre>      # clean install
wmcl <nombre>      # clean

# Con auto-detección (desde dentro del workspace)
wmcis              # detecta workspace actual
wmci               # detecta workspace actual
```

### Git
```bash
wgt <nombre>       # git status en todos
wgpa <nombre>      # git pull --all en todos

# Con auto-detección
wgt                # detecta workspace actual
```

### Navegación
```bash
wscd <patrón>      # navega a repo con matching parcial
wscd               # menú interactivo de repos
wscd .             # raíz del workspace
wscd ..            # nivel arriba
```

## Abreviaturas de Comandos

```bash
# Automáticas (cualquier prefijo único)
ws n <nombre> <repos...>        # new
ws a <nombre> <repos...>        # add
ws l                            # list
ws c <nombre>                   # clean

# Predefinidas
ws ls                           # list
ws cd <nombre>                  # switch + cambiar directorio
ws rm <nombre>                  # clean
ws del <nombre>                 # clean
ws mv <old> <new>               # rename
ws mk <nombre> <repos...>       # new
ws .                            # status (actual workspace)
ws here                         # status (actual workspace)
```

## Búsqueda Parcial

Todos los comandos soportan coincidencia parcial case-insensitive:

```bash
ws cd nuba                      # busca 'nuba' en workspaces
ws add fac libs/marc4j          # busca 'fac' en workspaces
ws rm test                      # busca 'test' en workspaces
wscd marc                       # busca 'marc' en repos del workspace actual
```

Si hay múltiples coincidencias, se muestra un menú interactivo.

## Especificar Repos

Siempre usa rutas relativas desde la raíz:

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
ws . o ws status
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

---

# Ejemplos Prácticos

## Ejemplo 1: Feature Simple (Código + Librería)

**Contexto:** Actualizar integración MARC

```bash
# 1. Crear workspace
ws new marc-update ks-nuba libs/marc4j

# 2. Navegar
ws cd marc-update

# 3. Trabajar en código principal
cd ks-nuba
# ... hacer cambios ...
git commit -am "feat: Update MARC integration"
git push origin feature/marc-update

# 4. Trabajar en librería
cd ../libs/marc4j
# ... actualizar librería ...
git commit -am "feat: Support MARC 21 updates"
git push origin feature/marc-update

# 5. Verificar estado
ws .                            # ver estado completo

# 6. Limpiar
ws clean marc-update
```

## Ejemplo 2: Desarrollo Incremental

**Contexto:** No sabes qué repos necesitarás

```bash
# 1. Empezar con workspace vacío o mínimo
ws new explore ks-nuba

# 2. Trabajar y descubrir necesidad de librería
ws cd explore
# ... revisar código ...

# 3. Añadir librería
ws add explore libs/marc4j

# 4. Navegar entre repos fácilmente
wscd ks                         # ir a ks-nuba
wscd marc                       # ir a libs/marc4j
wscd .                          # ir a raíz

# 5. Descubrir necesidad de módulo
ws add explore modules/docs

# 6. Ver estructura final
ws status explore
```

## Ejemplo 3: Feature Solo con Librerías

**Contexto:** Actualizar varias librerías

```bash
# 1. Solo librerías
ws new libs-update libs/marc4j libs/dspace libs/foo-commonj

# 2. Navegar
ws cd libs-update

# 3. Estructura resultante:
# workspaces/libs-update/
# └── libs/
#     ├── marc4j/
#     ├── dspace/
#     └── foo-commonj/

# 4. Trabajar en todas
wscd marc                       # navega a libs/marc4j
# ... cambios ...
wscd dspace                     # navega a libs/dspace
# ... cambios ...

# 5. Commit y push en todas
ws git libs-update add .
ws git libs-update commit -m "feat: update libs"
ws git libs-update push origin feature/libs-update
```

## Ejemplo 4: Feature Completa (Multi-nivel)

**Contexto:** Gran feature que toca todo

```bash
# 1. Crear con todos los repos necesarios
ws new search-rewrite \
    ks-nuba \
    dga-commons \
    libs/marc4j \
    libs/foo-commonj \
    modules/metadata-entities \
    modules/docs

# 2. Ver estructura
ws status search-rewrite

# 3. Abrir todo con Claude Code
ws cd search-rewrite
claude-code .

# 4. Navegar entre repos
wscd ks                         # ks-nuba
wscd marc                       # libs/marc4j
wscd metadata                   # modules/metadata-entities
wscd .                          # raíz

# 5. Ejecutar Maven en todos
wmci search-rewrite            # o simplemente wmci (con auto-detección)

# 6. Ver estado de todos
ws .

# 7. Push en todos
ws git search-rewrite push origin feature/search-rewrite
```

## Ejemplo 5: Hotfix Urgente

**Contexto:** Bug crítico en librería

```bash
# 1. Crear workspace de master
ws new master libs/marc4j

# 2. Fix rápido
ws cd master
cd libs/marc4j
# ... hacer fix ...
git commit -am "fix: Critical MARC parsing bug"
git push origin master

# 3. Limpiar
ws clean master
```

## Ejemplo 6: Integración en Develop

**Contexto:** Integrar múltiples features

```bash
# 1. Crear workspace de develop
ws new develop \
    ks-nuba \
    dga-commons \
    libs/marc4j \
    modules/metadata-entities

# 2. Navegar
ws cd develop

# 3. Merge de features
wscd ks
git merge feature/search-rewrite
git merge feature/ui-update

wscd marc
git merge feature/marc-upgrade

# 4. Testing integral
ws .                            # ver estado

# 5. Ejecutar tests
wmci develop                    # Maven en todos

# 6. Push de todo
ws git develop push origin develop
```

## Ejemplo 7: Renombrar Workspace

**Contexto:** Cambiar nombre de workspace (ej: nuevo número de ticket)

```bash
# 1. Verificar estado actual
ws status old-name

# 2. Renombrar (con verificaciones exhaustivas)
ws rename old-name new-name

# El comando verifica:
# - ✅ Sin cambios sin commitear (bloqueante)
# - ⚠️  Commits sin pushear (warning)
# - ⚠️  Branches remotas (warning)
# - Pide confirmación escribiendo "RENOMBRAR"

# 3. Verificar resultado
ws status new-name

# 4. Tareas post-renombrado (si aplica):
# - Push commits locales
# - Reconfigurar tracking de branches remotas
```

## Ejemplo 8: Trabajar en Múltiples Features

**Contexto:** Varias features simultáneas

```bash
# Feature 1: Solo código principal
ws new ui-redesign ks-nuba

# Feature 2: Solo librerías
ws new libs-update libs/marc4j libs/dspace

# Feature 3: Código + librería específica
ws new marc-integration ks-nuba libs/marc4j

# Listar todo
ws ls

# Cambiar entre ellas
ws cd ui                        # búsqueda parcial → ui-redesign
ws cd libs                      # búsqueda parcial → libs-update
ws cd marc                      # búsqueda parcial → marc-integration

# Ver estado de cualquiera
ws status ui-redesign
ws status libs-update
```

## Ejemplo 9: Claude Code Optimizado

**Contexto:** Maximizar efectividad de IA

```bash
# 1. Crear workspace estructurado
ws new ai-cataloging \
    ks-nuba \
    libs/marc4j \
    modules/metadata-entities

# 2. Navegar y trabajar
ws cd ai-cataloging

# 3. Abrir con Claude Code
claude-code .
# Claude ve estructura clara con contexto
```

## Tips y Mejores Prácticas

### ✅ Hacer
- Usar rutas completas: `libs/marc4j`, no `marc4j`
- Usar `ws cd` para navegar automáticamente
- Usar `wscd` para navegar entre repos
- Usar búsqueda parcial para ahorrar tiempo
- Commitear antes de limpiar
- Usar `ws .` para ver estado rápido
- Usar shortcuts: `wmci`, `wgt`, `wscd`

### ❌ Evitar
- Usar solo nombre de repo sin path
- Eliminar directorios manualmente
- Trabajar en repos/ directamente
- Olvidar push antes de cleanup

## Listar Repos Disponibles

```bash
cd ~/wrkspc.nubarchiva

# Todo junto
find . -maxdepth 3 -name ".git" -type d | \
    sed 's|/.git||' | sed 's|^\./||' | sort

# Por nivel
echo "=== Raíz ==="
ls -d */.git 2>/dev/null | sed 's|/.git||'

echo "=== libs/ ==="
ls -d libs/*/.git 2>/dev/null | sed 's|/.git||'

echo "=== modules/ ==="
ls -d modules/*/.git 2>/dev/null | sed 's|/.git||'
```

---

## Ver También

- **README.md** - Documentación técnica completa
- **ROADMAP.md** - Mejoras planificadas
- **CHANGELOG.md** - Historial de cambios
