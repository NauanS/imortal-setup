#!/usr/bin/env bash
# Setup Imortal - backup da /home na nuvem, CRIPTOGRAFADO (restic + rclone).
# Funciona com Google Drive, Dropbox, OneDrive, MEGA, pCloud, iCloud Drive, Backblaze B2...
#
# Uso: ./scripts/cloud-backup.sh COMANDO
#   setup            instala restic/rclone, conecta a nuvem e cria (ou reconecta) o repositório
#   run              faz um backup agora
#   snapshots        lista os backups existentes
#   restore [DEST]   restaura o último backup em DEST (padrão: ~/restaurado-backup)
#   restore-flatpak  restaura só ~/.var/app (configurações dos Flatpaks) no lugar
#   timer on|off     liga/desliga o backup automático diário
#   status           mostra configuração, último backup e estado do timer
#
# Nada daqui vai para o repositório: a configuração fica em ~/.config/setup-imortal/.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

CFG_DIR="$HOME/.config/setup-imortal"
ENV_FILE="$CFG_DIR/backup.env"
PASS_FILE="$CFG_DIR/restic-password"
EXCLUDES="$REPO_DIR/config/backup-excludes.txt"
UNIT="setup-imortal-backup"

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; }

load_env() {
  [[ -f "$ENV_FILE" ]] || die "Backup na nuvem não configurado. Rode: $0 setup"
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  export RESTIC_REPOSITORY RESTIC_PASSWORD_FILE
}

