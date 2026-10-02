#!/usr/bin/env bash
# Módulo snapshots: escolhe a ferramenta certa conforme distro e sistema de arquivos.
#
#   openSUSE (qualquer)              -> Snapper já vem configurado
#   BTRFS com subvolume "@"          -> Timeshift (modo BTRFS)   [layout Ubuntu/Mint/archinstall]
#   BTRFS em Fedora (subvol "root")  -> Snapper + Btrfs Assistant
#   BTRFS em Arch                    -> Snapper + snap-pac
#   ext4 / outros                    -> Timeshift (modo rsync)

module_main() {
  local fs subvol
  fs="$(root_fstype)"
  subvol="$(root_subvol)"
  info "Raiz em '$fs'${subvol:+ (subvolume $subvol)}"

  if [[ "$DISTRO" == opensuse ]]; then
    ok "openSUSE já vem com Snapper configurado. Use o YaST > Snapper para ver os snapshots."
    return 0
  fi

  if [[ "$fs" != btrfs ]]; then
    setup_timeshift "rsync"
    return 0
  fi

  case "$DISTRO" in
    fedora) setup_snapper_fedora ;;
    arch)   setup_snapper_arch ;;
    *)
      if [[ "$subvol" == "/@" || "$subvol" == "@" ]]; then
        setup_timeshift "btrfs"
      else
        warn "Layout BTRFS sem subvolume '@' (subvol atual: '${subvol:-nenhum}')."
        warn "O Timeshift só funciona no modo BTRFS com os subvolumes @ e @home."
        setup_timeshift "rsync"
      fi
      ;;
  esac
}

setup_timeshift() {
  local mode="$1"
  info "Instalando Timeshift (modo $mode)"
  if ! pkg_install timeshift; then
    warn "Timeshift não disponível nos repositórios desta distro. Instale manualmente."
    return 0
  fi
  ok "Timeshift instalado."
  echo "   Abra o Timeshift uma vez para concluir a configuração:"
  echo "   • Tipo: $( [[ $mode == btrfs ]] && echo 'BTRFS' || echo 'RSYNC (escolha um disco que NÃO seja o do sistema, se tiver)')"
  echo "   • Agenda sugerida: 5 diários + 3 semanais"
  echo "   • Deixe a /home FORA dos snapshots (ela é coberta pelo backup)"
}

enable_snapper_timers() {
  as_root snapper -c root set-config \
    TIMELINE_CREATE=yes TIMELINE_LIMIT_HOURLY=5 TIMELINE_LIMIT_DAILY=7 \
    TIMELINE_LIMIT_WEEKLY=2 TIMELINE_LIMIT_MONTHLY=0 TIMELINE_LIMIT_YEARLY=0 \
    NUMBER_LIMIT=10
  as_root systemctl enable --now snapper-timeline.timer snapper-cleanup.timer
}

setup_snapper_fedora() {
  info "Instalando Snapper para o Fedora"
  pkg_install snapper
  pkg_install btrfs-assistant || warn "Btrfs Assistant indisponível (é só a interface gráfica, opcional)."

  if as_root snapper list-configs 2>/dev/null | grep -q '^root'; then
    ok "Configuração 'root' do Snapper já existe."
  else
    as_root snapper -c root create-config /
  fi
  enable_snapper_timers
  ok "Snapper ativo. Crie snapshots antes de atualizar: sudo snapper -c root create -d 'antes do update'"
}

setup_snapper_arch() {
  info "Instalando Snapper + snap-pac (snapshot automático a cada pacman)"
  pkg_install snapper snap-pac

  if as_root snapper list-configs 2>/dev/null | grep -q '^root'; then
    ok "Configuração 'root' do Snapper já existe."
  elif mountpoint -q /.snapshots; then
    # Layout do archinstall: @.snapshots já montado em /.snapshots.
    # Procedimento da ArchWiki para o Snapper aproveitar o subvolume existente.
    warn "/.snapshots já é um subvolume montado (layout do archinstall)."
    if confirm "Aplicar o procedimento da ArchWiki para integrar o Snapper?"; then
      as_root umount /.snapshots
      as_root rmdir /.snapshots
      as_root snapper -c root create-config /
      as_root btrfs subvolume delete /.snapshots
      as_root mkdir /.snapshots
      as_root mount -a
      as_root chmod 750 /.snapshots
    else
      warn "Pulado. Veja docs/05-snapshots-e-backup.md."
      return 0
    fi
  else
    as_root snapper -c root create-config /
  fi
  enable_snapper_timers
  ok "Snapper ativo. Cada 'pacman -S/-U/-R' agora cria snapshots pre/post."
}
