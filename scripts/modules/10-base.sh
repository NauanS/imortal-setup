#!/usr/bin/env bash
# Módulo base: pacotes nativos essenciais.

module_main() {
  pkg_refresh

  local pkgs=()
  mapfile -t pkgs < <(read_list "$REPO_DIR/packages/common.txt"; read_list "$REPO_DIR/packages/$DISTRO.txt")

  if (( ${#pkgs[@]} == 0 )); then
    warn "Nenhum pacote listado em packages/."
    return 0
  fi

  info "Instalando ${#pkgs[@]} pacotes nativos: ${pkgs[*]}"
  pkg_install "${pkgs[@]}"
  ok "Pacotes base instalados."
}
