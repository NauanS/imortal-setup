#!/usr/bin/env bash
# Módulo desktop: restaura atalhos e preferências salvos por scripts/backup.sh.

module_main() {
  local desk
  desk="$(current_desktop)"

  case "$desk" in
    gnome) restore_gnome ;;
    kde)   restore_kde ;;
    *)     warn "Interface '${XDG_CURRENT_DESKTOP:-desconhecida}' não suportada por este módulo. Pulando." ;;
  esac
}

restore_gnome() {
  local src="$REPO_DIR/config/desktop/gnome" path file n=0
  command -v dconf >/dev/null || { warn "dconf não encontrado."; return 0; }
  for path in "${DCONF_PATHS[@]}"; do
    file="$src/$(dconf_file_for "$path")"
    [[ -s "$file" ]] || continue
    if [[ "$DRY_RUN" == 1 ]]; then
      echo "    [dry-run] dconf load $path < $file"
    else
      deanonymize "$file" | dconf load "$path"
    fi
    n=$((n + 1))
  done
  if (( n )); then ok "GNOME: $n grupos de configurações restaurados."
  else warn "Nada salvo em config/desktop/gnome/. Rode ./scripts/backup.sh na máquina antiga."; fi
}

restore_kde() {
  local src="$REPO_DIR/config/desktop/kde" f n=0
  local stamp; stamp="$(date +%Y%m%d-%H%M%S)"
  for f in "${KDE_FILES[@]}"; do
    [[ -s "$src/$f" ]] || continue
    [[ -e "$HOME/.config/$f" ]] && run cp "$HOME/.config/$f" "$HOME/.config/$f.bak-$stamp"
    if [[ "$DRY_RUN" == 1 ]]; then echo "    [dry-run] restaurar $f"; else deanonymize "$src/$f" > "$HOME/.config/$f"; fi
    n=$((n + 1))
  done
  if (( n )); then
    ok "KDE: $n arquivos restaurados."
    warn "Encerre a sessão AGORA (sem mexer no painel) para o Plasma não sobrescrever os arquivos."
  else
    warn "Nada salvo em config/desktop/kde/. Rode ./scripts/backup.sh na máquina antiga."
  fi
}
