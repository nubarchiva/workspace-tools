# Roadmap - Workspace Tools

Este documento describe las mejoras planificadas para Workspace Tools, priorizadas por su impacto en la eficiencia del flujo de trabajo diario.

## ✅ Completado

### Auto-detección de workspace
✅ **v3.1** - Detecta automáticamente el workspace actual cuando ejecutas comandos desde dentro, eliminando la necesidad de especificar el nombre. Soporta `ws mvn`, `ws git`, `ws add` con lógica de prioridad inteligente (explícito > auto-detección > tradicional).

---

### ws status / ws . - Estado del workspace actual
✅ **v3.1** - Muestra información del workspace actual con auto-detección. Atajo ultra-corto `ws .` para consulta rápida de estado (repos, branches, cambios pendientes, rutas relativas).

---

### wscd - Navegación rápida entre repos
✅ **v3.2** - Navega entre repos del workspace actual con matching parcial y menú interactivo. `wscd app` en lugar de `cd ../../../app`. Soporta `wscd .` (raíz) y `wscd ..` (arriba).

---

### ws rename - Renombrado seguro de workspaces
✅ **v3.3** - Renombra workspaces con verificaciones exhaustivas (bloquea si hay cambios sin commitear, advierte sobre commits sin pushear y branches remotas). Actualiza automáticamente worktrees y branches locales. Confirmación explícita escribiendo "RENOMBRAR".

---

### Infraestructura de tests
✅ **v4.0** - Tests automatizados con BATS (Bash Automated Testing System). 78+ tests cubriendo ws-new, ws-add, ws-list, ws-clean, ws-common. Módulo centralizado `ws-init.sh` para inicialización. Archivo de configuración `~/.wsrc`.

---

### ws update - Actualización con develop
✅ **v4.2** - Actualiza la branch de trabajo con lo último de develop (merge o rebase).
- `ws update` - Merge develop en todos los repos (auto-detección)
- `ws update --rebase` - Rebase sobre develop
- `ws update --from main` - Especificar branch base
- Salta repos con cambios sin commitear (no pierde trabajo)
- Se detiene si hay conflictos, mostrando instrucciones claras

---

### ws origins - Operaciones en repos origen
✅ **v4.2** - Ejecuta comandos en todos los repos origen (WORKSPACE_ROOT).
- `ws origins git pull` - Pull en todos los repos origen
- `ws origins git status` - Status de todos los repos origen
- `ws origins list` - Lista repos detectados
- Excluye automáticamente el directorio workspaces/
- Útil para actualizar repos en develop/master sin crear workspace

---

### ws stash - Gestión coordinada de stash
✅ **v4.1** - Permite hacer stash/pop de cambios en todos los repos del workspace simultáneamente.
- `ws stash` / `ws stash push "mensaje"` - Stash en repos con cambios
- `ws stash pop` - Pop del stash más reciente
- `ws stash list` - Lista stashes de todos los repos
- `ws stash clear` - Elimina todos los stashes (con confirmación)
- `ws stash show [n]` - Muestra contenido del stash
- Shortcut: `wstash`

---

### ws templates - Templates de workspace
✅ **v4.1** - Define conjuntos predefinidos de repos para tipos comunes de workspace.
- `ws templates` / `ws tpl` - Lista templates disponibles
- `ws templates add <nombre> <repos...>` - Crea template
- `ws templates show <nombre>` - Muestra repos de un template
- `ws templates remove <nombre>` - Elimina template
- `ws new <nombre> --template <tpl>` - Crea workspace desde template
- Archivo de configuración: `$WORKSPACE_ROOT/.ws-templates`

---

### ws grep - Búsqueda multi-repo
✅ **v4.1** - Busca texto o patrones en todos los repos del workspace simultáneamente.
- `ws grep "patrón"` - Busca en todos los repos
- `ws grep -i "todo" --type java` - Case-insensitive, solo archivos .java
- Opciones: -i, -l, -n, -w, -E, --type
- Shortcut: `wgrep`

---

### Distribución
✅ **v4.1** - Herramientas de distribución e instalación.
- Homebrew formula (`brew install --build-from-source ./Formula/workspace-tools.rb`)
- `ws --version` / `ws -v` - Muestra versión actual
- Script de desinstalación interactivo (`uninstall.sh`)
- CI con GitHub Actions (tests + ShellCheck)
- Instalador rediseñado para usuarios externos (configuración interactiva)

---

### .wsignore
✅ **v4.1** - Excluye repos de operaciones `ws origins`.
- Archivo `$WORKSPACE_ROOT/.wsignore`
- Un repo por línea, comentarios con `#`
- Útil para excluir repos externos del pull masivo

---

## 💡 Ideas para el futuro

Las siguientes funcionalidades están documentadas pero no priorizadas. Se implementarán solo si hay necesidad real:

### ws diff - Comparación entre workspaces
Compara los commits entre dos workspaces mostrando qué cambios tiene cada uno.

```bash
ws diff feature-123 feature-456
ws diff feature-123 develop      # comparar con develop
```

---

### ws cleanup - Limpieza automática de workspaces
Identifica y elimina workspaces viejos o ya mergeados.

```bash
ws cleanup --merged              # elimina workspaces mergeados
ws cleanup --older-than 30d      # elimina antiguos
ws cleanup --dry-run             # muestra qué se eliminaría
```

---

### Hooks personalizados
Permite ejecutar scripts custom en eventos específicos (pre-push, pre-switch, post-new, etc.).

```bash
# En .ws-hooks/pre-push
#!/bin/bash
# Verificar que todos los repos estén sincronizados
```

---

### Integración con Jira
Integración con Jira para crear workspaces desde tickets y actualizar estado automáticamente.

```bash
ws new TICKET-123                   # crea workspace y linkea con Jira
ws commit "fix: bug" --update-jira  # actualiza Jira automáticamente
```

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

**Última actualización:** 30 de noviembre de 2025
**Versión:** 4.1.0
