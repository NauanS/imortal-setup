#!/usr/bin/env bash
# Módulo apps: instala apps nativos a partir dos repositórios OFICIAIS dos fabricantes.
# Lista em config/native-apps.txt. Cada item "nome-do-app" chama install_nome_do_app.
#
# Para adicionar um app novo: crie uma função install_<nome> neste arquivo
# e coloque <nome> em config/native-apps.txt.

module_main() {
  local apps=() app fn failed=()
  mapfile -t apps < <(read_list "$REPO_DIR/config/native-apps.txt")
  (( ${#apps[@]} )) || { ok "config/native-apps.txt vazio. Pulando."; return 0; }

  command -v curl >/dev/null || pkg_install curl

  for app in "${apps[@]}"; do
    fn="install_${app//-/_}"
    if ! declare -F "$fn" >/dev/null; then
      warn "Não sei instalar '$app' (falta a função $fn em scripts/modules/15-apps.sh)."
      failed+=("$app"); continue
    fi
    info "App nativo: $app"
    "$fn" || { warn "Falha ao instalar $app."; failed+=("$app"); }
  done

  (( ${#failed[@]} )) && warn "Com problema: ${failed[*]}"
  return 0
}

# ============================================================================
# Docker CE (Docker Engine) — sem Docker Desktop
# Fonte: https://docs.docker.com/engine/install/
# ============================================================================
install_docker() {
  if command -v docker >/dev/null && docker compose version >/dev/null 2>&1; then
    ok "Docker e o plugin compose já instalados."
  else
    case "$DISTRO" in
      fedora)   docker_fedora ;;
      debian)   docker_debian ;;
      arch)     pkg_install docker docker-compose docker-buildx ;;   # Docker não tem repo para Arch; o pacote oficial do Arch é o Docker CE
      opensuse) pkg_install docker docker-compose
                pkg_install docker-buildx || warn "docker-buildx indisponível nesta versão do openSUSE (opcional)." ;;
    esac
  fi
  docker_post_install
}

docker_fedora() {
  # Remove pacotes antigos/conflitantes, se existirem
  local old=(docker docker-client docker-client-latest docker-common docker-latest
             docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux
             docker-engine moby-engine podman-docker) p rm=()
  for p in "${old[@]}"; do pkg_installed "$p" && rm+=("$p"); done
  (( ${#rm[@]} )) && as_root dnf remove -y "${rm[@]}"

  if [[ ! -f /etc/yum.repos.d/docker-ce.repo ]]; then
    pkg_install dnf-plugins-core
    local url="https://download.docker.com/linux/fedora/docker-ce.repo"
    if dnf --version 2>/dev/null | grep -qi dnf5; then
      as_root dnf config-manager addrepo --from-repofile="$url"    # Fedora 41+ (dnf5)
    else
      as_root dnf config-manager --add-repo "$url"                 # dnf4
    fi
  fi
  pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

docker_debian() {
  # shellcheck disable=SC1091
  . /etc/os-release
  # Ubuntu e derivadas (Mint, Pop!_OS, Zorin) usam o repo "ubuntu" com o codinome base do Ubuntu.
  local os codename
  if [[ -n "${UBUNTU_CODENAME:-}" ]]; then
    os=ubuntu; codename="$UBUNTU_CODENAME"
  else
    os=debian; codename="${DEBIAN_CODENAME:-${VERSION_CODENAME:-}}"     # LMDE usa DEBIAN_CODENAME
  fi
  [[ -n "$codename" ]] || { warn "Não descobri o codinome da distro."; return 1; }

  local old=(docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc) p rm=()
  for p in "${old[@]}"; do pkg_installed "$p" && rm+=("$p"); done
  (( ${#rm[@]} )) && as_root apt-get remove -y "${rm[@]}"

  pkg_install ca-certificates curl
  as_root install -m 0755 -d /etc/apt/keyrings
  as_root curl -fsSL "https://download.docker.com/linux/$os/gpg" -o /etc/apt/keyrings/docker.asc
  as_root chmod a+r /etc/apt/keyrings/docker.asc

  write_root_file /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/$os
Suites: $codename
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
  as_root apt-get update
  pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

# Grupo docker + serviço, para rodar "docker" sem sudo.
docker_post_install() {
  as_root groupadd -f docker
  if id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
    ok "$USER já está no grupo docker."
  else
    as_root usermod -aG docker "$USER"
    ok "$USER adicionado ao grupo docker."
    warn "Encerre a sessão e entre de novo (ou rode 'newgrp docker') para usar docker sem sudo."
  fi
  as_root systemctl enable --now docker.service
  if systemctl list-unit-files containerd.service >/dev/null 2>&1; then
    as_root systemctl enable --now containerd.service
  fi
  echo "   Teste:  docker run --rm hello-world  &&  docker compose version"
  echo "   Atenção: o grupo docker equivale a acesso root. Veja docs/04-pos-instalacao.md."
}

# ============================================================================
# Google Chrome — pacote oficial (.deb/.rpm) com repositório para atualizações
# ============================================================================
CHROME_KEY="https://dl.google.com/linux/linux_signing_key.pub"

install_google_chrome() {
  [[ "$(uname -m)" == x86_64 ]] || { warn "Google Chrome para Linux só existe para x86_64."; return 1; }
  command -v google-chrome-stable >/dev/null && { ok "Google Chrome já instalado."; return 0; }

  case "$DISTRO" in
    debian)
      # O .deb oficial também cadastra o repositório do Google para atualizações.
      local tmp; tmp="$(mktemp -d)"; chmod 755 "$tmp"
      download "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" "$tmp/chrome.deb"
      as_root apt-get install -y "$tmp/chrome.deb"
      rm -rf "$tmp"
      ;;
    fedora)
      as_root rpm --import "$CHROME_KEY"
      write_root_file /etc/yum.repos.d/google-chrome.repo <<EOF
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=$CHROME_KEY
EOF
      pkg_install google-chrome-stable
      ;;
    opensuse)
      as_root rpm --import "$CHROME_KEY"
      write_root_file /etc/zypp/repos.d/google-chrome.repo <<EOF
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=$CHROME_KEY
EOF
      as_root zypper --non-interactive --gpg-auto-import-keys refresh google-chrome
      pkg_install google-chrome-stable
      ;;
    arch)
      aur_install google-chrome
      ;;
  esac
}

# ============================================================================
# Visual Studio Code — repositório oficial da Microsoft (não é o Code-OSS)
# Fonte: https://code.visualstudio.com/docs/setup/linux
# ============================================================================
MS_KEY="https://packages.microsoft.com/keys/microsoft.asc"

install_vscode() {
  command -v code >/dev/null && { ok "VS Code já instalado."; return 0; }

  case "$DISTRO" in
    debian)
      # O .deb oficial cadastra o repositório da Microsoft para atualizações.
      local arch
      case "$(dpkg --print-architecture)" in
        amd64) arch=x64 ;; arm64) arch=arm64 ;; armhf) arch=armhf ;;
        *) warn "Arquitetura sem VS Code."; return 1 ;;
      esac
      local tmp; tmp="$(mktemp -d)"; chmod 755 "$tmp"
      download "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-$arch" "$tmp/code.deb"
      as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "$tmp/code.deb"
      rm -rf "$tmp"
      ;;
    fedora)
      as_root rpm --import "$MS_KEY"
      write_root_file /etc/yum.repos.d/vscode.repo <<EOF
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=$MS_KEY
EOF
      pkg_install code
      ;;
    opensuse)
      as_root rpm --import "$MS_KEY"
      write_root_file /etc/zypp/repos.d/vscode.repo <<EOF
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=$MS_KEY
EOF
      as_root zypper --non-interactive refresh code
      pkg_install code
      ;;
    arch)
      # O pacote "code" do repositório oficial do Arch é o Code-OSS (sem o marketplace da Microsoft).
      aur_install visual-studio-code-bin
      ;;
  esac
}
