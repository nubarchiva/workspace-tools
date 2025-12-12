# Plan: Refactorización ws-info / ws-switch

> **Objetivo**: Eliminar duplicación de código (~155 líneas) entre ws-info y ws-switch
> **Fecha**: 2025-12-12
> **Estado**: ✅ COMPLETADO

---

## Contexto

### Problema identificado
- `ws-info` y `ws-switch` comparten ~155 líneas de código idéntico (66-77%)
- `ws-info` era un symlink a `ws-switch`, se convirtió en archivo independiente para añadir auto-detección
- Mantener dos archivos casi idénticos es propenso a errores y dificulta el mantenimiento

### Diferencias actuales entre ambos scripts
| Aspecto | ws-info | ws-switch |
|---------|---------|-----------|
| Auto-detección | ✅ Sí | ❌ No (lista workspaces) |
| Comportamiento sin args | Auto-detecta workspace | Lista workspaces disponibles |
| Textos de ayuda | "ws info ..." | "ws switch ..." |
| Propósito | Solo mostrar información | Mostrar info (para luego hacer cd) |

### Solución propuesta
Un solo archivo `ws-switch` que detecta cómo fue llamado (`basename $0`) y ajusta comportamiento:
- Si invocado como `ws-info` → auto-detecta
- Si invocado como `ws-switch` → comportamiento actual
- `ws-info` vuelve a ser symlink a `ws-switch`

---

## Fases

### Fase 0: Preparación de tests ✅
> **Prerrequisito obligatorio antes de refactorizar**

#### 0.1 Analizar comportamiento actual
- [x] Documentar todos los casos de uso de `ws-switch`
- [x] Documentar todos los casos de uso de `ws-info`
- [x] Identificar diferencias de comportamiento

#### 0.2 Crear tests para ws-switch
```bash
tests/test_ws_switch.bats
```
Tests a crear:
- [x] `ws-switch: sin argumentos lista workspaces`
- [x] `ws-switch: con workspace válido muestra información`
- [x] `ws-switch: con patrón parcial encuentra workspace`
- [x] `ws-switch: workspace inexistente falla`
- [x] `ws-switch: muestra branch de cada repo`
- [x] `ws-switch: muestra estado de cambios (sin commitear)`
- [x] `ws-switch: muestra indicadores de sync (↑ ↓ ←)`
- [x] `ws-switch: muestra ruta del workspace`
- [x] `ws-switch: -h/--help muestra ayuda`
- [x] `ws-switch: modo offline muestra indicador [OFFLINE]`

#### 0.3 Crear tests para ws-info
```bash
tests/test_ws_info.bats
```
Tests a crear:
- [x] `ws-info: sin argumentos auto-detecta workspace`
- [x] `ws-info: sin argumentos fuera de workspace lista disponibles`
- [x] `ws-info: con workspace válido muestra información`
- [x] `ws-info: con patrón parcial encuentra workspace`
- [x] `ws-info: -h/--help muestra ayuda`
- [x] `ws-info: muestra "Workspace detectado:" al auto-detectar`

#### 0.4 Verificar que tests pasan
```bash
bats tests/test_ws_switch.bats tests/test_ws_info.bats
```

---

### Fase 1: Refactorización ✅
> Solo iniciar cuando Fase 0 esté completa y tests pasen

#### 1.1 Modificar ws-switch para detectar nombre de invocación
```bash
# Al inicio del script
SCRIPT_NAME=$(basename "$0")
IS_INFO_MODE=false
[[ "$SCRIPT_NAME" == "ws-info" ]] && IS_INFO_MODE=true
```

#### 1.2 Ajustar comportamiento según modo
```bash
if [ -z "$1" ]; then
    if $IS_INFO_MODE; then
        # Auto-detectar workspace
        WORKSPACE_PATTERN=$(detect_current_workspace 2>/dev/null || true)
        if [ -z "$WORKSPACE_PATTERN" ]; then
            # Mostrar lista y salir
        fi
    else
        # Comportamiento original: listar workspaces
    fi
fi
```

#### 1.3 Ajustar textos de ayuda según modo
```bash
show_help() {
    local cmd="switch"
    $IS_INFO_MODE && cmd="info"
    echo "Uso: ws $cmd [nombre|patrón]"
    # ...
}
```

#### 1.4 Convertir ws-info en symlink
```bash
rm bin/ws-info
ln -s ws-switch bin/ws-info
```

#### 1.5 Ejecutar tests
```bash
bats tests/test_ws_switch.bats tests/test_ws_info.bats
```

---

### Fase 2: Limpieza y documentación ✅

#### 2.1 Actualizar CHANGELOG
- Documentar la refactorización

#### 2.2 Actualizar README si es necesario

#### 2.3 Commit final
```
refactor(switch,info): unificar ws-switch y ws-info en un solo script

Elimina ~155 líneas de código duplicado fusionando ambos scripts.
ws-info vuelve a ser symlink a ws-switch, que detecta el nombre
de invocación para ajustar el comportamiento (auto-detección vs listar).
```

---

## Archivos involucrados

| Archivo | Acción |
|---------|--------|
| `bin/ws-switch` | Modificar (añadir detección de modo) |
| `bin/ws-info` | Eliminar archivo, crear symlink |
| `tests/test_ws_switch.bats` | Crear |
| `tests/test_ws_info.bats` | Crear |
| `CHANGELOG.md` | Actualizar |

---

## Criterios de éxito

- [x] Todos los tests de ws-switch pasan (18 tests)
- [x] Todos los tests de ws-info pasan (18 tests, 1 skip)
- [x] `ws switch` sin args lista workspaces (comportamiento original)
- [x] `ws info` sin args auto-detecta workspace (comportamiento añadido)
- [x] No hay regresiones en funcionalidad existente
- [x] Código duplicado eliminado (~155 líneas menos)

---

## Notas para cambio de contexto

Si esta sesión se interrumpe:
1. Verificar en qué fase estamos (buscar ⬅️ ACTUAL)
2. Leer este documento para contexto
3. Continuar desde el punto donde se dejó
4. Los tests son el prerrequisito más importante
