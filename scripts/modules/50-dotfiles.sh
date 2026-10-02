#!/usr/bin/env bash
# Módulo dotfiles: cria links simbólicos de dotfiles/<pacote>/ para a sua home (GNU Stow).
#
# Cada subpasta de dotfiles/ é um "pacote" que espelha a estrutura da home:
#   dotfiles/git/.gitconfig            -> ~/.gitconfig
#   dotfiles/nvim/.config/nvim/init.lua -> ~/.config/nvim/init.lua
#
# Arquivos que já existirem na home são movidos para ~/.dotfiles-backup-<data>/.

module_main() {
  command -v stow >/dev/null || pkg_install stow

  local dot_dir="$REPO_DIR/dotfiles"
  local backup_dir
  backup_dir="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

  preserve_existing_gitconfig

  local pkg_path pkg rel target
  for pkg_path in "$dot_dir"/*/; do
    pkg="$(basename "$pkg_path")"
    info "Pacote: $pkg"

    # Move arquivos conflitantes (que não sejam links para o próprio repo).
    while IFS= read -r -d '' rel; do
      rel="${rel#"$pkg_path"}"
      target="$HOME/$rel"
      if [[ -e "$target" && ! -L "$target" ]]; then
        warn "Já existe: ~/$rel  → movendo para $backup_dir/"
        run mkdir -p "$(dirname "$backup_dir/$rel")"
        run mv "$target" "$backup_dir/$rel"
      fi
    done < <(find "$pkg_path" -type f -print0)

    # --no-folding: nunca transforma uma pasta inteira (ex.: ~/.config) em link.
    run stow --no-folding --restow -d "$dot_dir" -t "$HOME" "$pkg"
    ok "$pkg ligado."
  done

  # Garante que o ~/.bashrc carregue ~/.config/shell/*.sh, a mesma pasta que o ~/.zshrc usa.
  # Assim aliases, PATH e prompt valem no bash e no zsh, em qualquer máquina.
  if [[ -d "$HOME/.config/shell" ]] && ! grep -q 'config/shell' "$HOME/.bashrc" 2>/dev/null; then
    info "Adicionando carregamento de ~/.config/shell ao ~/.bashrc"
    if [[ "$DRY_RUN" == 1 ]]; then
      echo "    [dry-run] acrescentaria o bloco ao ~/.bashrc"
    else
      cat >> "$HOME/.bashrc" <<'EOF2'

# Setup Imortal: configurações comuns ao bash e ao zsh
if [ -d ~/.config/shell ]; then
  for rc in ~/.config/shell/*.sh; do [ -r "$rc" ] && . "$rc"; done
  unset rc
fi
EOF2
    fi
  fi
  # Garante o zsh em qualquer terminal (botão direito > "Abrir no terminal", COSMIC, Konsole, GNOME...),
  # mesmo antes de encerrar a sessão após o chsh. Só vale em bash interativo cujo shell de login
  # ainda não é o zsh. Para abrir um bash de propósito: SETUP_IMORTAL_NO_ZSH=1 bash
  if [[ -d "$HOME/.config/shell" ]] && ! grep -q 'SETUP_IMORTAL_NO_ZSH' "$HOME/.bashrc" 2>/dev/null; then
    info "Adicionando a troca bash -> zsh ao ~/.bashrc"
    if [[ "$DRY_RUN" == 1 ]]; then
      echo "    [dry-run] acrescentaria o bloco ao ~/.bashrc"
    else
      cat >> "$HOME/.bashrc" <<'EOF2'

# Setup Imortal: abre o zsh em terminais interativos (desative com SETUP_IMORTAL_NO_ZSH=1)
if [ -n "${PS1:-}" ] && [ -z "${SETUP_IMORTAL_NO_ZSH:-}" ] && [ -z "${ZSH_VERSION:-}" ] \
   && [ "${SHELL##*/}" != zsh ] && command -v zsh >/dev/null 2>&1; then
  export SHELL="$(command -v zsh)"
  exec zsh -l
