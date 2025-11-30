# Workspace Tools para Nubarchiva

Guía específica de uso de Workspace Tools para el proyecto Nubarchiva.

---

## Configuración Recomendada

### 1. Ubicación de la Herramienta

```
~/wrkspc.nubarchiva/
├── nuba-oss/                     # Repo principal
├── libs/commons/                 # Utilidades comunes
├── libs/                         # Librerías
│   ├── marc4j/
│   ├── dspace/
│   └── foo-commonj/
├── modules/                      # Módulos
│   ├── diffusion-portal/
│   ├── metadata-entities/
│   └── docs/
├── tools/                        # Herramientas
│   └── workspace-tools/          # Esta herramienta
└── workspaces/                   # Workspaces (creado automáticamente)
```

### 2. Configuración del Shell

Añade a tu `~/.bashrc` o `~/.zshrc`:

```bash
source ~/wrkspc.nubarchiva/tools/workspace-tools/setup.sh
```

### 3. Archivo ~/.wsrc (opcional)

Si tu directorio es diferente, crea `~/.wsrc`:

```bash
WORKSPACE_ROOT="$HOME/wrkspc.nubarchiva"
```

---

## Repos Disponibles

### Raíz
- `nuba-oss` - Aplicación principal

### Librerías (libs/)
- `libs/commons` - Utilidades compartidas
- `libs/marc4j` - Procesamiento MARC21
- `libs/dspace` - Integración DSpace
- `libs/foo-commonj` - Utilidades Java

### Módulos (modules/)
- `modules/diffusion-portal` - Portal de difusión
- `modules/metadata-entities` - Entidades de metadatos
- `modules/docs` - Documentación

---

## Templates Recomendados

Configura estos templates para agilizar la creación de workspaces:

```bash
# Template para desarrollo frontend (portal + UI)
ws templates add frontend nuba-oss modules/diffusion-portal

# Template para desarrollo backend (core + commons)
ws templates add backend nuba-oss libs/commons libs/foo-commonj

# Template para trabajo con MARC
ws templates add marc nuba-oss libs/marc4j modules/metadata-entities

# Template completo (desarrollo full-stack)
ws templates add full nuba-oss libs/commons libs/marc4j modules/diffusion-portal

# Ver templates configurados
ws templates
```

---

## Orden de Compilación

Crea el archivo `~/wrkspc.nubarchiva/.ws-build-order` con el orden de dependencias:

```
libs/commons
libs/foo-commonj
libs/marc4j
libs/dspace
modules/metadata-entities
nuba-oss
modules/diffusion-portal
modules/docs
```

Este orden garantiza que las dependencias se compilan antes que los módulos que las usan.

---

## Casos de Uso Frecuentes

### Feature en nuba-oss + librería

```bash
# Crear workspace
ws new NUBA-1234 nuba-oss libs/marc4j

# Cambiar al workspace
ws cd NUBA-1234

# Trabajar
cd nuba-oss
# ... hacer cambios ...
git commit -am "feat(NUBA-1234): actualizar procesamiento MARC"

cd ../libs/marc4j
# ... hacer cambios ...
git commit -am "feat(NUBA-1234): nuevo parser MARC21"

# Compilar todo
wmci NUBA-1234

# Push
ws git NUBA-1234 push origin feature/NUBA-1234

# Limpiar cuando termine
ws clean NUBA-1234
```

### Hotfix urgente en master

```bash
# Crear workspace de master
ws new master nuba-oss libs/marc4j

# Cambiar y arreglar
ws cd master
cd nuba-oss
# ... fix ...
git commit -am "fix: corregir parsing de campos 856"
git push origin master

# Limpiar
ws clean master
```

### Desarrollo de portal de difusión

```bash
# Usar template frontend
ws new NUBA-5678 --template frontend

# O crear manualmente
ws new NUBA-5678 nuba-oss modules/diffusion-portal

# Navegar entre repos
ws cd NUBA-5678
wscd nuba                  # ir a nuba-oss
wscd portal                # ir a modules/diffusion-portal
wscd .                     # ir a raíz

# Compilar
wmcis NUBA-5678            # sin tests para desarrollo rápido
wmci NUBA-5678             # con tests antes de push
```

### Trabajo con múltiples librerías

```bash
# Crear workspace con varias libs
ws new libs-update libs/marc4j libs/dspace libs/foo-commonj

# Trabajar
ws cd libs-update
wscd marc                  # ir a libs/marc4j
wscd dspace                # ir a libs/dspace
wscd foo                   # ir a libs/foo-commonj

# Ver estado de todo
ws .

# Compilar en orden correcto
wmci libs-update
```

### Integración en develop

