#!/usr/bin/env bash
# Setup Imortal - procura dados pessoais antes de publicar o repositório.
#
# Uso: ./scripts/check-privacy.sh                 verifica os arquivos versionáveis
#      ./scripts/check-privacy.sh --install-hook  roda a verificação a cada "git commit"
#
# Procura: seu usuário, seu nome de máquina, caminhos da sua home, e-mails,
# chaves privadas e padrões comuns de tokens/senhas.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

case "${1:-}" in
  -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --install-hook)
    [[ -d "$REPO_DIR/.git" ]] || die "Rode 'git init' primeiro."
    printf '#!/bin/sh\nexec "%s" --staged\n' "$REPO_DIR/scripts/check-privacy.sh" > "$REPO_DIR/.git/hooks/pre-commit"
    chmod +x "$REPO_DIR/.git/hooks/pre-commit"
    ok "Hook instalado: todo commit será verificado. (Pular numa emergência: git commit --no-verify)"
    exit 0 ;;
esac

cd "$REPO_DIR" || exit 1

# Arquivos a verificar: os do stage (hook), os versionáveis (repo git) ou todos.
if [[ "${1:-}" == --staged ]]; then
  mapfile -t files < <(git diff --cached --name-only --diff-filter=ACM)
elif [[ -d .git ]]; then
  mapfile -t files < <(git ls-files --cached --others --exclude-standard)
else
  mapfile -t files < <(find . -type f -not -path './.git/*' | sed 's|^\./||')
fi
# Não verifica este próprio script (ele contém os padrões de busca) nem o LICENSE
# (a licença leva, por natureza, o nome do titular do copyright).
mapfile -t files < <(printf '%s\n' "${files[@]}" | grep -v '^scripts/check-privacy.sh$' | grep -v '^LICENSE$' | grep -v '^$')
(( ${#files[@]} )) || { ok "Nada para verificar."; exit 0; }

user="${USER:-$(id -un)}"
host="$(cat /etc/hostname 2>/dev/null || hostname 2>/dev/null || true)"

# padrão|descrição
checks=(
  "/home/${user}\b|caminho da sua home (/home/${user})"
  "-----BEGIN [A-Z ]*PRIVATE KEY-----|chave privada"
  "gh[pousr]_[A-Za-z0-9]{30,}|token do GitHub"
  "AKIA[0-9A-Z]{16}|chave de acesso da AWS"
  "AIza[0-9A-Za-z_-]{35}|chave de API do Google"
  "xox[baprs]-[A-Za-z0-9-]{10,}|token do Slack"
  "(password|passwd|senha|secret|token|api_key)[[:space:]]*[=:][[:space:]]*['\"]?[^[:space:]'\"#$]{8,}|possível senha/token"
  "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|endereço de e-mail"
)
# Usuário e máquina só se forem nomes específicos (evita falso positivo com "user", "root"...)
if [[ ${#user} -ge 4 && ! "$user" =~ ^(root|user|admin|test|tester|liveuser|ubuntu|fedora)$ ]]; then
  checks+=("\b${user}\b|seu nome de usuário ($user)")
fi
if [[ ${#host} -ge 4 && ! "$host" =~ ^(localhost|fedora|ubuntu|debian|archlinux|linux)$ ]]; then
  checks+=("\b${host}\b|nome da sua máquina ($host)")
fi

# E-mails genéricos que podem aparecer nos exemplos
allow='(seu-email@exemplo\.com|noreply@github\.com|users\.noreply\.github\.com|@example\.(com|org)|git@github\.com)'

found=0
for entry in "${checks[@]}"; do
  pattern="${entry%|*}"; label="${entry##*|}"
  hits="$(grep -EnIi -- "$pattern" "${files[@]}" 2>/dev/null | grep -Eiv "$allow" || true)"
  if [[ -n "$hits" ]]; then
    found=1
    warn "Encontrado: $label"
    printf '%s\n' "$hits" | head -10 | sed 's/^/      /'
  fi
done

if (( found )); then
  echo
  die "Possíveis dados pessoais encontrados. Revise antes de publicar (ou ajuste o arquivo e rode de novo)."
fi
ok "Nenhum dado pessoal encontrado em ${#files[@]} arquivos."
