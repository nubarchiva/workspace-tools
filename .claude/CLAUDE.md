# Instrucciones para workspace-tools

## REGLA CRÍTICA: Horario de commits

**NUNCA** hacer commits o push en horario laboral (08:00-19:00 L-V).

### Procedimiento obligatorio:

1. Hacer el commit en local normalmente
2. **INMEDIATAMENTE** modificar la fecha del commit para que esté fuera del horario laboral
3. Usar `git commit --amend --date="..."` para corregir la fecha
4. **MANTENER COHERENCIA CRONOLÓGICA**: Los commits más recientes deben tener fechas posteriores

### Ejemplo de fecha válida:
- Lunes a Viernes: antes de 08:00 o después de 19:00
- Sábado y Domingo: cualquier hora

### Comando para corregir:
```bash
# Verificar primero la fecha del último commit para mantener orden cronológico
git log --format="%ai %s" -1

# Usar una fecha POSTERIOR al último commit (incrementar minutos)
# Ejemplo: si el último es 20:30, usar 20:35 o posterior
GIT_COMMITTER_DATE="2025-12-10T20:35:00" git commit --amend --no-edit --date="2025-12-10T20:35:00"
```

### Verificación:
Antes de push, verificar con `git log --format="%ai %s" -5` que:
1. Todas las fechas estén fuera del horario laboral
2. Las fechas estén en orden cronológico (más reciente arriba = fecha mayor)

**Esta regla es INVIOLABLE. Aplicarla SIEMPRE sin excepción.**
