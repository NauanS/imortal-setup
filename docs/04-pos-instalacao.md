# 04 · Pós-instalação: do sistema limpo ao seu ambiente

Tempo esperado: **10 a 30 minutos**, a maior parte baixando apps.

## 1. Atualize o sistema e reinicie

```bash
# Fedora              # Ubuntu/Mint/Debian                        # Arch               # openSUSE
sudo dnf upgrade -y   sudo apt update && sudo apt full-upgrade -y  sudo pacman -Syu     sudo zypper dup
```

## 2. Clone o repositório

```bash
# git costuma vir instalado; se não vier, instale pelo gerenciador da distro
git clone https://github.com/SEU-USUARIO/setup-imortal.git ~/setup-imortal
cd ~/setup-imortal
```

## 3. Simule antes de rodar

```bash
./scripts/install.sh --dry-run
```

Isso mostra cada comando sem executar nada. Confira se a distro foi detectada corretamente.

## 4. Rode

```bash
./scripts/install.sh            # tudo, na ordem
./scripts/install.sh flatpak    # ou só um módulo
```

| Módulo | O que faz | Onde você personaliza |
|---|---|---|
| `base` | Pacotes nativos mínimos: git, curl, flatpak, stow, distrobox, podman, rsync, zsh | `packages/common.txt`, `packages/<distro>.txt` |
| `apps` | Apps nativos dos repositórios oficiais: **Docker CE**, **Google Chrome**, **VS Code** | `config/native-apps.txt` |
| `flatpak` | Ativa o Flathub e instala seus apps | `config/flatpaks.txt` |
| `distrobox` | Cria contêineres (ex.: Arch com AUR) | `config/distrobox.ini` |
| `snapshots` | Snapper ou Timeshift, conforme o disco | automático |
| `dotfiles` | Liga os arquivos de `dotfiles/` na sua home | pasta `dotfiles/` |
| `shell` | **zsh** com sugestões pelo histórico, destaque de sintaxe e prompt **Starship** | `dotfiles/zsh/`, `dotfiles/shell/`, `dotfiles/starship/` |
| `desktop` | Restaura atalhos e preferências do GNOME/KDE | `config/desktop/` (gerado pelo backup) |

### Apps nativos (módulo `apps`)

Algumas ferramentas funcionam melhor **fora** do Flatpak: o sandbox atrapalha o acesso ao terminal,
ao Docker e aos SDKs. Elas são instaladas dos repositórios **oficiais dos fabricantes**, e não da distro,
e continuam recebendo atualizações junto com o sistema.

| App | Fedora | Ubuntu/Debian/Mint | Arch | openSUSE |
|---|---|---|---|---|
| **Docker CE** | repo oficial do Docker | repo oficial do Docker | pacote `docker` do Arch¹ | pacote `docker` do openSUSE¹ |
| **Google Chrome** | repo do Google | `.deb` oficial (cadastra o repo) | AUR `google-chrome` | repo do Google |
| **VS Code** | repo da Microsoft | `.deb` oficial (cadastra o repo) | AUR `visual-studio-code-bin`² | repo da Microsoft |

¹ O Docker não publica repositório para Arch e openSUSE. O pacote da própria distro **é** o Docker CE (Engine), com o plugin compose.
² O pacote `code` do repositório oficial do Arch é o Code-OSS, sem o marketplace da Microsoft.

**Docker:** é o **Docker Engine (CE)**, não o Docker Desktop. O script:
1. Remove pacotes antigos/conflitantes (`docker.io`, `podman-docker`, `moby-engine`...)
2. Instala Engine, CLI, containerd e os plugins **`docker compose`** (v2, com espaço, sem hífen) e **buildx**
3. Cria o grupo `docker` e adiciona seu usuário (`usermod -aG docker $USER`), para rodar sem `sudo`
4. Ativa o serviço: `systemctl enable --now docker`

Depois, **encerre a sessão e entre de novo** e teste: `docker run --rm hello-world && docker compose version`.

> ⚠️ Estar no grupo `docker` equivale a ter acesso root (quem roda containers pode montar `/` do sistema).
> É o padrão em máquinas de desenvolvimento. Para isolamento maior, pesquise "Docker rootless".

O Podman (usado pelo Distrobox) convive sem problemas com o Docker.

**Adicionar outro app nativo:** crie uma função `install_<nome>` em `scripts/modules/15-apps.sh`
seguindo o modelo das existentes, e coloque `<nome>` em `config/native-apps.txt`.

**Flatpaks na /home:** `FLATPAK_SCOPE=user ./scripts/install.sh flatpak` instala os apps em
`~/.local/share/flatpak`. Numa reinstalação que preserve a /home, os apps já estarão lá.
A desvantagem é que eles ficam invisíveis para outros usuários do computador.

## 5. Restaure as configurações dos apps

```bash
# Backup na nuvem (doc 05):
./scripts/cloud-backup.sh setup && ./scripts/cloud-backup.sh restore-flatpak
# ou do HD externo:
./scripts/restore.sh /run/media/$USER/HD-Externo/setup-imortal
```

Se você **preservou a /home** na reinstalação, pule este passo: o `~/.var/app` já está lá.

## 6. Finalize

- [ ] Faça login no navegador (os web apps e favoritos voltam)
- [ ] Restaure `~/.ssh` e `~/.gnupg` do pendrive criptografado e corrija as permissões: `chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_*`
- [ ] Encerre a sessão e entre de novo (aplica atalhos e interface)
- [ ] **Ligue o backup automático:** `./scripts/cloud-backup.sh timer on` ([doc 05](05-snapshots-e-backup.md)). Um sistema novo sem backup não é imortal.

## Quando algo falhar

- **Um Flatpak falhou:** o ID pode ter mudado. Busque com `flatpak search nome` e corrija `config/flatpaks.txt`.
- **Um pacote nativo não existe na distro:** mova-o de `common.txt` para o `packages/<distro>.txt` certo.
- Os módulos podem ser rodados de novo com segurança.

---

Próximo: [05 · Snapshots e backup](05-snapshots-e-backup.md)
