# Homebrew formula for workspace-tools
# Para instalar localmente: brew install --build-from-source ./Formula/workspace-tools.rb

class WorkspaceTools < Formula
  desc "Git worktree-based workspace management for multi-repo projects"
  homepage "https://github.com/tu-usuario/workspace-tools"
  version "4.1.0"
  license "Apache-2.0"

  # Para instalación desde release de GitHub:
  # url "https://github.com/tu-usuario/workspace-tools/archive/refs/tags/v4.1.0.tar.gz"
  # sha256 "CHECKSUM_AQUI"

  # Para desarrollo local, usar --HEAD
  head "https://github.com/tu-usuario/workspace-tools.git", branch: "develop"

  depends_on "bash"
  depends_on "git"

  def install
    # Instalar scripts en libexec
    libexec.install Dir["bin/*"]
    libexec.install Dir["completions/*"]
    libexec.install "setup.sh"
    libexec.install "VERSION"

    # Crear wrapper en bin que configura el entorno
    (bin/"ws").write <<~EOS
      #!/bin/bash
      export WS_TOOLS="#{libexec}"
      exec "#{libexec}/ws" "$@"
    EOS

    # Instalar completions
    bash_completion.install "completions/ws-completion.bash" => "ws"
    zsh_completion.install "completions/ws-completion.zsh" => "_ws"

    # Instalar documentación
    doc.install "README.md"
    doc.install "USER_GUIDE.md" if File.exist?("USER_GUIDE.md")
    doc.install "CHANGELOG.md" if File.exist?("CHANGELOG.md")
  end

  def caveats
    <<~EOS
      Para habilitar todas las funciones (shortcuts, navegación con wscd):

      Añade a tu ~/.bashrc o ~/.zshrc:
        source #{libexec}/setup.sh

      O configura manualmente:
        export WS_TOOLS="#{libexec}"
        export PATH="#{libexec}:$PATH"

      Para configurar tu directorio de workspaces, crea ~/.wsrc:
        WORKSPACE_ROOT="$HOME/tu-proyecto"

      Documentación: #{doc}
    EOS
  end

  test do
    # Verificar que ws funciona
    assert_match "Workspace Tools", shell_output("#{bin}/ws --help")

    # Verificar versión
    assert_match version.to_s, shell_output("#{bin}/ws --version 2>&1", 0)
  end
end
