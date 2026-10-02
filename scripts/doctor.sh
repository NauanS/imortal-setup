#!/usr/bin/env bash
# Setup Imortal - diagnóstico de saúde do setup (rode uma vez por mês).
#
# Uso: ./scripts/doctor.sh [--smart]
#   --smart   pede a senha do sudo para ler a saúde dos discos (SMART)
#
# Só LÊ e mostra: não instala, não apaga e não altera nada.
# Confere: backup na nuvem, espaço em / e /home, Docker, runtimes Flatpak órfãos,
# saúde dos discos (SMART) e o repositório (alterações sem commit ou sem push).
# Termina com código 1 se encontrar algum problema grave (útil em automação).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Limites (dias / % de uso)
BACKUP_WARN_DAYS=3
BACKUP_FAIL_DAYS=14
DISK_WARN_PCT=85
DISK_FAIL_PCT=95
COMMIT_WARN_DAYS=60

ASK_SUDO=0
case "${1:-}" in
  -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --smart)   ASK_SUDO=1 ;;
  "")        ;;
  *)         die "Opção desconhecida: $1 (veja --help)" ;;
esac

[[ $EUID -eq 0 ]] && die "Rode como seu usuário normal. Para o SMART, use --smart (o script pede sudo só para isso)."

n_ok=0; n_warn=0; n_fail=0
good()  { ok "$*"; n_ok=$((n_ok + 1)); }
alert() { warn "$*"; n_warn=$((n_warn + 1)); }
fail()  { printf '%s  ✗%s %s\n' "$c_red" "$c_reset" "$*"; n_fail=$((n_fail + 1)); }
note()  { printf '    %s\n' "$*"; }

# Dias entre uma data (formato aceito pelo date -d) e agora.
days_since() {
  local then now
  then="$(date -d "$1" +%s 2>/dev/null)" || return 1
  now="$(date +%s)"
  echo $(( (now - then) / 86400 ))
}

# ---------------------------------------------------------------------------
check_backup() {
  info "Backup na nuvem"
  local env_file="$HOME/.config/setup-imortal/backup.env"
  if [[ ! -f "$env_file" ]]; then
    alert "Backup na nuvem não configurado. Rode: ./scripts/cloud-backup.sh setup"
    return
  fi
  if ! command -v restic >/dev/null; then
    alert "restic não instalado. Rode: ./scripts/cloud-backup.sh setup"
    return
  fi

  local json
  json="$(
    # shellcheck disable=SC1090
    source "$env_file"
    export RESTIC_REPOSITORY RESTIC_PASSWORD_FILE
    timeout 90 restic snapshots --json 2>/dev/null
  )" || { fail "Não consegui ler o repositório (rede, login da nuvem ou senha). Veja: ./scripts/cloud-backup.sh status"; return; }

  local last
  last="$(grep -o '"time":"[^"]*"' <<<"$json" | cut -d'"' -f4 | sort | tail -1)"
  if [[ -z "$last" ]]; then
    fail "O repositório existe, mas não tem nenhum backup. Rode: ./scripts/cloud-backup.sh run"
    return
  fi

  local days
  days="$(days_since "$last")" || { alert "Não entendi a data do último backup: $last"; return; }
  if   (( days >= BACKUP_FAIL_DAYS )); then fail "Último backup há $days dias ($(date -d "$last" '+%d/%m/%Y')). Rode: ./scripts/cloud-backup.sh run"
  elif (( days >= BACKUP_WARN_DAYS )); then alert "Último backup há $days dias ($(date -d "$last" '+%d/%m/%Y'))."
  else good "Último backup há $days dia(s) ($(date -d "$last" '+%d/%m/%Y %H:%M'))."
  fi

  if systemctl --user is-active --quiet setup-imortal-backup.timer 2>/dev/null; then
    good "Backup automático ligado."
  else
    alert "Backup automático desligado. Ligue com: ./scripts/cloud-backup.sh timer on"
  fi
}

# ---------------------------------------------------------------------------
check_space() {
  info "Espaço em disco"
  local seen="" mount dev pct avail
  for mount in / /home; do
    dev="$(findmnt -no SOURCE --target "$mount" 2>/dev/null)" || continue
    [[ " $seen " == *" $dev "* ]] && continue      # /home dentro da mesma partição de /
    seen+=" $dev"
    pct="$(df --output=pcent "$mount" | tail -1 | tr -dc '0-9')"
    avail="$(df -h --output=avail "$mount" | tail -1 | tr -d ' ')"
    if   (( pct >= DISK_FAIL_PCT )); then fail "$mount: ${pct}% usado, só $avail livres."
    elif (( pct >= DISK_WARN_PCT )); then alert "$mount: ${pct}% usado ($avail livres). Mantenha 10–15% livre."
    else good "$mount: ${pct}% usado ($avail livres)."
    fi
  done
  [[ "$(findmnt -no FSTYPE / 2>/dev/null)" == btrfs ]] &&
    note "BTRFS: para ver o espaço real, rode: sudo btrfs filesystem usage /"
  return 0
}

