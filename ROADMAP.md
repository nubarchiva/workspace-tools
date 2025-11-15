# Roadmap - Workspace Tools

Este documento describe las mejoras planificadas para Workspace Tools, priorizadas por su impacto en la eficiencia del flujo de trabajo diario.

## ✅ Completado

### Detección automática de workspace
**Estado:** ✅ Implementado en v3.1

Detecta automáticamente el workspace actual cuando ejecutas comandos desde dentro de un workspace, eliminando la necesidad de especificar el nombre explícitamente.

**Lógica de prioridad:**
1. Si primer argumento coincide con workspace existente → usar explícitamente
2. Si no coincide → intentar auto-detección desde directorio actual
3. Si no detecta → modo tradicional (primer arg es workspace)

**Beneficios:**
- Reduce fricción en el uso diario (comandos más cortos)
- Menos errores al especificar workspace incorrecto
- Permite especificar workspace explícito desde cualquier lugar
- Funciona con cualquier comando git/maven sin restricciones

**Uso:**
```bash
# Auto-detección (desde dentro de feature-123)
cd ~/workspaces/feature-123/ks-nuba
ws mvn clean install        # detecta feature-123 automáticamente
ws git status               # detecta feature-123 automáticamente
ws git show-branch ...      # funciona con cualquier comando git
ws add libs/marc4j          # añade repo al workspace detectado

# Especificación explícita (desde cualquier lugar)
ws git feature-456 status   # ejecuta en feature-456 aunque estés en otro
ws mvn otro-ws test         # ejecuta en otro-ws desde cualquier lugar
```

**Comandos soportados:** `ws mvn`, `ws git`, `ws add`

---

### Estado del workspace actual (ws status / ws .)
**Estado:** ✅ Implementado en v3.1

Muestra información del workspace actual sin necesidad de especificar el nombre, usando auto-detección.

**Beneficios:**
- Consulta rápida de estado desde cualquier directorio del workspace
- No necesitas recordar el nombre exacto del workspace
- Vista consolidada de todos los repos (branch, cambios pendientes)
- Atajo ultra-corto: `ws .`

**Uso:**
```bash
# Desde dentro de un workspace
cd ~/workspaces/feature-123/ks-nuba
ws status          # auto-detecta feature-123
ws .               # atajo corto
ws here            # alias alternativo

# Especificación explícita (desde cualquier lugar)
ws status feature-456    # muestra estado de feature-456
```

**Implementación:**
- Usa `detect_current_workspace()` para auto-detección
- Delega a `ws-switch` para mostrar la información
- Aliases: `.`, `here`, `status`
- Muestra: README, estado de repos, branch, cambios, rutas

---

### Navegación rápida entre repos (wscd)
**Estado:** ✅ Implementado en v3.2

Navega entre repos del workspace actual usando matching parcial, sin necesidad de conocer rutas exactas.

**Beneficios:**
- Navegación ultra-rápida: `wscd ks` en lugar de `cd ../../../ks-nuba`
- Matching parcial inteligente con menú de selección
- Context-aware: funciona desde cualquier directorio del workspace
- Consistente con otros comandos (mismo patrón de búsqueda)

**Uso:**
```bash
# Desde cualquier lugar del workspace
wscd ks              # busca "ks" → navega a ks-nuba
wscd libs/marc       # busca parcial → navega a libs/marc4j
wscd                 # muestra menú con todos los repos
wscd .               # navega a raíz del workspace
wscd ..              # navega un nivel arriba
```

**Implementación:**
- `bin/ws-repo-path`: Helper script que encuentra repos con matching parcial
- `setup.sh`: Función `wscd()` que hace `cd` a la ruta devuelta
- Menús interactivos con `/dev/tty` para interacción directa
- Auto-detecta workspace con `detect_current_workspace()`

---

## 🔥 Alto impacto / Alta prioridad

### 1. Sincronización de repos (ws sync)
**Prioridad:** Alta
**Esfuerzo:** Bajo
**Estado:** Propuesto

Ejecuta `git pull` en todos los repos de un workspace simultáneamente, asegurando que todos estén actualizados.

