# Ejemplos Prácticos - Con Soporte para Subdirectorios

Este documento contiene casos de uso reales considerando repos en subdirectorios (`libs/*`, `modules/*`).

## Caso 1: Feature con Repos en Múltiples Niveles

### Contexto
Vas a actualizar la integración MARC que requiere cambios en:
- `ks-nuba` (código principal - raíz)
- `libs/marc4j` (librería MARC - subdirectorio)
- `modules/metadata-entities` (entidades de metadatos - subdirectorio)

### Pasos

```bash
# 1. Crear workspace especificando rutas completas
cd ~/wrkspc.nubarchiva
./tools/new-workspace.sh feature marc-upgrade ks-nuba libs/marc4j modules/metadata-entities

# 2. Verificar estructura creada
cd workspaces/features/marc-upgrade
tree -L 2

# Output:
# .
# ├── ks-nuba/
# ├── libs/
# │   └── marc4j/
# └── modules/
#     └── metadata-entities/

# 3. Trabajar en cada repo
cd ks-nuba
# hacer cambios...
git commit -am "feat: Update MARC integration"

cd ../libs/marc4j
# actualizar librería...
git commit -am "feat: Support MARC 21 updates"

cd ../../modules/metadata-entities
# actualizar entidades...
git commit -am "feat: New MARC entity fields"

# 4. Push de cada repo
cd ~/wrkspc.nubarchiva/workspaces/features/marc-upgrade
for dir in ks-nuba libs/marc4j modules/metadata-entities; do
    cd $dir
    git push origin feature/marc-upgrade
    cd -
done

# 5. Limpiar cuando termines
cd ~/wrkspc.nubarchiva
./tools/cleanup-workspace.sh feature marc-upgrade
```

## Caso 2: Añadir Repo en Subdirectorio Durante Desarrollo

### Contexto
Empezaste trabajando en `ks-nuba` pero descubriste que necesitas actualizar `libs/marc4j`

### Pasos

```bash
# 1. Ya tienes el workspace con ks-nuba
cd ~/wrkspc.nubarchiva
./tools/new-workspace.sh feature quick-fix ks-nuba

# 2. Te das cuenta que necesitas libs/marc4j
./tools/add-repo.sh feature quick-fix libs/marc4j

# 3. Verificar estructura
cd workspaces/features/quick-fix
ls -la
# ks-nuba/
# libs/

tree libs
# libs/
# └── marc4j/

# 4. Ahora trabajas en ambos repos
cd libs/marc4j
# hacer cambios...
```

## Caso 3: Feature Solo con Librerías

### Contexto
Actualizar varias librerías en `libs/` sin tocar código principal

### Pasos

```bash
# Solo trabajar en librerías
./tools/new-workspace.sh feature libs-update libs/marc4j libs/dspace libs/foo-commonj

# Estructura resultante:
# workspaces/features/libs-update/
# └── libs/
#     ├── marc4j/
#     ├── dspace/
#     └── foo-commonj/

cd workspaces/features/libs-update/libs
# Todos los repos de librerías en un solo lugar
```

## Caso 4: Feature Solo con Módulos

### Contexto
Trabajar en la documentación y el portal de difusión

### Pasos

```bash
# Solo módulos
./tools/new-workspace.sh feature docs-update modules/docs modules/diffusion-portal

# Estructura:
# workspaces/features/docs-update/
# └── modules/
#     ├── docs/
#     └── diffusion-portal/

cd workspaces/features/docs-update/modules
ls -la
# docs/
# diffusion-portal/
```

## Caso 5: Feature Completa - Todos los Niveles

### Contexto
Gran feature que toca todo: código principal, librerías y módulos

### Pasos

```bash
# Especificar todos los repos necesarios
./tools/new-workspace.sh feature search-rewrite \
    ks-nuba \
    dga-commons \
    libs/marc4j \
    libs/foo-commonj \
    modules/metadata-entities \
    modules/docs

# Estructura completa:
# workspaces/features/search-rewrite/
# ├── ks-nuba/
# ├── dga-commons/
# ├── libs/
# │   ├── marc4j/
# │   └── foo-commonj/
# └── modules/
#     ├── metadata-entities/
#     └── docs/

# Abrir todo el workspace con Claude Code
cd workspaces/features/search-rewrite
claude-code .
```

