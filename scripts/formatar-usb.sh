#!/usr/bin/env bash
# formatar-usb.sh — formata um disco USB (HD externo ou pendrive) com segurança.
#
# Uso:
#   ./formatar-usb.sh              lista os discos USB e pergunta qual formatar
#   ./formatar-usb.sh /dev/sdc     formata esse disco (ainda pede confirmação)
#
# O que faz:
#   1. Mostra só discos conectados via USB (discos internos nunca aparecem)
#   2. Mostra o que tem no disco e pede para você DIGITAR o nome dele para confirmar
#   3. Pergunta o formato (exFAT, ext4 ou NTFS) e o nome (rótulo)
#   4. Desmonta, apaga a tabela de partições, cria UMA partição ocupando o disco todo
#   5. Formata e monta, já com você como dono
#
# ⚠️ FORMATAR APAGA TUDO QUE ESTÁ NO DISCO. Copie seus arquivos antes.
set -uo pipefail

if [[ -t 1 ]]; then B=$'\e[1;34m'; G=$'\e[1;32m'; Y=$'\e[1;33m'; R=$'\e[1;31m'; N=$'\e[0m'; else B=; G=; Y=; R=; N=; fi
info() { printf '%s==>%s %s\n' "$B" "$N" "$*"; }
ok()   { printf '%s  ✓%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s  !%s %s\n' "$Y" "$N" "$*"; }
die()  { printf '%s  ✗%s %s\n' "$R" "$N" "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] && die "Rode como seu usuário normal (o script pede sudo só quando precisa)."
for cmd in lsblk sfdisk wipefs udisksctl; do
  command -v "$cmd" >/dev/null || die "Comando '$cmd' não encontrado."
done

install_pkg() {
  info "Instalando $1"
  if   command -v apt    >/dev/null; then sudo apt install -y "$1"
  elif command -v dnf    >/dev/null; then sudo dnf install -y "$1"
  elif command -v pacman >/dev/null; then sudo pacman -S --needed --noconfirm "$1"
  elif command -v zypper >/dev/null; then sudo zypper --non-interactive install "$1"
  else die "Não sei instalar '$1' nesta distro. Instale manualmente."
  fi
}

usb_disks() { lsblk -dnpo NAME,TRAN,TYPE | awk '$2=="usb" && $3=="disk" {print $1}'; }

# ---- 1. Escolher o disco ----------------------------------------------------
mapfile -t disks < <(usb_disks)
(( ${#disks[@]} )) || die "Nenhum disco USB encontrado. Ele está conectado?"

if (( $# )); then
  disk="$1"
else
  echo
  info "Discos USB conectados:"
  for i in "${!disks[@]}"; do
    d="${disks[$i]}"
    printf '   %d) %-10s %8s  %s %s\n' "$((i + 1))" "$d" \
      "$(lsblk -dno SIZE "$d")" "$(lsblk -dno VENDOR "$d" | xargs)" "$(lsblk -dno MODEL "$d" | xargs)"
  done
  read -rp "   Número do disco: " n
  [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#disks[@]} )) || die "Opção inválida."
  disk="${disks[$((n - 1))]}"
fi

# ---- 2. Verificações de segurança --------------------------------------------
[[ -b "$disk" ]] || die "$disk não existe."
[[ "$(lsblk -dno TYPE "$disk")" == disk ]] || die "$disk é uma partição. Passe o disco inteiro (ex.: /dev/sdc, não /dev/sdc1)."
printf '%s\n' "${disks[@]}" | grep -qx "$disk" || die "$disk não é um disco USB. Por segurança, este script não formata discos internos."
if lsblk -nro MOUNTPOINT "$disk" | grep -qxE '/|/home|/boot|/boot/efi|\[SWAP\]'; then
  die "$disk contém partes do sistema em uso (/, /home, /boot ou swap). Abortado."
fi

echo
warn "Conteúdo ATUAL de $disk (tudo isto será APAGADO):"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$disk" | sed 's/^/      /'

# ---- 3. Formato e nome ------------------------------------------------------
echo
info "Formato:"
echo "   1) exFAT  — funciona em Linux, Windows, Mac, TV, videogame (recomendado para HD externo)"
echo "   2) ext4   — só Linux; mais robusto, guarda permissões"
echo "   3) NTFS   — Windows; no Linux pode dar o erro de 'disco sujo'"
read -rp "   Escolha [1]: " f
case "${f:-1}" in
  1) fs=exfat; tool=mkfs.exfat; pkg=exfatprogs; maxlabel=15
     guid=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7 ;;   # Microsoft basic data
  2) fs=ext4;  tool=mkfs.ext4;  pkg=e2fsprogs;  maxlabel=16
     guid=0FC63DAF-8483-4772-8E79-3D69D8477DE4 ;;   # Linux filesystem
  3) fs=ntfs;  tool=mkfs.ntfs;  pkg=ntfs-3g;    maxlabel=32
     guid=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7 ;;
  *) die "Opção inválida." ;;
esac
command -v "$tool" >/dev/null || install_pkg "$pkg"
command -v "$tool" >/dev/null || die "'$tool' continua indisponível."

read -rp "   Nome do disco (rótulo) [Dados]: " label
label="${label:-Dados}"
if (( ${#label} > maxlabel )); then
  label="${label:0:maxlabel}"
  warn "Nome cortado para '$label' (máximo $maxlabel caracteres em $fs)."
fi

# ---- 4. Confirmação final ---------------------------------------------------
echo
warn "Vou APAGAR TUDO em $disk ($(lsblk -dno SIZE "$disk")) e formatar como $fs com o nome '$label'."
read -rp "   Para confirmar, digite o nome do disco ($(basename "$disk")): " typed
[[ "$typed" == "$(basename "$disk")" ]] || die "Confirmação não confere. Nada foi alterado."

# ---- 5. Formatar ------------------------------------------------------------
info "Desmontando partições de $disk"
while read -r part mp; do
  [[ -n "$mp" ]] && { udisksctl unmount -b "$part" >/dev/null 2>&1 || sudo umount "$part" || die "Não consegui desmontar $part. Feche os arquivos abertos nele."; }
done < <(lsblk -nrpo NAME,MOUNTPOINT "$disk" | tail -n +2)

info "Apagando assinaturas antigas e criando tabela GPT com uma partição"
sudo wipefs -a "$disk" >/dev/null || die "Falha ao limpar $disk."
printf 'label: gpt\n,,%s\n' "$guid" | sudo sfdisk --quiet --wipe always "$disk" || die "Falha ao criar a partição."
sudo udevadm settle 2>/dev/null || sleep 2

part="$(lsblk -nrpo NAME,TYPE "$disk" | awk '$2=="part" {print $1; exit}')"
[[ -b "$part" ]] || die "A partição nova não apareceu. Desconecte e reconecte o disco."

info "Formatando $part como $fs"
case "$fs" in
  exfat) sudo mkfs.exfat -L "$label" "$part" ;;
  ext4)  sudo mkfs.ext4 -F -L "$label" -E "root_owner=$(id -u):$(id -g)" "$part" ;;   # você vira o dono
  ntfs)  sudo mkfs.ntfs -f -L "$label" "$part" ;;
esac || die "Falha ao formatar."

# ---- 6. Montar --------------------------------------------------------------
sudo udevadm settle 2>/dev/null || sleep 2
if out="$(udisksctl mount -b "$part" 2>&1)"; then
  ok "$out"
else
  warn "Formatado, mas não montou automaticamente: $out"
  warn "Desconecte e reconecte o disco."
fi

echo
ok "Pronto! $disk formatado como $fs ('$label')."
echo "     Lembre-se: sempre clique em 'Ejetar' antes de desconectar."