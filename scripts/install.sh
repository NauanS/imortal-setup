#!/usr/bin/env bash
# Setup Imortal - script de pós-instalação.
# Uso: ./scripts/install.sh [opções] [módulos...]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

ALL_MODULES=(base apps flatpak distrobox snapshots dotfiles shell desktop)

usage() {
  cat <<EOF
Uso: $(basename "$0") [opções] [módulos...]

Sem módulos, roda todos na ordem: ${ALL_MODULES[*]}

Módulos:
  base        Pacotes nativos essenciais (packages/common.txt + packages/<distro>.txt)
  apps        Docker CE, Google Chrome, VS Code... (config/native-apps.txt)
  flatpak     Ativa o Flathub e instala os apps de config/flatpaks.txt
  distrobox   Cria os contêineres de config/distrobox.ini
  snapshots   Configura Snapper ou Timeshift conforme o disco
  dotfiles    Liga os dotfiles do repositório na sua home (GNU Stow)
  shell       zsh + autosuggestions + syntax-highlighting + Starship (vira o shell padrão, com confirmação)
  desktop     Restaura atalhos e preferências do GNOME/KDE

Opções:
  -n, --dry-run   Mostra o que seria feito, sem executar nada
  -y, --yes       Responde "sim" para todas as perguntas
  -h, --help      Mostra esta ajuda

Variáveis:
  FLATPAK_SCOPE=system|user   Onde instalar os Flatpaks (padrão: system)

Exemplos:
  ./scripts/install.sh --dry-run
  ./scripts/install.sh flatpak dotfiles
EOF
}

selected=()
while (( $# )); do
  case "$1" in
    -n|--dry-run) DRY_RUN=1 ;;
    -y|--yes)     export ASSUME_YES=1 ;;
    -h|--help)    usage; exit 0 ;;
    -*)           die "Opção desconhecida: $1 (veja --help)" ;;
    *)            selected+=("$1") ;;
  esac
  shift
done
(( ${#selected[@]} )) || selected=("${ALL_MODULES[@]}")

[[ $EUID -eq 0 ]] && die "Rode como seu usuário normal. O script pede sudo quando precisa."

detect_distro
info "Distro detectada: $DISTRO_NAME  →  família '$DISTRO'"
[[ "$DRY_RUN" == 1 ]] && warn "Modo dry-run: nada será alterado."

if [[ "$DRY_RUN" != 1 && $EUID -ne 0 ]]; then
  sudo -v || die "Preciso de sudo para continuar."
fi

for m in "${selected[@]}"; do
  shopt -s nullglob
  files=("$SCRIPT_DIR"/modules/*-"$m".sh)
  shopt -u nullglob
  (( ${#files[@]} )) || die "Módulo inexistente: $m"
  echo
  info "Módulo: $m"
  # shellcheck disable=SC1090
  source "${files[0]}"
  module_main
done

echo
ok "Concluído! Próximos passos:"
echo "   1. Restaure as configurações dos Flatpaks:  ./scripts/cloud-backup.sh setup && ./scripts/cloud-backup.sh restore-flatpak"
echo "      (ou de um HD externo: ./scripts/restore.sh /caminho/do/backup)"
echo "   2. Faça login no navegador para sincronizar web apps e favoritos"
echo "   3. Encerre a sessão e entre de novo para aplicar tudo (inclusive o grupo docker)"
echo "   4. Ligue o backup automático: ./scripts/cloud-backup.sh timer on"
