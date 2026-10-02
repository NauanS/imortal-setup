#!/usr/bin/env bash
# Setup Imortal - calcula tamanhos de partição recomendados.
# Pode rodar no live USB, antes de instalar.
#
# Uso: ./scripts/partition-calc.sh [--disk GB] [--ram GB] [--hibernate]
#   --disk GB     tamanho do disco em GiB (padrão: maior disco detectado)
#   --ram GB      memória RAM em GiB (padrão: detectada)
#   --hibernate   reserva swap para hibernação (suspender para o disco)
set -euo pipefail

usage() { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; }

DISK=""; RAM=""; HIBERNATE=0
while (( $# )); do
  case "$1" in
    --disk) DISK="${2:?}"; shift ;;
    --ram)  RAM="${2:?}"; shift ;;
    --hibernate) HIBERNATE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opção desconhecida: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

GIB=$((1024 * 1024 * 1024))
if [[ -z "$RAM" ]]; then
  kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
  RAM=$(( (kb + 524288) / 1048576 ))
fi
if [[ -z "$DISK" ]]; then
  bytes=$(lsblk -dbno SIZE,TYPE 2>/dev/null | awk '$2=="disk"{print $1}' | sort -n | tail -1)
  [[ -n "$bytes" ]] || { echo "Não detectei o disco. Use --disk GB." >&2; exit 1; }
  DISK=$(( bytes / GIB ))
fi
[[ "$RAM" =~ ^[0-9]+$ && "$DISK" =~ ^[0-9]+$ ]] || { echo "Use números inteiros." >&2; exit 1; }
(( RAM > 0 && DISK > 0 )) || { echo "RAM e disco precisam ser maiores que zero." >&2; exit 1; }

clamp() { local v=$1 lo=$2 hi=$3; (( v < lo )) && v=$lo; (( v > hi )) && v=$hi; echo "$v"; }

# ---- Swap -----------------------------------------------------------------
if (( HIBERNATE )); then
  SWAP=$(( RAM + 2 )); SWAP_WHY="hibernação: RAM + 2 GiB"
elif (( RAM <= 2 )); then
  SWAP=$(( RAM * 2 )); SWAP_WHY="RAM ≤ 2 GiB: 2× a RAM"
elif (( RAM <= 8 )); then
  SWAP=$RAM;           SWAP_WHY="RAM entre 2 e 8 GiB: igual à RAM"
else
  SWAP=$(clamp $(( RAM / 2 )) 4 8); SWAP_WHY="RAM > 8 GiB: metade da RAM, entre 4 e 8 GiB"
fi

EFI=1
# ---- Raiz (ext4) ------------------------------------------------------------
ROOT=$(clamp $(( DISK * 15 / 100 )) 40 100)
HOME_EXT4=$(( DISK - EFI - ROOT - SWAP ))
BTRFS=$(( DISK - EFI ))

line() { printf '  %-14s %-10s %-10s %s\n' "$@"; }

echo
echo "Disco: ${DISK} GiB    RAM: ${RAM} GiB    Hibernação: $( (( HIBERNATE )) && echo sim || echo não)"
echo "(Um disco vendido como 512 GB tem ~476 GiB. Os valores abaixo estão em GiB.)"

if (( DISK < 100 )); then
  echo
  echo "⚠  Disco pequeno (< 100 GiB): separar /home desperdiça espaço."
  echo "   Recomendado: Layout B (BTRFS), que divide o espaço de forma flexível."
fi

echo
echo "LAYOUT A — ext4 clássico (partições fixas)"
line "PARTIÇÃO" "TAMANHO" "FORMATO" "PONTO DE MONTAGEM"
line "EFI" "${EFI} GiB" "FAT32" "/boot/efi   (ou /boot no Arch/systemd-boot)"
line "raiz" "${ROOT} GiB" "ext4" "/           (15% do disco, entre 40 e 100)"
line "swap" "${SWAP} GiB" "swap" "—           ($SWAP_WHY)"
if (( HOME_EXT4 > 20 )); then
  line "home" "${HOME_EXT4} GiB" "ext4" "/home       (todo o resto)"
else
  echo "  ⚠  Sobra pouco para /home (${HOME_EXT4} GiB). Prefira o Layout B."
fi

echo
echo "LAYOUT B — BTRFS com subvolumes (espaço compartilhado)"
line "PARTIÇÃO" "TAMANHO" "FORMATO" "CONTEÚDO"
line "EFI" "${EFI} GiB" "FAT32" "/boot/efi"
line "sistema" "${BTRFS} GiB" "BTRFS" "subvolumes abaixo (todo o resto)"
echo "      @           → /"
echo "      @home       → /home"
echo "      @log        → /var/log        (fora dos snapshots)"
echo "      @cache      → /var/cache      (fora dos snapshots)"
echo "      @snapshots  → /.snapshots     (só Snapper)"
echo "      @swap       → /swap           (swapfile de ${SWAP} GiB)"
echo "  Mantenha 10–15% livre (~$(( BTRFS * 12 / 100 )) GiB): snapshots ocupam espaço no mesmo volume."

echo
echo "Dica: se o sistema usar zram (Fedora e outros), a swap em disco pode ser"
echo "menor — ela vira reserva. Para hibernar, a swap em disco continua obrigatória."
