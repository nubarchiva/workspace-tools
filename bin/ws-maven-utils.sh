#!/bin/bash
# =============================================================================
# ws-maven-utils.sh - Aislamiento del repositorio Maven por workspace
# =============================================================================
#
# Problema: todos los worktrees construyen los mismos GAV *-SNAPSHOT desde
# código distinto. Si dos sesiones paralelas hacen `mvn install` contra el
# ~/.m2/repository compartido, se pisan los SNAPSHOT mutuamente (fallo
# silencioso: el código de un worktree acaba ejecutándose con jars del otro).
#
# Solución (Maven >= 3.9): repositorio "head" por workspace + "tail"
# compartido de solo lectura, vía .mvn/maven.config en cada repo:
#   - Escrituras (mvn install, descargas) van solo al head del workspace
#   - Lecturas: primero head; lo que no esté se lee del tail sin re-descargar
#
# Variables configurables (~/.wsrc):
#   WS_MAVEN_ISOLATION  - "false" desactiva el aislamiento (por defecto activo)
#   WS_MAVEN_HEAD_BASE  - Base de los heads (por defecto $HOME/.m2/wt)
#   WS_MAVEN_TAIL       - Repositorio compartido (por defecto $HOME/.m2/repository)
#
# =============================================================================

# Indica si el aislamiento Maven está activo
# Uso: if maven_isolation_enabled; then ...
maven_isolation_enabled() {
    [[ "${WS_MAVEN_ISOLATION:-true}" != "false" ]]
}

# Directorio head de un workspace (raíz, lo que se borra en ws clean)
# Uso: maven_head_dir <workspace_name>
maven_head_dir() {
    echo "${WS_MAVEN_HEAD_BASE:-$HOME/.m2/wt}/$1"
}

# Repositorio head de un workspace (lo que consume Maven)
# Uso: maven_head_repo <workspace_name>
maven_head_repo() {
    echo "$(maven_head_dir "$1")/repository"
}

# Repositorio tail compartido (solo lectura para los workspaces)
maven_tail_repo() {
    echo "${WS_MAVEN_TAIL:-$HOME/.m2/repository}"
}

# Configura el aislamiento Maven en un worktree:
#   1. Crea .mvn/maven.config con head del workspace + tail compartido
#   2. Excluye el fichero de git (info/exclude del gitdir común: lleva rutas
#      absolutas locales y no debe commitearse)
# Idempotente: re-escribe la config y no duplica la línea de exclude.
# Uso: setup_maven_isolation <worktree_path> <workspace_name>
# Retorna: 0 si configuró el repo, 1 si lo saltó (desactivado o sin pom.xml)
setup_maven_isolation() {
    local worktree_path="$1"
    local workspace_name="$2"

    maven_isolation_enabled || return 1
    [[ -n "$workspace_name" ]] || return 1
    [[ -f "$worktree_path/pom.xml" ]] || return 1

    mkdir -p "$worktree_path/.mvn"
    cat > "$worktree_path/.mvn/maven.config" << EOF
-Dmaven.repo.local=$(maven_head_repo "$workspace_name")
-Dmaven.repo.local.tail=$(maven_tail_repo)
EOF

    (
        cd "$worktree_path" 2>/dev/null || exit 0
        exclude_file="$(git rev-parse --git-path info/exclude 2>/dev/null)"
        [[ -n "$exclude_file" ]] || exit 0
        mkdir -p "$(dirname "$exclude_file")"
        if ! grep -qxF '.mvn/maven.config' "$exclude_file" 2>/dev/null; then
            echo '.mvn/maven.config' >> "$exclude_file"
        fi
    )

    return 0
}

# Avisa si el Maven instalado no soporta maven.repo.local.tail (< 3.9).
# Con Maven < 3.9 el tail se ignora: el aislamiento funciona pero el head
# parte vacío y re-descarga todo (lento, no peligroso).
maven_warn_if_no_tail_support() {
    command -v mvn >/dev/null 2>&1 || return 0

    local version major minor
    version=$(mvn -v 2>/dev/null | head -1 | sed -E 's/^Apache Maven ([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
    [[ "$version" =~ ^[0-9]+\.[0-9]+ ]] || return 0

    major="${version%%.*}"
    minor="${version#*.}"
    minor="${minor%%.*}"

    if (( major < 3 )) || { (( major == 3 )) && (( minor < 9 )); }; then
        warning "⚠️  Maven $version detectado: maven.repo.local.tail requiere Maven >= 3.9"
        echo "   El aislamiento funcionará, pero sin tail se re-descargan todas las dependencias al head."
    fi
}
