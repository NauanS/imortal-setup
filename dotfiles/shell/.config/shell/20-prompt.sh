# Prompt Starship (instalado pelo módulo "shell"). Funciona no bash e no zsh.
if command -v starship >/dev/null 2>&1; then
  if [ -n "${ZSH_VERSION:-}" ]; then
    eval "$(starship init zsh)"
  elif [ -n "${BASH_VERSION:-}" ]; then
    eval "$(starship init bash)"
  fi
fi
