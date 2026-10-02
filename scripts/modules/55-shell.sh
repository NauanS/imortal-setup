#!/usr/bin/env bash
# Módulo shell: zsh + autosuggestions + syntax-highlighting + Starship.
#
# - zsh vem do repositório da distro (packages/common.txt).
# - Os plugins vêm do repositório oficial do zsh-users, em ~/.local/share/zsh/plugins
#   (mesma versão nas 4 famílias e sobrevive à reinstalação, pois fica na /home).
# - O Starship vem da release oficial do GitHub (checksum verificado), em ~/.local/bin.
# - A configuração (~/.zshrc e ~/.config/shell/) vem do módulo dotfiles.

ZSH_PLUGINS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"

module_main() {
  command -v zsh >/dev/null || pkg_install zsh
  command -v git >/dev/null || pkg_install git

  install_zsh_plugin zsh-autosuggestions   https://github.com/zsh-users/zsh-autosuggestions.git
  install_zsh_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git
  install_starship
  set_default_shell_zsh
  ok "Shell configurado. Abra um novo terminal (ou encerre a sessão) para usar o zsh."
}

install_zsh_plugin() {
  local name="$1" url="$2" dest="$ZSH_PLUGINS_DIR/$1"
  if [[ -d "$dest/.git" ]]; then
    ok "$name já instalado."
    return 0
  fi
  info "Instalando $name"
  run mkdir -p "$ZSH_PLUGINS_DIR"
  run git clone --depth 1 "$url" "$dest"
}

install_starship() {
  if command -v starship >/dev/null || [[ -x "$HOME/.local/bin/starship" ]]; then
    ok "Starship já instalado."
    return 0
  fi

  local arch
  case "$(uname -m)" in
    x86_64)        arch=x86_64 ;;
    aarch64|arm64) arch=aarch64 ;;
    *) warn "Arquitetura $(uname -m) sem binário oficial do Starship. Pulando."; return 0 ;;
  esac

  local file="starship-${arch}-unknown-linux-musl.tar.gz"
  local base="https://github.com/starship/starship/releases/latest/download"
  info "Instalando Starship (release oficial)"

  if [[ "$DRY_RUN" == 1 ]]; then
    echo "    [dry-run] baixaria $base/$file, verificaria o sha256 e instalaria em ~/.local/bin"
    return 0
  fi

  local tmp
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN
  download "$base/$file" "$tmp/$file" || { warn "Falha ao baixar o Starship."; return 1; }
  download "$base/$file.sha256" "$tmp/$file.sha256" || { warn "Falha ao baixar o checksum."; return 1; }

  local expected actual
  expected="$(awk '{print $1}' "$tmp/$file.sha256")"
  actual="$(sha256sum "$tmp/$file" | awk '{print $1}')"
  [[ -n "$expected" && "$expected" == "$actual" ]] || { warn "Checksum do Starship não confere. Abortando."; return 1; }

  mkdir -p "$HOME/.local/bin"
  tar -xzf "$tmp/$file" -C "$tmp" starship
  install -m 0755 "$tmp/starship" "$HOME/.local/bin/starship"
  ok "Starship instalado em ~/.local/bin."
}

set_default_shell_zsh() {
  local zsh_path current
  zsh_path="$(command -v zsh || true)"
  [[ -n "$zsh_path" ]] || { warn "zsh não encontrado; não vou trocar o shell."; return 0; }

  current="$(getent passwd "$USER" | cut -d: -f7)"
  if [[ "$current" == "$zsh_path" || "$current" == */zsh ]]; then
    ok "O zsh já é o seu shell padrão."
    return 0
  fi

  info "Seu shell padrão hoje: $current"
  confirm "Trocar o shell padrão para zsh ($zsh_path)? O bash continua instalado." || {
    warn "Mantido o shell atual. Para trocar depois: chsh -s $zsh_path"
    return 0
  }

  grep -qx "$zsh_path" /etc/shells 2>/dev/null || as_root sh -c "echo '$zsh_path' >> /etc/shells"
  as_root chsh -s "$zsh_path" "$USER"
}