**Beneficios:**
- Operación muy frecuente (inicio del día, cambio de contexto)
- Ahorra tiempo vs hacer pull repo por repo
- Evita trabajar con código desactualizado

**Uso propuesto:**
```bash
ws sync feature-123           # pull en todos los repos
ws sync feature-123 --ff      # pull solo si es fast-forward (más seguro)
ws sync                       # con detección automática
```

**Implementación:**
- Similar a `ws git` pero específico para pull
- Opción `--ff` para abortar si no es fast-forward
- Mostrar resumen de cambios por repo

---

### 2. Gestión coordinada de stash (ws stash)
**Prioridad:** Alta
**Esfuerzo:** Medio
**Estado:** Propuesto

Permite hacer stash/pop de cambios en todos los repos del workspace simultáneamente, facilitando el cambio rápido entre workspaces.

**Beneficios:**
- Fundamental para context switching efectivo
- Mantiene trabajo sin commitear entre cambios de workspace
- Evita perder cambios o commitear código incompleto

**Uso propuesto:**
```bash
ws stash feature-123          # stash en todos los repos
ws stash pop feature-123      # pop en todos los repos
ws stash list feature-123     # lista stashes de todos los repos
ws stash clear feature-123    # limpia todos los stashes
```

**Implementación:**
- Ejecutar git stash en cada repo
- Trackear qué repos tienen stash activo
- Opción para hacer stash selectivo (solo repos con cambios)

---

### 3. Estado del workspace actual (ws status / ws .)
**Prioridad:** Media-Alta
**Esfuerzo:** Bajo
**Estado:** Propuesto

Muestra información del workspace donde estás sin necesidad de especificar el nombre.

**Beneficios:**
- Consulta rápida de estado
- No necesitas recordar el nombre exacto del workspace
- Vista consolidada de todos los repos

**Uso propuesto:**
```bash
ws .              # o 'ws here' o 'ws status'
```

**Implementación:**
- Usar detección automática existente
- Mostrar mismo output que `ws switch <workspace>`
- Alias simple que llama a ws-switch con auto-detección

---

## 🎯 Medio impacto / Prioridad media

### 4. Comparación entre workspaces (ws diff)
**Prioridad:** Media
**Esfuerzo:** Medio
**Estado:** Propuesto

Compara los commits entre dos workspaces mostrando qué cambios tiene cada uno.

**Beneficios:**
- Útil para ver divergencias entre features
- Ayuda a planificar merges
- Identifica trabajo duplicado

**Uso propuesto:**
```bash
ws diff feature-123 feature-456
ws diff feature-123 develop      # comparar con develop
```

**Implementación:**
- Comparar commits por repo usando `git log branch1..branch2`
- Mostrar solo repos con diferencias
- Opción --summary para vista condensada

---

### 5. Templates de workspace
**Prioridad:** Media
**Esfuerzo:** Medio
**Estado:** Propuesto

Define conjuntos predefinidos de repos para tipos comunes de workspace, acelerando la creación.

**Beneficios:**
- Acelera creación de workspaces nuevos
- Estandariza qué repos se usan para cada tipo de tarea
- Reduce errores al olvidar repos necesarios

**Uso propuesto:**
```bash
ws templates                      # lista templates disponibles
ws templates add frontend "ks-nuba libs/ui modules/portal"
ws new feature-123 --template frontend
```

**Implementación:**
- Archivo de configuración `.ws-templates`
- Formato simple: `nombre: repo1 repo2 repo3`
- Merge con repos especificados manualmente

---

### 6. Búsqueda multi-repo (ws grep)
**Prioridad:** Media
**Esfuerzo:** Bajo
**Estado:** Propuesto

Busca texto o patrones en todos los repos del workspace simultáneamente.

**Beneficios:**
- Útil para refactoring cross-repo
- Encuentra todas las referencias a una clase/método
- Más rápido que buscar repo por repo

**Uso propuesto:**
```bash
ws grep feature-123 "SearchTerm"
ws grep feature-123 "class Foo" --java
ws grep "TODO" --author matute
```