# ---------------------------------------------------------------------------
check_docker() {
  info "Docker"
  if ! command -v docker >/dev/null; then
    note "Docker não instalado (ok)."
    return
  fi
  local out
  if ! out="$(docker system df 2>&1)"; then
    alert "Não consegui falar com o Docker (serviço parado ou usuário fora do grupo docker)."
    return
  fi
  good "Docker responde. Uso de espaço:"
  sed 's/^/      /' <<<"$out"
  note "Para limpar o que não está em uso: docker system prune (confira antes o que será removido)."
}

# ---------------------------------------------------------------------------
check_flatpak() {
  info "Flatpak"
  if ! command -v flatpak >/dev/null; then
    note "Flatpak não instalado."
    return
  fi
  local out count
  # --assumeno só LISTA o que seria removido; não remove nada.
  out="$(LC_ALL=C flatpak uninstall --unused --assumeno 2>&1 </dev/null || true)"
  count="$(grep -cE '^ *[0-9]+\.' <<<"$out" || true)"
  if (( count > 0 )); then
    alert "$count runtime(s) órfão(s). Para remover: flatpak uninstall --unused"
  else
    good "Nenhum runtime órfão."
  fi
}

# ---------------------------------------------------------------------------
check_smart() {
  info "Saúde dos discos (SMART)"
  if ! command -v smartctl >/dev/null; then
    alert "smartctl não instalado. Instale o pacote 'smartmontools' (mesmo nome nas 4 famílias)."
    return
  fi

  local sudo_cmd=(sudo -n)
  if (( ASK_SUDO )); then
    sudo -v || { alert "Sem sudo, não dá para ler o SMART."; return; }
  fi

  local disks=() d out status skipped=0
  while read -r d; do
    [[ -n "$d" ]] && disks+=("$d")
  done < <(lsblk -dno NAME,TYPE 2>/dev/null | awk '$2=="disk" && $1 !~ /^(zram|loop|ram)/ {print $1}')
  (( ${#disks[@]} )) || { note "Nenhum disco encontrado."; return; }

  for d in "${disks[@]}"; do
    if ! out="$("${sudo_cmd[@]}" smartctl -H "/dev/$d" 2>&1)"; then
      # smartctl devolve bits de status mesmo com leitura ok; só desiste se não houver resultado.
      if ! grep -qi 'overall-health\|SMART Health Status' <<<"$out"; then
        if grep -qi 'password\|sudo' <<<"$out"; then skipped=1; continue; fi
        alert "/dev/$d: sem SMART disponível (disco USB/virtual ou sem suporte)."
        continue
      fi
    fi
    status="$(grep -i 'overall-health\|SMART Health Status' <<<"$out" | head -1 | sed 's/.*: *//')"
    if [[ "$status" =~ ^(PASSED|OK)$ ]]; then good "/dev/$d: $status"
    else fail "/dev/$d: $status. Faça backup agora e investigue: sudo smartctl -a /dev/$d"
    fi
  done
  (( skipped )) && alert "SMART pulado: precisa de root. Rode: ./scripts/doctor.sh --smart"
  return 0
}

# ---------------------------------------------------------------------------
check_repo() {
  info "Repositório do setup (dotfiles, listas e scripts)"
  if ! git -C "$REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    alert "$REPO_DIR não é um repositório Git. Sem Git, nada do setup está versionado."
    return
  fi

  local dirty ahead last days
  dirty="$(git -C "$REPO_DIR" status --porcelain | wc -l)"
  if (( dirty > 0 )); then
    alert "$dirty arquivo(s) com alterações sem commit:"
    git -C "$REPO_DIR" status --short | head -10 | sed 's/^/      /'
    note "Salve com: cd $REPO_DIR && git add -A && git commit -m \"...\" && git push"
  else
    good "Nenhuma alteração pendente."
  fi

  if git -C "$REPO_DIR" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    ahead="$(git -C "$REPO_DIR" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
    if (( ahead > 0 )); then alert "$ahead commit(s) ainda não enviados. Rode: git push"
    else good "Tudo enviado ao remoto."
    fi
  else
    alert "A branch atual não tem remoto configurado: o setup não está salvo fora desta máquina."
  fi

  last="$(git -C "$REPO_DIR" log -1 --format=%cI 2>/dev/null || true)"
  if [[ -n "$last" ]] && days="$(days_since "$last")"; then
    if (( days >= COMMIT_WARN_DAYS )); then alert "O último commit foi há $days dias. Há algo novo para registrar?"
    else good "Último commit há $days dia(s)."
    fi
  fi
}

# ---------------------------------------------------------------------------
echo "Diagnóstico do Setup Imortal: $(date '+%d/%m/%Y %H:%M')"
echo

check_backup; echo
check_space;  echo
check_docker; echo
check_flatpak; echo
check_smart;  echo
check_repo;   echo

printf 'Resumo: %s%d ok%s, %s%d aviso(s)%s, %s%d problema(s)%s\n' \
  "$c_green" "$n_ok" "$c_reset" "$c_yellow" "$n_warn" "$c_reset" "$c_red" "$n_fail" "$c_reset"
(( n_fail == 0 ))
