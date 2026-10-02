#!/usr/bin/env bash
# Funções compartilhadas pelos scripts do Setup Imortal.
# Não execute este arquivo diretamente: ele é carregado com "source".

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO_DIR
# shellcheck disable=SC2034  # usadas pelos módulos e scripts que carregam este arquivo
DRY_RUN="${DRY_RUN:-0}"
ASSUME_YES="${ASSUME_YES:-0}"

if [[ -t 1 ]]; then
  c_blue=$'\e[1;34m'; c_green=$'\e[1;32m'; c_yellow=$'\e[1;33m'; c_red=$'\e[1;31m'; c_reset=$'\e[0m'
else
  c_blue=''; c_green=''; c_yellow=''; c_red=''; c_reset=''
fi

info() { printf '%s==>%s %s\n' "$c_blue" "$c_reset" "$*"; }
ok()   { printf '%s  ✓%s %s\n' "$c_green" "$c_reset" "$*"; }
warn() { printf '%s  !%s %s\n' "$c_yellow" "$c_reset" "$*" >&2; }
die()  { printf '%sERRO:%s %s\n' "$c_red" "$c_reset" "$*" >&2; exit 1; }

# Executa um comando (ou só mostra, em modo --dry-run).
run() {
  if [[ "$DRY_RUN" == 1 ]]; then
    printf '    [dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

# Executa como root (via sudo quando necessário).
as_root() {
  if [[ $EUID -eq 0 ]]; then run "$@"; else run sudo "$@"; fi
}

# Pergunta sim/não. Com --yes, assume "sim".
confirm() {
  [[ "$ASSUME_YES" == 1 ]] && return 0
  local answer
  read -rp "$1 [s/N] " answer
  [[ "$answer" =~ ^[sSyY]$ ]]
}

# Lê uma lista (um item por linha), ignorando comentários (#) e linhas vazias.
read_list() {
  [[ -f "$1" ]] || return 0
  sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e 's/^[[:space:]]*//' "$1" | grep -v '^$' || true
}

# Define DISTRO = fedora | debian | arch | opensuse
detect_distro() {
  [[ -r /etc/os-release ]] || die "Não encontrei /etc/os-release. Distro não suportada."
  # shellcheck disable=SC1091
  . /etc/os-release
  local ids=" ${ID:-} ${ID_LIKE:-} "
  case "$ids" in
    *" fedora "*)                          DISTRO=fedora ;;
    *" opensuse"*|*" suse "*)              DISTRO=opensuse ;;
    *" arch "*)                            DISTRO=arch ;;
    *" debian "*|*" ubuntu "*)             DISTRO=debian ;;
    *) die "Distro não reconhecida: ${ID:-?} (ID_LIKE=${ID_LIKE:-?})." ;;
  esac
  DISTRO_NAME="${PRETTY_NAME:-$ID}"
  export DISTRO DISTRO_NAME
}

# Atualiza os índices de pacotes.
pkg_refresh() {
  case "$DISTRO" in
    fedora)   as_root dnf makecache ;;
    debian)   as_root apt-get update ;;
    arch)     as_root pacman -Syu --noconfirm ;;   # Arch não suporta atualização parcial
    opensuse) as_root zypper --non-interactive refresh ;;
  esac
}

# Instala pacotes nativos da distro.
pkg_install() {
  (( $# )) || return 0
  case "$DISTRO" in
    fedora)   as_root dnf install -y "$@" ;;
    debian)   as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" ;;
    arch)     as_root pacman -S --needed --noconfirm "$@" ;;
    opensuse) as_root zypper --non-interactive install "$@" ;;
  esac
}

# Sistema de arquivos e subvolume da raiz.
root_fstype()  { findmnt -no FSTYPE /; }
root_subvol()  { findmnt -no OPTIONS / | tr ',' '\n' | sed -n 's/^subvol=//p'; }

# Configurações de interface que valem a pena levar entre distros.
# (Evitamos /org/gnome/shell/ inteiro: extensões variam de distro para distro.)
# shellcheck disable=SC2034
DCONF_PATHS=(
  /org/gnome/desktop/interface/
  /org/gnome/desktop/wm/keybindings/
  /org/gnome/desktop/wm/preferences/
  /org/gnome/desktop/peripherals/
  /org/gnome/desktop/input-sources/
  /org/gnome/settings-daemon/plugins/media-keys/
  /org/gnome/shell/keybindings/
  /org/gnome/mutter/
)
# shellcheck disable=SC2034
KDE_FILES=(
  kdeglobals
  kglobalshortcutsrc
  kwinrc
  kxkbrc
  kcminputrc
  plasma-org.kde.plasma.desktop-appletsrc
)

# Converte /org/gnome/mutter/ -> org_gnome_mutter.ini
dconf_file_for() { local p="${1#/}"; p="${p%/}"; printf '%s.ini' "${p//\//_}"; }

current_desktop() {
  case "${XDG_CURRENT_DESKTOP:-}" in
    *GNOME*) echo gnome ;;
    *KDE*)   echo kde ;;
    *)       echo other ;;
  esac
}

# O repositório é público: o caminho da sua home vira @HOME@ nos arquivos exportados
# e volta ao normal na restauração (funciona mesmo com outro nome de usuário).
anonymize_dir() {
  local f
  while IFS= read -r -d '' f; do
    sed -i "s|$HOME|@HOME@|g" "$f"
  done < <(find "$1" -type f -print0)
}
deanonymize() { sed "s|@HOME@|$HOME|g" "$1"; }

# Grava um arquivo de sistema (ex.: /etc/yum.repos.d/x.repo). Conteúdo vem do stdin.
write_root_file() {
  local dest="$1" content
  content="$(cat)"
  if [[ "$DRY_RUN" == 1 ]]; then
    printf '    [dry-run] gravar %s:\n' "$dest"
    printf '%s\n' "$content" | sed 's/^/      | /'
  else
    printf '%s\n' "$content" | as_root tee "$dest" >/dev/null
  fi
}

# Baixa uma URL para um arquivo (use só com URLs oficiais conhecidas).
download() { run curl -fL --retry 3 --progress-bar -o "$2" "$1"; }

# Verifica se um pacote nativo já está instalado.
pkg_installed() {
  case "$DISTRO" in
    fedora|opensuse) rpm -q "$1" >/dev/null 2>&1 ;;
    debian)          dpkg -s "$1" >/dev/null 2>&1 ;;
    arch)            pacman -Qi "$1" >/dev/null 2>&1 ;;
  esac
}

# Instala um pacote do AUR (Arch). Usa yay/paru se existir; senão, makepkg.
aur_install() {
  local pkg="$1"
  pkg_installed "$pkg" && { ok "$pkg já instalado."; return 0; }
  if command -v yay >/dev/null; then run yay -S --needed --noconfirm "$pkg"; return; fi
  if command -v paru >/dev/null; then run paru -S --needed --noconfirm "$pkg"; return; fi
  pkg_install git base-devel
  local tmp; tmp="$(mktemp -d)"
  run git clone --depth 1 "https://aur.archlinux.org/$pkg.git" "$tmp/$pkg"
  if [[ "$DRY_RUN" == 1 ]]; then
    echo "    [dry-run] (cd $tmp/$pkg && makepkg -si --noconfirm)"
  else
    (cd "$tmp/$pkg" && makepkg -si --noconfirm)
  fi
  rm -rf "$tmp"
}
