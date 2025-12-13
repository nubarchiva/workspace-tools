# Plan: Refactorización de Detección de Workspace

> **Objetivo**: Eliminar duplicación en detección/resolución de workspace (~140 líneas)
> **Fecha**: 2025-12-12
> **Estado**: ✅ Completado

---

## Contexto

### Problema identificado
Había código duplicado en 4 scripts para detectar y resolver workspaces:

| Script | Líneas duplicadas | Patrón |
|--------|-------------------|--------|
| ws-mvn | 14-62 (~49 líneas) | parse_workspace_and_args + resolve |
| ws-git | 14-62 (~49 líneas) | parse_workspace_and_args + resolve |
| ws-stash | 90-112 (~22 líneas) | detect_workspace() local |
| ws-grep | 131-153 (~22 líneas) | detect_workspace() local |

**Total: ~142 líneas duplicadas**

### Funciones extraídas

#### 1. `resolve_workspace()` → ws-init.sh ✅
Resuelve un patrón de workspace en nombre válido y directorio.
```bash
# Uso:
resolve_workspace "$WORKSPACE_PATTERN" "ws stash <workspace>"
# Resultado: WORKSPACE_NAME y WORKSPACE_DIR definidos
```

#### 2. `is_workspace_pattern()` → ws-init.sh ✅
Verifica si un string coincide con algún workspace existente.
```bash
# Uso:
if is_workspace_pattern "$1"; then
    # Es un workspace
fi
```

#### 3. `get_sync_status()` → ws-git-utils.sh ✅
Calcula estado de sincronización respecto a develop/master.
```bash
# Uso:
sync_status=$(get_sync_status "$repo_path")
# Retorna: "unpushed:pending_merge:behind"
```

---

## Fases completadas

### Fase 0: Crear tests para scripts sin cobertura ✅
- [x] ws-stash - tests/test_ws_stash.bats (14 tests)
- [x] ws-grep - tests/test_ws_grep.bats (14 tests)
- [x] ws-mvn - tests/test_ws_mvn.bats (10 tests)
- [x] ws-git - tests/test_ws_git.bats (13 tests)

### Fase 1: Extraer `resolve_workspace()` a ws-init.sh ✅
1. ✅ Añadida función `resolve_workspace()` a ws-init.sh
2. ✅ Modificado ws-stash para usar la función
3. ✅ Modificado ws-grep para usar la función

### Fase 2: Extraer `is_workspace_pattern()` a ws-init.sh ✅
1. ✅ Añadida función `is_workspace_pattern()` a ws-init.sh
2. ✅ Refactorizado ws-mvn para usar ambas funciones
3. ✅ Refactorizado ws-git para usar ambas funciones

### Fase 3: Mover `get_sync_status()` a ws-git-utils.sh ✅
1. ✅ Copiada función de ws-list a ws-git-utils.sh
2. ✅ Eliminada función local de ws-list
3. ✅ Verificado que ws-list funciona

### Fase 4: Tests y documentación ✅
1. ✅ 165 tests pasan (51 nuevos + 114 existentes)
2. ✅ CHANGELOG actualizado

---

## Archivos modificados

| Archivo | Acción |
|---------|--------|
| `bin/ws-init.sh` | Añadido resolve_workspace() e is_workspace_pattern() |
| `bin/ws-git-utils.sh` | Añadido get_sync_status() |
| `bin/ws-stash` | Eliminado detect_workspace() local, usa resolve_workspace() |
| `bin/ws-grep` | Eliminado detect_workspace() local, usa resolve_workspace() |
| `bin/ws-mvn` | Refactorizado para usar is_workspace_pattern() y resolve_workspace() |
| `bin/ws-git` | Refactorizado para usar is_workspace_pattern() y resolve_workspace() |
| `bin/ws-list` | Eliminado get_sync_status() local |
| `tests/test_ws_stash.bats` | Creado - 14 tests |
| `tests/test_ws_grep.bats` | Creado - 14 tests |
| `tests/test_ws_mvn.bats` | Creado - 10 tests |
| `tests/test_ws_git.bats` | Creado - 13 tests |
| `CHANGELOG.md` | Documentada refactorización |

---

## Criterios de éxito

- [x] Todos los tests existentes pasan (165 tests)
- [x] `ws mvn` funciona con auto-detección y workspace explícito
- [x] `ws git` funciona con auto-detección y workspace explícito
- [x] `ws stash` funciona con auto-detección y workspace explícito
- [x] `ws grep` funciona con auto-detección y workspace explícito
- [x] `ws ls` muestra indicadores de sincronización correctamente
- [x] Código duplicado eliminado (~140 líneas menos)

---

## Impacto logrado

- **Líneas eliminadas**: ~140
- **Tests añadidos**: 51 nuevos tests
- **Mantenibilidad**: Lógica centralizada en ws-init.sh y ws-git-utils.sh
- **Riesgo materializado**: Ninguno, todos los tests pasan