fi
EOF2
    fi
  fi
  setup_git_identity
  setup_git_delta
  ok "Dotfiles aplicados."
}

# Nome e e-mail do Git ficam FORA do repositório público, em ~/.gitconfig.local.
setup_git_identity() {
  local local_cfg="$HOME/.gitconfig.local"
  if [[ -n "$(git config -f "$local_cfg" user.name 2>/dev/null)" && -n "$(git config -f "$local_cfg" user.email 2>/dev/null)" ]]; then
    ok "Identidade do Git já configurada em ~/.gitconfig.local"
    return 0
  fi

  if [[ "$DRY_RUN" == 1 || "$ASSUME_YES" == 1 || ! -t 0 ]]; then
    warn "Crie ~/.gitconfig.local com seu nome e e-mail (veja docs/06-dotfiles.md)."
    return 0
  fi

  local name email
  info "Identidade do Git (salva só em ~/.gitconfig.local, fora do repositório)"
  echo "   Dica: use o e-mail 'noreply' do GitHub para não expor o seu e-mail real:"
  echo "   GitHub > Settings > Emails > 'Keep my email addresses private'."
  read -rp "   Nome: " name
  read -rp "   E-mail: " email
  if [[ -z "$name" || -z "$email" ]]; then
    warn "Nome ou e-mail vazio. Pulando; crie ~/.gitconfig.local depois."
    return 0
  fi
  printf '\n[user]\n\tname = %s\n\temail = %s\n' "$name" "$email" >> "$local_cfg"
  chmod 600 "$local_cfg"
  ok "Arquivo ~/.gitconfig.local criado."
}

# Um ~/.gitconfig que não seja link para o repositório pode ter credenciais (ex.: gh auth git-credential)
# e identidade. Antes de o Stow substituí-lo, o conteúdo vai para ~/.gitconfig.local (fora do repositório,
# modo 600), então nada se perde. O arquivo original ainda vai para ~/.dotfiles-backup-*/.
preserve_existing_gitconfig() {
  local current="$HOME/.gitconfig" local_cfg="$HOME/.gitconfig.local"
  [[ -f "$current" && ! -L "$current" ]] || return 0
  [[ -s "$current" ]] || return 0
  grep -qF "Preservado de ~/.gitconfig" "$local_cfg" 2>/dev/null && return 0

  info "Preservando o seu ~/.gitconfig atual em ~/.gitconfig.local (credenciais e identidade)"
  if [[ "$DRY_RUN" == 1 ]]; then
    echo "    [dry-run] copiaria ~/.gitconfig para ~/.gitconfig.local"
    return 0
  fi
  {
    printf '\n# Preservado de ~/.gitconfig pelo Setup Imortal em %s\n' "$(date +%F)"
    cat "$current"
  } >> "$local_cfg"
  chmod 600 "$local_cfg"
  ok "Conteúdo copiado para ~/.gitconfig.local."
}

# delta: diffs legíveis. Só liga a configuração se o delta existir, para o Git nunca quebrar.
# O pacote se chama git-delta; se a distro não tiver, o resto do setup segue sem ele.
setup_git_delta() {
  local local_cfg="$HOME/.gitconfig.local"
  command -v delta >/dev/null || pkg_install git-delta || warn "git-delta indisponível nesta distro (opcional). Pulando."
  if ! command -v delta >/dev/null; then
    [[ "$DRY_RUN" == 1 ]] && echo "    [dry-run] ligaria a configuração do delta se ele for instalado"
    return 0
  fi
  if git config -f "$local_cfg" --get-all include.path 2>/dev/null | grep -qF 'delta.gitconfig'; then
    ok "delta já configurado."
    return 0
  fi
  run git config -f "$local_cfg" --add include.path '~/.config/git/delta.gitconfig'
  [[ "$DRY_RUN" == 1 ]] || chmod 600 "$local_cfg"
  ok "delta configurado no Git."
}