**Implementación:**
- Wrapper sobre `git grep` en cada repo
- Soporte para filtros por tipo de archivo
- Output agregado con contexto de repo

---

### 7. Limpieza automática de workspaces (ws cleanup)
**Prioridad:** Media
**Esfuerzo:** Medio
**Estado:** Propuesto

Identifica y elimina workspaces viejos o ya mergeados, manteniendo el espacio limpio.

**Beneficios:**
- Mantiene organización del espacio de trabajo
- Libera espacio en disco
- Evita confusión con workspaces obsoletos

**Uso propuesto:**
```bash
ws cleanup --merged              # elimina workspaces mergeados
ws cleanup --older-than 30d      # elimina antiguos
ws cleanup --dry-run             # muestra qué se eliminaría
```

**Implementación:**
- Detectar branches mergeadas en develop/master
- Verificar fecha de último commit
- Confirmación interactiva antes de eliminar
- Opción --force para automatización

---

## 💡 Bajo impacto / Futuro

### 8. Hooks personalizados
**Prioridad:** Baja
**Esfuerzo:** Medio
**Estado:** Idea

Permite ejecutar scripts custom en eventos específicos (pre-push, pre-switch, post-new, etc.).

**Beneficios:**
- Automatización de tareas repetitivas
- Validaciones custom antes de operaciones
- Integración con herramientas externas

**Uso propuesto:**
```bash
# En .ws-hooks/pre-push
#!/bin/bash
# Verificar que todos los repos estén sincronizados
```

---

### 9. Tracking de sincronización
**Prioridad:** Baja
**Esfuerzo:** Bajo
**Estado:** Idea

Muestra cuándo fue el último pull de cada repo y avisa si el remoto tiene cambios nuevos.

**Beneficios:**
- Evita trabajar con código desactualizado
- Identificar repos que necesitan actualización

**Implementación:**
- Trackear timestamp de último pull en metadata
- Comparar con remote refs sin hacer fetch completo
- Advertencia visual en `ws list` si hay cambios remotos

---

### 10. Aliases personalizados por workspace
**Prioridad:** Baja
**Esfuerzo:** Bajo
**Estado:** Idea

Permite definir comandos personalizados específicos para cada workspace.

**Beneficios:**
- Shortcuts para operaciones específicas del proyecto
- Documentación ejecutable de comandos comunes

**Uso propuesto:**
```bash
# En workspace/.ws-config
aliases:
  test: "mvn test -Dgroups=integration"
  deploy-dev: "mvn deploy -Pdev"

# Ejecutar
ws run test
ws run deploy-dev
```

---

### 11. Integración con Jira
**Prioridad:** Baja
**Esfuerzo:** Alto
**Estado:** Idea

Integración con Jira para crear workspaces desde tickets y actualizar estado automáticamente.

**Beneficios:**
- Workflow integrado entre Jira y código
- Actualización automática de estado de tickets
- Prefijos de commit automáticos

**Uso propuesto:**
```bash
ws new NUBA-8123                    # crea workspace y linkea con Jira
ws commit "fix: bug" --update-jira  # actualiza Jira automáticamente
```

**Requisitos:**
- Configuración de credenciales Jira
- API de Jira
- Mapeo de estados workspace -> Jira

---

## 🔄 Criterios de priorización

Las mejoras se priorizan según:

1. **Frecuencia de uso** - ¿Cuántas veces al día se usaría?
2. **Tiempo ahorrado** - ¿Cuánto tiempo ahorra por uso?
3. **Fricción reducida** - ¿Cuánto simplifica el workflow?
4. **Esfuerzo de implementación** - Bajo/Medio/Alto
5. **Dependencias** - ¿Requiere otras features primero?

## 📝 Contribuciones

Las propuestas de mejora son bienvenidas. Para sugerir una nueva funcionalidad:

1. Abre un issue describiendo el caso de uso
2. Explica el beneficio esperado
3. Propón una sintaxis de ejemplo
4. Indica tu disponibilidad para contribuir código

---

**Última actualización:** 19 de noviembre de 2025
**Versión:** 3.1
