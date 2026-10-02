#!/usr/bin/env bash
# Setup Imortal - exporta o estado atual da máquina para o repositório
# e (opcionalmente) copia as configurações dos Flatpaks para um disco externo.
#
# Uso: ./scripts/backup.sh [DESTINO]
#   DESTINO  pasta de backup (ex.: /run/media/$USER/HD-Externo/setup-imortal)
#            Se omitido, só atualiza os arquivos do repositório.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

case "${1:-}" in -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
DEST="${1:-}"
[[ -z "$DEST" ]] || command -v rsync >/dev/null || die "rsync não instalado. Instale com o gerenciador da sua distro."

detect_distro
info "Exportando estado de: $DISTRO_NAME"

# 1. Lista de Flatpaks -------------------------------------------------------
if command -v flatpak >/dev/null; then
  {
    echo "# Gerado por scripts/backup.sh em $(date '+%Y-%m-%d %H:%M')"
    echo "# Um ID do Flathub por linha. Linhas com # são ignoradas."
    flatpak list --app --columns=application | sort -u
  } > "$REPO_DIR/config/flatpaks.txt"
  ok "config/flatpaks.txt ($(read_list "$REPO_DIR/config/flatpaks.txt" | wc -l) apps)"
fi

# 2. Configurações da interface ---------------------------------------------
case "$(current_desktop)" in
  gnome)
    mkdir -p "$REPO_DIR/config/desktop/gnome"
    for path in "${DCONF_PATHS[@]}"; do
      dconf dump "$path" > "$REPO_DIR/config/desktop/gnome/$(dconf_file_for "$path")"
    done
    anonymize_dir "$REPO_DIR/config/desktop/gnome"
    ok "config/desktop/gnome/ (${#DCONF_PATHS[@]} grupos, caminhos da home anonimizados)"
    ;;
  kde)
    mkdir -p "$REPO_DIR/config/desktop/kde"
    for f in "${KDE_FILES[@]}"; do
      [[ -f "$HOME/.config/$f" ]] && cp "$HOME/.config/$f" "$REPO_DIR/config/desktop/kde/"
    done
    anonymize_dir "$REPO_DIR/config/desktop/kde"
    ok "config/desktop/kde/ (caminhos da home anonimizados)"
    ;;
  *) warn "Interface não reconhecida; configurações de desktop não exportadas." ;;
esac

# 3. Pacotes nativos instalados (só para consulta) ---------------------------
ref="$REPO_DIR/config/reference"
mkdir -p "$ref"
case "$DISTRO" in
  fedora)   dnf repoquery --userinstalled --queryformat '%{name}\n' 2>/dev/null | sort -u ;;
  debian)   apt-mark showmanual | sort -u ;;
  arch)     pacman -Qqe ;;
  opensuse) rpm -qa --queryformat '%{NAME}\n' | sort -u ;;
esac > "$ref/native-packages-$DISTRO.txt" || true
ok "config/reference/native-packages-$DISTRO.txt (consulta, não é instalado automaticamente)"

# 4. Configurações dos Flatpaks (~/.var/app) para o disco externo ------------
if [[ -n "$DEST" ]]; then
  [[ -d "$DEST" ]] || mkdir -p "$DEST" || die "Não consegui criar $DEST"
  if [[ -d "$HOME/.var/app" ]]; then
    info "Copiando ~/.var/app para $DEST/var-app/ (sem caches)"
    rsync -a --delete --info=stats1 --exclude='/*/cache/' "$HOME/.var/app/" "$DEST/var-app/"
    ok "Configurações dos Flatpaks salvas."
  fi
else
  warn "Sem DESTINO: ~/.var/app NÃO foi copiado. Ex.: ./scripts/backup.sh /run/media/\$USER/HD/setup-imortal"
fi

# 5. Verificação de privacidade (o repositório é público) --------------------
echo
"$SCRIPT_DIR/check-privacy.sh" || die "Corrija os itens acima antes de fazer commit."

echo
ok "Pronto. Agora salve no GitHub:"
echo "   cd $REPO_DIR && git add -A && git commit -m 'backup $(date +%F)' && git push"
