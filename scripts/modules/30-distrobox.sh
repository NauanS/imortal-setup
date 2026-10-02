#!/usr/bin/env bash
# Módulo distrobox: cria os contêineres descritos em config/distrobox.ini.

module_main() {
  local ini="$REPO_DIR/config/distrobox.ini"

  if ! grep -qE '^[[:space:]]*\[' "$ini" 2>/dev/null; then
    ok "Nenhum contêiner definido em config/distrobox.ini (tudo comentado). Pulando."
    return 0
  fi

  command -v distrobox >/dev/null || pkg_install distrobox podman

  if ! distrobox assemble --help >/dev/null 2>&1; then
    warn "Sua versão do distrobox não tem 'assemble' (precisa da 1.5+)."
    warn "Crie manualmente: distrobox create -n arch -i archlinux:latest"
    return 0
  fi

  info "Criando contêineres (pode demorar no primeiro download)"
  run distrobox assemble create --file "$ini"
  ok "Contêineres prontos. Liste com: distrobox list"
}
