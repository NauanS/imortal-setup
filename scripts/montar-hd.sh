#!/usr/bin/env bash
# montar-hd.sh — monta HDs externos NTFS (USB) que o Linux recusa por estarem "sujos".
#
# Uso:
#   ./montar-hd.sh              procura HDs USB com NTFS e monta todos
#   ./montar-hd.sh /dev/sdc1    monta só essa partição
#
# O que faz, para cada partição:
#   1. Tenta montar normalmente (udisksctl, igual ao Dolphin)
#   2. Se falhar, mostra o erro e pergunta se pode rodar "ntfsfix -d" (limpa a marca de "sujo")
#   3. Tenta montar de novo
#   4. Avisa se o HD está conectado numa porta USB 2.0 (mais lenta)
#
# Segurança: só mexe em discos conectados via USB. Nunca toca nas partições
# internas (como as do Windows no SSD), mesmo que você passe o nome delas.
set -uo pipefail

if [[ -t 1 ]]; then B=$'\e[1;34m'; G=$'\e[1;32m'; Y=$'\e[1;33m'; R=$'\e[1;31m'; N=$'\e[0m'; else B=; G=; Y=; R=; N=; fi
info() { printf '%s==>%s %s\n' "$B" "$N" "$*"; }
ok()   { printf '%s  ✓%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s  !%s %s\n' "$Y" "$N" "$*"; }
err()  { printf '%s  ✗%s %s\n' "$R" "$N" "$*"; }

[[ $EUID -eq 0 ]] && { err "Rode como seu usuário normal (o script pede sudo só quando precisa)."; exit 1; }
for cmd in lsblk udisksctl; do
  command -v "$cmd" >/dev/null || { err "Comando '$cmd' não encontrado."; exit 1; }
done

# Instala o ntfs-3g (que traz o ntfsfix) se faltar.
ensure_ntfsfix() {
  command -v ntfsfix >/dev/null && return 0
  info "Instalando ntfs-3g (necessário para o ntfsfix)"
  if   command -v apt    >/dev/null; then sudo apt install -y ntfs-3g
  elif command -v dnf    >/dev/null; then sudo dnf install -y ntfs-3g
  elif command -v pacman >/dev/null; then sudo pacman -S --needed --noconfirm ntfs-3g
  elif command -v zypper >/dev/null; then sudo zypper --non-interactive install ntfs-3g
  else err "Não sei instalar o ntfs-3g nesta distro. Instale manualmente."; return 1
  fi
}

# Disco "pai" de uma partição (ex.: /dev/sdc1 -> /dev/sdc).
parent_disk() { echo "/dev/$(lsblk -ndo PKNAME "$1" 2>/dev/null)"; }

is_usb() {
  local disk; disk="$(parent_disk "$1")"
  [[ "$(lsblk -ndo TRAN "$disk" 2>/dev/null)" == usb ]]
}

# Avisa se o disco está numa porta USB 2.0 (480 Mbit/s).
check_usb_speed() {
  local disk dir speed
  disk="$(basename "$(parent_disk "$1")")"
  dir="$(readlink -f "/sys/block/$disk" 2>/dev/null)" || return 0
  while [[ "$dir" != / && -n "$dir" ]]; do
    if [[ -f "$dir/speed" ]]; then
      speed="$(cat "$dir/speed")"
      if [[ "$speed" -le 480 ]]; then
        warn "Conectado em USB 2.0 ($speed Mbit/s). Use uma porta USB 3.0 (azul ou com 'SS') para ficar ~3x mais rápido."
      else
        ok "Conectado em USB 3.x ($speed Mbit/s)."
      fi
      return 0
    fi
    dir="$(dirname "$dir")"
  done
}

mounted_at() { lsblk -no MOUNTPOINT "$1" 2>/dev/null | head -1; }

try_mount() {
  local out
  out="$(udisksctl mount -b "$1" 2>&1)" && { ok "$out"; return 0; }
  LAST_ERROR="$out"
  return 1
}

process() {
  local part="$1" fstype label mp
  [[ -b "$part" ]] || { err "$part não existe."; return 1; }
  if ! is_usb "$part"; then
    err "$part não é um disco USB. Por segurança, este script não mexe em discos internos."
    return 1
  fi

  fstype="$(lsblk -no FSTYPE "$part")"
  label="$(lsblk -no LABEL "$part")"
  echo
  info "Partição $part (${label:-sem nome}, $fstype)"
  check_usb_speed "$part"

  mp="$(mounted_at "$part")"
  if [[ -n "$mp" ]]; then ok "Já está montada em $mp"; return 0; fi

  try_mount "$part" && return 0
  err "Não montou: $LAST_ERROR"
  sudo dmesg 2>/dev/null | grep -iE "ntfs|$(basename "$part")" | tail -3 | sed 's/^/      /'

  if [[ "$fstype" != ntfs ]]; then
    warn "A partição não é NTFS ($fstype): o ntfsfix não se aplica. Veja o erro acima."
    return 1
  fi

  echo
  warn "O disco provavelmente está marcado como 'sujo' (desconectado sem ejetar, ou"
  warn "usado num Windows com 'Inicialização rápida' ligada)."
  read -rp "   Rodar 'sudo ntfsfix -d $part' para corrigir? [s/N] " ans
  [[ "$ans" =~ ^[sSyY]$ ]] || { warn "Pulado."; return 1; }

  ensure_ntfsfix || return 1
  sudo ntfsfix -d "$part" || { err "O ntfsfix falhou. Rode 'chkdsk /f' nesse disco num Windows."; return 1; }

  if try_mount "$part"; then
    echo
    ok "Resolvido! Para não acontecer de novo:"
    echo "     • Sempre clique em 'Ejetar' antes de desconectar o HD"
    echo "     • No Windows, desligue a 'Inicialização rápida' (Opções de Energia)"
  else
    err "Ainda não montou: $LAST_ERROR"
    err "Se o HD também é usado no Windows, rode 'chkdsk /f' nele por lá."
    return 1
  fi
}

# Partições a processar: a passada como argumento, ou todas as NTFS de discos USB.
if (( $# )); then
  parts=("$@")
else
  mapfile -t parts < <(
    lsblk -nrpo NAME,FSTYPE,TYPE | while read -r name fs type; do
      [[ "$type" == part && "$fs" == ntfs ]] && is_usb "$name" && echo "$name"
    done
  )
  if (( ${#parts[@]} == 0 )); then
    warn "Nenhum HD USB com NTFS encontrado. Ele está conectado? Confira com: lsblk -f"
    exit 1
  fi
fi

LAST_ERROR=""
fail=0
for p in "${parts[@]}"; do process "$p" || fail=1; done
exit "$fail"