## Caso 6: Master con Hotfix en Librería

### Contexto
Bug crítico en `libs/marc4j` que necesita fix inmediato

### Pasos

```bash
# Crear workspace de master solo con la librería afectada
./tools/new-workspace.sh master libs/marc4j

# Fix rápido
cd workspaces/master/libs/marc4j
# ... hacer fix ...
git commit -am "fix: Critical MARC parsing bug"
git push origin master

# Limpiar
cd ~/wrkspc.nubarchiva
./tools/cleanup-workspace.sh master ""
```

## Caso 7: Develop - Integración Completa

### Contexto
Integrar múltiples features antes de release, incluyendo cambios en librerías

### Pasos

```bash
# Crear workspace de develop con todos los repos relevantes
./tools/new-workspace.sh develop \
    ks-nuba \
    dga-commons \
    libs/marc4j \
    libs/dspace \
    modules/metadata-entities

# Merge de features en cada repo
cd workspaces/develop/ks-nuba
git merge feature/search-rewrite
git merge feature/ui-update

cd ../libs/marc4j
git merge feature/marc-upgrade

cd ../../modules/metadata-entities
git merge feature/entity-update

# Testing integral
cd ~/wrkspc.nubarchiva/workspaces/develop
# Probar todo junto...

# Push de todo
for dir in ks-nuba dga-commons libs/marc4j libs/dspace modules/metadata-entities; do
    cd $dir
    git push origin develop
    cd -
done
```

## Caso 8: Añadir Múltiples Repos de Subdirectorio

### Contexto
Necesitas añadir varias librerías a una feature existente

### Pasos

```bash
# Feature ya existe
cd ~/wrkspc.nubarchiva

# Añadir múltiples librerías
./tools/add-repo.sh feature my-feature libs/marc4j
./tools/add-repo.sh feature my-feature libs/dspace
./tools/add-repo.sh feature my-feature libs/foo-commonj

# Verificar
./tools/switch-workspace.sh feature my-feature
```

## Caso 9: Exploración - Descubrir Qué Repos Tocar

### Contexto
No estás seguro de qué repos vas a necesitar modificar

### Pasos

```bash
# 1. Crear workspace vacío
./tools/new-workspace.sh feature exploratory

# 2. Investigar código...
# Descubres que necesitas ks-nuba
./tools/add-repo.sh feature exploratory ks-nuba

cd workspaces/features/exploratory/ks-nuba
# Revisar código...

# 3. Descubres dependencia en marc4j
cd ~/wrkspc.nubarchiva
./tools/add-repo.sh feature exploratory libs/marc4j

# 4. Y necesitas un módulo
./tools/add-repo.sh feature exploratory modules/docs

# Resultado final: workspace con estructura incremental
```

## Caso 10: Múltiples Features con Diferentes Estructuras

### Contexto
Trabajar en varias features simultáneamente, cada una con diferentes repos

### Pasos

```bash
cd ~/wrkspc.nubarchiva

# Feature 1: Solo código principal
./tools/new-workspace.sh feature ui-redesign ks-nuba

# Feature 2: Solo librerías
./tools/new-workspace.sh feature libs-update libs/marc4j libs/dspace

# Feature 3: Código + librería específica
./tools/new-workspace.sh feature marc-integration ks-nuba libs/marc4j

# Feature 4: Solo módulos
./tools/new-workspace.sh feature portal-update modules/diffusion-portal modules/docs

# Listar todo
./tools/list-workspaces.sh

# Output:
# ═══════════════════════════════════════════════════
# FEATURES (4)
# ═══════════════════════════════════════════════════
# 
# 🔹 feature/ui-redesign
#    📦 Repos: 1
#    📂 Contenido:
#       • ks-nuba
#
# 🔹 feature/libs-update
#    📦 Repos: 2
#    📂 Contenido:
#       • libs/marc4j
#       • libs/dspace
#
# 🔹 feature/marc-integration
#    📦 Repos: 2
#    📂 Contenido:
#       • ks-nuba
#       • libs/marc4j
#
# 🔹 feature/portal-update
#    📦 Repos: 2
#    📂 Contenido:
#       • modules/diffusion-portal
#       • modules/docs
```

