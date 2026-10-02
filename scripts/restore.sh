#!/usr/bin/env bash
# Setup Imortal - restaura as configurações dos Flatpaks (~/.var/app) de um backup.
#
# Uso: ./scripts/restore.sh ORIGEM
#   ORIGEM  a mesma pasta usada no backup.sh (deve conter var-app/)
#
# Rode DEPOIS do ./scripts/install.sh flatpak, com os apps fechados.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

case "${1:-}" in ""|-h|--help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
SRC="$1"
[[ -d "$SRC/var-app" ]] || die "Não encontrei $SRC/var-app"
command -v rsync >/dev/null || die "rsync não instalado. Rode antes: ./scripts/install.sh base"

if command -v flatpak >/dev/null && [[ -n "$(flatpak ps --columns=application 2>/dev/null)" ]]; then
  warn "Há Flatpaks abertos:"
  flatpak ps --columns=application
  confirm "Feche-os antes. Continuar mesmo assim?" || exit 1
fi

info "Restaurando $SRC/var-app → ~/.var/app"
mkdir -p "$HOME/.var/app"
rsync -a --info=stats1 "$SRC/var-app/" "$HOME/.var/app/"
ok "Configurações dos Flatpaks restauradas. Abra seus apps: eles devem estar como antes."