```bash
# Workspace de develop con repos principales
ws new develop nuba-oss libs/commons libs/marc4j modules/metadata-entities

# Cambiar
ws cd develop

# Merge de features
wscd nuba
git merge feature/NUBA-1234
git merge feature/NUBA-5678

wscd marc
git merge feature/NUBA-1234

# Compilar y verificar
wmci develop

# Push
ws git develop push origin develop
```

### Actualizar repos origen

```bash
# Al empezar el día, actualizar todos los repos origen (develop/master)
ws origins git pull        # pull en todos los repos origen

# Ver estado de los repos origen
ws origins git status
```

### Actualizar workspace con develop

```bash
# Actualizar tu workspace con lo último de develop
ws cd NUBA-1234
ws update                  # merge develop en todos los repos

# O con rebase para historial limpio
ws update --rebase
```

### Cambio rápido de contexto

```bash
# Estás en NUBA-1234 con cambios sin commitear
# Necesitas cambiar urgente a NUBA-9999

# Guardar trabajo actual
ws stash push "WIP: implementando búsqueda"

# Cambiar al otro workspace
ws cd NUBA-9999
# ... resolver urgencia ...

# Volver y recuperar trabajo
ws cd NUBA-1234
ws stash pop
```

### Buscar código en el workspace

```bash
# Buscar todas las referencias a una clase
ws grep "MarcRecordParser"

# Buscar TODOs en archivos Java
ws grep -i "TODO" --type java

# Buscar uso de método deprecated
ws grep "oldMethod" -l              # solo archivos
```

---

## Workflows por Tipo de Tarea

### Bug Fix Simple

```bash
ws new NUBA-XXX nuba-oss
ws cd NUBA-XXX
# fix, commit, push
ws clean NUBA-XXX
```

### Feature Multi-Repo

```bash
ws new NUBA-XXX --template full
ws cd NUBA-XXX
# desarrollo iterativo
wmcis                      # compilar rápido (sin tests)
# cuando esté listo
wmci                       # compilar con tests
ws git NUBA-XXX push origin feature/NUBA-XXX
ws clean NUBA-XXX
```

### Actualización de Librería

```bash
ws new NUBA-XXX libs/marc4j nuba-oss
ws cd NUBA-XXX
# actualizar lib primero
cd libs/marc4j
# ... cambios ...
git commit -am "feat: nueva funcionalidad"
# luego actualizar consumidor
wscd nuba
# ... adaptar código ...
git commit -am "feat: usar nueva funcionalidad de marc4j"
wmci NUBA-XXX
```

### Revisión de PR

```bash
# Crear workspace con la branch del PR
ws new review-PR-123 nuba-oss libs/marc4j
ws cd review-PR-123

# Cambiar a la branch del PR
ws git review-PR-123 checkout feature/NUBA-XXX

# Compilar y probar
wmci review-PR-123

# Limpiar después de revisar
ws clean review-PR-123
```

---

## Shortcuts Útiles

| Comando | Descripción |
|---------|-------------|
| `ws ls NUBA` | Listar workspaces de tickets NUBA |
| `ws .` | Ver estado del workspace actual |
| `wscd nuba` | Ir a nuba-oss |
| `wscd marc` | Ir a libs/marc4j |
| `wmcis` | Compilar rápido (sin tests) |
| `wmci` | Compilar completo |
| `wgt` | Git status en todos los repos |
| `ws origins git pull` | Actualizar repos origen |
| `ws update` | Actualizar workspace con develop |
| `wstash` | Guardar cambios temporalmente |
| `wgrep "texto"` | Buscar en todos los repos |

---

## Tips

### Nombres de Workspace

Usa el número de ticket Jira como nombre:
```bash
ws new NUBA-1234 nuba-oss libs/marc4j
```

Esto facilita:
- Identificar el workspace por ticket
- La branch se crea como `feature/NUBA-1234`
- Búsqueda parcial: `ws cd 1234`

### Compilación Incremental

Durante desarrollo, usa `wmcis` (sin tests) para compilación rápida:
```bash
wmcis                      # rápido, para desarrollo
wmci                       # completo, antes de push
```

### Navegación Rápida

Desde cualquier repo del workspace:
```bash
wscd .                     # ir a raíz
wscd nuba                  # ir a nuba-oss
wscd                       # menú interactivo
```

### Ver Estado Rápido

```bash
ws .                       # estado completo
wgt                        # solo git status
```

### Antes de Hacer Push

```bash
ws update                  # actualizar con develop
ws .                       # verificar estado
wmci                       # compilar con tests
ws git NUBA-XXX push origin feature/NUBA-XXX
```

---

## Ver También

- **[README.md](README.md)** - Introducción general
- **[USER_GUIDE.md](USER_GUIDE.md)** - Referencia completa de comandos
- **[CHANGELOG.md](CHANGELOG.md)** - Historial de cambios