## Caso 11: Claude Code con Estructura Jerárquica

### Contexto
Maximizar efectividad de Claude Code con repos en subdirectorios

### Pasos

```bash
# 1. Crear workspace bien estructurado
./tools/new-workspace.sh feature ai-cataloging \
    ks-nuba \
    libs/marc4j \
    modules/metadata-entities

# 2. Documentar bien el README
cd workspaces/features/ai-cataloging
cat > README.md <<EOF
# Feature: AI-Powered Cataloging

## Objetivo
Implementar catalogación asistida por IA

## Repos y sus roles
- \`ks-nuba\`: Frontend y servicios principales
- \`libs/marc4j\`: Procesamiento MARC con IA
- \`modules/metadata-entities\`: Entidades enriquecidas

## Arquitectura
1. ks-nuba/src/main/java/...  → UI y API
2. libs/marc4j/...             → Parser MARC extendido
3. modules/metadata-entities/  → Modelos de datos

## Stack
- Java 11
- Apache Solr 3.5
- MARC 21

## Para AI
Este cambio añade capacidades de IA para:
- Sugerencia automática de campos MARC
- Validación inteligente de metadatos
- Enriquecimiento de registros
EOF

# 3. Abrir con Claude Code
claude-code .

# Claude Code ve estructura clara:
# - Qué repos están involucrados (y dónde están)
# - Rol de cada repo
# - Relaciones entre ellos
```

## Tips para Trabajar con Subdirectorios

### Verificar Repos Disponibles
```bash
cd ~/wrkspc.nubarchiva

# Ver repos en raíz
ls -d */.git | sed 's|/.git||'

# Ver repos en libs/
ls -d libs/*/.git | sed 's|/.git||'

# Ver repos en modules/
ls -d modules/*/.git | sed 's|/.git||'

# O todo junto
find . -maxdepth 3 -name ".git" -type d | sed 's|/.git||' | sed 's|^\./||' | sort
```

### Navegar en Workspaces
```bash
# Ir al workspace
cd ~/wrkspc.nubarchiva/workspaces/features/mi-feature

# Ver estructura
tree -L 2

# Navegar a repo en subdirectorio
cd libs/marc4j
# o
cd modules/docs
```

### Git Operations en Subdirectorios
```bash
cd workspaces/features/mi-feature

# Push de todos los repos (incluyendo subdirectorios)
for repo_path in ks-nuba libs/marc4j modules/docs; do
    echo "Pushing $repo_path..."
    (cd $repo_path && git push origin feature/mi-feature)
done

# Status de todos
for repo_path in ks-nuba libs/marc4j modules/docs; do
    echo "=== $repo_path ==="
    (cd $repo_path && git status -s)
done
```

### Cleanup de Worktrees Huérfanos
```bash
# Para repo en subdirectorio
cd ~/wrkspc.nubarchiva/libs/marc4j
git worktree list
git worktree prune

# Para módulo
cd ~/wrkspc.nubarchiva/modules/docs
git worktree list
git worktree prune
```

## Patrones Comunes

### Pattern 1: Código Principal + Una Librería
```bash
./tools/new-workspace.sh feature my-change ks-nuba libs/<lib-name>
```

### Pattern 2: Solo Librerías
```bash
./tools/new-workspace.sh feature libs-only libs/lib1 libs/lib2 libs/lib3
```

### Pattern 3: Solo Módulos
```bash
./tools/new-workspace.sh feature modules-only modules/mod1 modules/mod2
```

### Pattern 4: Todo
```bash
./tools/new-workspace.sh feature full-stack \
    ks-nuba \
    dga-commons \
    libs/needed-lib \
    modules/needed-module
```

### Pattern 5: Incremental
```bash
# Empezar simple
./tools/new-workspace.sh feature incremental ks-nuba

# Ir añadiendo según necesites
./tools/add-repo.sh feature incremental libs/marc4j
./tools/add-repo.sh feature incremental modules/docs
```