# ---------------------------------------------------------------------------
cmd_setup() {
  detect_distro
  [[ -t 0 ]] || die "O setup é interativo. Rode num terminal."

  # 1. Ferramentas
  local need=()
  command -v restic >/dev/null || need+=(restic)
  command -v rclone >/dev/null || need+=(rclone)
  if (( ${#need[@]} )); then
    info "Instalando: ${need[*]}"
    pkg_install "${need[@]}"
  fi
  check_rclone_version

  # 2. Conta na nuvem (rclone)
  if [[ -z "$(rclone listremotes)" ]]; then
    info "Nenhuma nuvem configurada no rclone. Vamos criar uma agora."
    echo "   No assistente: 'n' (new remote) → dê um nome (ex.: nuvem) → escolha o provedor"
    echo "   → aceite os padrões → faça login no navegador que abrir. Guia: docs/05-snapshots-e-backup.md"
    rclone config
  fi
  echo
  info "Nuvens configuradas no rclone:"
  rclone listremotes | sed 's/^/   /'
  local remote folder
  read -rp "   Qual usar? (nome, sem os dois pontos) " remote
  remote="${remote%:}"
  rclone listremotes | grep -qx "$remote:" || die "Nuvem '$remote' não existe no rclone."
  read -rp "   Pasta na nuvem [setup-imortal-backup]: " folder
  folder="${folder:-setup-imortal-backup}"

  # 3. Senha de criptografia
  mkdir -p "$CFG_DIR"; chmod 700 "$CFG_DIR"
  if [[ ! -s "$PASS_FILE" ]]; then
    echo
    info "Senha de criptografia do backup"
    echo "   Se o backup já existe (máquina nova), digite a MESMA senha de antes."
    echo "   Se é o primeiro, deixe vazio para gerar uma senha forte automaticamente."
    local p1 p2
    read -rsp "   Senha: " p1; echo
    if [[ -z "$p1" ]]; then
      p1="$(head -c 32 /dev/urandom | base64 | tr -d '/+=' | head -c 40)"
      echo
      warn "SENHA GERADA (guarde AGORA no seu gerenciador de senhas):"
      echo
      echo "      $p1"
      echo
      warn "Sem essa senha, NINGUÉM consegue recuperar o backup, nem você."
      read -rp "   Já guardou? Digite 'sim' para continuar: " p2
      [[ "$p2" == sim ]] || die "Setup cancelado. Nada foi criado na nuvem."
    else
      read -rsp "   Repita a senha: " p2; echo
      [[ "$p1" == "$p2" ]] || die "As senhas não conferem."
    fi
    (umask 077; printf '%s' "$p1" > "$PASS_FILE")
  else
    ok "Usando a senha já salva em $PASS_FILE"
  fi

  (umask 077; cat > "$ENV_FILE" <<EOF
# Gerado por cloud-backup.sh setup. NÃO versione este arquivo.
RESTIC_REPOSITORY="rclone:$remote:$folder"
RESTIC_PASSWORD_FILE="$PASS_FILE"
EOF
)
  load_env

  # 4. Cria o repositório ou reconecta a um existente
  if restic cat config >/dev/null 2>&1; then
    ok "Backup existente encontrado em $RESTIC_REPOSITORY. Senha correta."
    echo "   Para restaurar nesta máquina: $0 restore   ou   $0 restore-flatpak"
  else
    if rclone lsf "$remote:$folder/config" >/dev/null 2>&1; then
      die "Já existe um backup em $remote:$folder, mas a senha não confere. Apague $PASS_FILE e rode o setup de novo."
    fi
    info "Criando repositório criptografado em $RESTIC_REPOSITORY"
    restic init
    ok "Repositório criado."
    if confirm "Fazer o primeiro backup agora? (pode demorar)"; then cmd_run; fi
    if confirm "Ligar backup automático diário?"; then cmd_timer on; fi
  fi
}

check_rclone_version() {
  local v minor
  v="$(rclone version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1 || true)"
  minor="${v#*.}"
  if [[ -n "$v" && "${v%%.*}" == 1 && "$minor" -lt 69 ]]; then
    warn "rclone $v é antigo (a distro empacota versões defasadas)."
    warn "iCloud Drive exige 1.69+, e o suporte a 2FA do MEGA é recente."
    if confirm "Instalar a versão oficial mais nova (script de rclone.org)?"; then
      as_root bash -c 'curl -fsSL https://rclone.org/install.sh | bash'
    fi
  fi
}

# ---------------------------------------------------------------------------
cmd_run() {
  load_env
  info "Backup de $HOME → $RESTIC_REPOSITORY"
  nice -n 19 ionice -c3 restic backup "$HOME" \
    --exclude-file "$EXCLUDES" --exclude-caches --one-file-system \
    --tag setup-imortal
  # Guarda: 7 diários, 4 semanais, 6 mensais. "prune" (que libera espaço) só aos domingos,
  # porque é lento em nuvens como Google Drive.
  local prune=()
  [[ "$(date +%u)" == 7 ]] && prune=(--prune)
  restic forget --tag setup-imortal --keep-daily 7 --keep-weekly 4 --keep-monthly 6 "${prune[@]}"
  ok "Backup concluído."
}

cmd_snapshots() { load_env; restic snapshots; }

# Caminho da home gravado no último backup (pode ser outro usuário/máquina).
backup_home() {
  restic snapshots --latest 1 --json | grep -o '"paths":\["[^"]*"' | head -1 | sed 's/.*\["//; s/"$//'
}

cmd_restore() {
  load_env
  local dest="${1:-$HOME/restaurado-backup}" src
  src="$(backup_home)"
  [[ -n "$src" ]] || die "Nenhum backup encontrado."
  info "Restaurando $src (último backup) → $dest"
  mkdir -p "$dest"
  restic restore "latest:$src" --target "$dest"
  ok "Restaurado em $dest. Copie de lá o que precisar."
}

cmd_restore_flatpak() {
  load_env
  local src; src="$(backup_home)"
  [[ -n "$src" ]] || die "Nenhum backup encontrado."
  if command -v flatpak >/dev/null && [[ -n "$(flatpak ps --columns=application 2>/dev/null)" ]]; then
    confirm "Há Flatpaks abertos. Feche-os antes. Continuar mesmo assim?" || exit 1
  fi
  info "Restaurando $src/.var/app → ~/.var/app"
  mkdir -p "$HOME/.var/app"
  restic restore "latest:$src/.var/app" --target "$HOME/.var/app"
  ok "Configurações dos Flatpaks restauradas."
}

# ---------------------------------------------------------------------------
cmd_timer() {
  local unit_dir="$HOME/.config/systemd/user"
  case "${1:-}" in
    on)
      load_env
      mkdir -p "$unit_dir"
      cat > "$unit_dir/$UNIT.service" <<EOF
[Unit]
Description=Setup Imortal - backup da home na nuvem (restic)
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=$REPO_DIR/scripts/cloud-backup.sh run
EOF
      cat > "$unit_dir/$UNIT.timer" <<EOF
[Unit]
Description=Backup diário do Setup Imortal

[Timer]
OnCalendar=daily
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF
      systemctl --user daemon-reload
      systemctl --user enable --now "$UNIT.timer"
      ok "Backup automático diário ligado (roda enquanto você estiver logado; se o PC estava desligado, roda ao ligar)."
      echo "   Ver logs: journalctl --user -u $UNIT.service"
      ;;
    off)
      systemctl --user disable --now "$UNIT.timer" 2>/dev/null || true
      ok "Backup automático desligado."
      ;;
    *) die "Use: $0 timer on|off" ;;
  esac
}

cmd_status() {
  load_env
  echo "Repositório: $RESTIC_REPOSITORY"
  echo "Arquivo da senha: $RESTIC_PASSWORD_FILE"
  echo -n "Timer:       "; systemctl --user is-active "$UNIT.timer" 2>/dev/null || true
  echo "Último backup:"
  restic snapshots --latest 1 --compact 2>/dev/null | sed 's/^/   /' || warn "Não consegui acessar o repositório."
}

# ---------------------------------------------------------------------------
[[ $EUID -eq 0 ]] && die "Rode como seu usuário normal (o backup é da SUA home)."
case "${1:-}" in
  setup)           cmd_setup ;;
  run)             cmd_run ;;
  snapshots)       cmd_snapshots ;;
  restore)         cmd_restore "${2:-}" ;;
  restore-flatpak) cmd_restore_flatpak ;;
  timer)           cmd_timer "${2:-}" ;;
  status)          cmd_status ;;
  -h|--help|"")    usage ;;
  *)               usage; exit 1 ;;
esac
