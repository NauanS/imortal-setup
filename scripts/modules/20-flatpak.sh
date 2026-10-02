#!/usr/bin/env bash
# Módulo flatpak: ativa o Flathub e instala os apps de config/flatpaks.txt.
#
# FLATPAK_SCOPE=system (padrão) -> apps em /var/lib/flatpak (partição raiz)
# FLATPAK_SCOPE=user            -> apps em ~/.local/share/flatpak (fica na /home
#                                  e sobrevive a uma reinstalação que preserve a /home)

FLATHUB_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"

module_main() {
  local scope="${FLATPAK_SCOPE:-system}"
  [[ "$scope" == system || "$scope" == user ]] || die "FLATPAK_SCOPE deve ser 'system' ou 'user'."

  if command -v flatpak >/dev/null; then
    ok "Flatpak já instalado ($(flatpak --version 2>/dev/null || echo 'versão ?'))."
  else
    info "Flatpak não encontrado. Instalando pelo gerenciador da distro."
    pkg_install flatpak
    warn "Flatpak recém-instalado: os apps só aparecem no menu depois de encerrar a sessão."
  fi

  local fp=(flatpak)
  [[ "$scope" == system ]] && fp=(sudo flatpak)
  [[ $EUID -eq 0 ]] && fp=(flatpak)

  info "Ativando Flathub (escopo: $scope)"
  run "${fp[@]}" remote-add --"$scope" --if-not-exists flathub "$FLATHUB_URL"

  local apps=()
  mapfile -t apps < <(read_list "$REPO_DIR/config/flatpaks.txt")
  if (( ${#apps[@]} == 0 )); then
    warn "config/flatpaks.txt está vazio. Rode ./scripts/backup.sh na máquina antiga para gerá-lo."
    return 0
  fi

  info "Instalando ${#apps[@]} apps do Flathub"
  local failed=() app
  for app in "${apps[@]}"; do
    if run "${fp[@]}" install --"$scope" -y --noninteractive flathub "$app"; then
      ok "$app"
    else
      failed+=("$app")
    fi
  done

  if (( ${#failed[@]} )); then
    warn "Não foi possível instalar: ${failed[*]}"
    warn "Confira os IDs em https://flathub.org"
  else
    ok "Todos os Flatpaks instalados."
  fi
}
