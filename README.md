# 🐧 Setup Imortal

Um ambiente Linux que você **recria em minutos em qualquer distro**: Fedora, Ubuntu/Debian/Mint, Arch ou openSUSE.

Baseado no vídeo [_O Setup Imortal_](https://www.youtube.com/watch?v=OjtzXG9MdME) (Diolinux), com o passo a passo completo:
do particionamento do disco até a automação da pós-instalação.

## A ideia

> A distro é descartável. **Seus dados, configurações e fluxos, não.**

| 3 pilares básicos (~80%)             | 5 alicerces avançados (~20%)            |
| ------------------------------------ | --------------------------------------- |
| Interface padrão (GNOME ou KDE)      | `/home` separada                        |
| Apps universais (Flatpak, Distrobox) | Snapshots (BTRFS / Timeshift / Snapper) |
| Web apps                             | Dotfiles versionados                    |
|                                      | Sincronização/backup                    |
|                                      | Automação com shell script              |

## Passo a passo

| #   | Etapa                                                                                       | Quando                   |
| --- | ------------------------------------------------------------------------------------------- | ------------------------ |
| 01  | [Planejamento](docs/01-planejamento.md): inventário e checklist                             | antes de formatar        |
| 02  | [Particionamento](docs/02-particionamento.md): tamanhos de EFI, `/`, swap e `/home`         | antes de instalar        |
| 03  | [Instalação por distro](docs/03-instalacao-por-distro.md): ext4 ou BTRFS em cada instalador | durante a instalação     |
| 04  | [Pós-instalação](docs/04-pos-instalacao.md): rodar os scripts                               | primeiro boot            |
| 05  | [Snapshots e backup](docs/05-snapshots-e-backup.md)                                         | primeiro dia             |
| 06  | [Dotfiles](docs/06-dotfiles.md)                                                             | contínuo                 |
| 07  | [Reinstalação e migração](docs/07-reinstalacao-e-migracao.md)                               | quando precisar          |
| 08  | [Manutenção](docs/08-manutencao.md)                                                         | mensal                   |
| 09  | [Adicionar programas](docs/09-adicionar-programas.md): onde colocar cada app                | sempre que instalar algo |

## Início rápido

**Na máquina atual** (antes de formatar):

```bash
git clone https://github.com/SEU-USUARIO/setup-imortal.git ~/setup-imortal
cd ~/setup-imortal
./scripts/backup.sh                 # exporta lista de apps e atalhos (sem dados pessoais)
./scripts/cloud-backup.sh setup     # 1ª vez: conecta Google Drive/Dropbox/MEGA/... (criptografado)
./scripts/cloud-backup.sh run       # backup da /home na nuvem
git add -A && git commit -m "meu setup" && git push
```

**No live USB** (para decidir o particionamento):

```bash
./scripts/partition-calc.sh            # ou: --disk 476 --ram 16 --hibernate
```

**Na máquina nova** (depois de instalar):

```bash
git clone https://github.com/SEU-USUARIO/setup-imortal.git ~/setup-imortal
cd ~/setup-imortal
./scripts/install.sh --dry-run    # simula
./scripts/install.sh              # executa: pacotes, Docker CE, Chrome, VS Code, Flatpaks...
./scripts/cloud-backup.sh setup   # mesma nuvem e MESMA senha
./scripts/cloud-backup.sh restore-flatpak
./scripts/cloud-backup.sh timer on
```

## Estrutura

```
setup-imortal/
├── docs/                    Guias 01–09
├── scripts/
│   ├── install.sh           Pós-instalação (módulos: base apps flatpak distrobox snapshots dotfiles shell desktop)
│   ├── cloud-backup.sh      Backup criptografado da /home na nuvem (restic + rclone)
│   ├── backup.sh            Exporta lista de apps/atalhos para o repositório (+ ~/.var/app para um HD)
│   ├── restore.sh           Restaura ~/.var/app de um HD
│   ├── check-privacy.sh     Procura dados pessoais antes de publicar
│   ├── doctor.sh            Diagnóstico mensal: backup, espaço, Docker, Flatpak, SMART e repositório (só lê)
│   ├── partition-calc.sh    Calcula os tamanhos das partições
│   ├── montar-hd.sh         Monta HDs externos NTFS que dão erro ("disco sujo")
│   ├── formatar-usb.sh      Formata discos USB com segurança (exFAT, ext4 ou NTFS)
│   ├── lib/common.sh        Detecção de distro e funções comuns
│   └── modules/             Um arquivo por módulo
├── packages/                Pacotes nativos (common.txt + um por família de distro)
├── config/
│   ├── native-apps.txt      Apps nativos: docker, google-chrome, vscode
│   ├── flatpaks.txt         Seus apps do Flathub (gerado pelo backup.sh)
│   ├── backup-excludes.txt  O que fica fora do backup na nuvem
│   ├── distrobox.ini        Contêineres (ex.: Arch com AUR)
│   └── desktop/             Atalhos e preferências do GNOME/KDE (gerado pelo backup.sh)
└── dotfiles/                Pacotes do GNU Stow (espelham a sua home): git, shell (comum bash/zsh), zsh, starship
```

## Distros suportadas

| Família  | Exemplos                              | Gerenciador | Snapshots          |
| -------- | ------------------------------------- | ----------- | ------------------ |
| Fedora   | Fedora Workstation/KDE, Nobara        | dnf         | Snapper            |
| Debian   | Debian, Ubuntu, Mint, Pop!\_OS, Zorin | apt         | Timeshift          |
| Arch     | Arch, EndeavourOS, CachyOS, Manjaro   | pacman      | Snapper + snap-pac |
| openSUSE | Tumbleweed, Leap                      | zypper      | Snapper (nativo)   |

## Repositório público

Este repositório foi pensado para ser **público**: você clona de qualquer máquina sem login.
Nada pessoal é versionado:

- nome/e-mail do Git ficam em `~/.gitconfig.local`
- senhas e acessos da nuvem ficam em `~/.config/setup-imortal/` e `~/.config/rclone/`
- caminhos da home viram `@HOME@`
- `./scripts/check-privacy.sh` bloqueia o commit se encontrar algo (instale o hook com `--install-hook`)

> ⚠️ Os scripts foram validados com `shellcheck` e testados em modo `--dry-run`. **Teste numa VM**
> antes de usar na sua máquina principal ([doc 07](docs/07-reinstalacao-e-migracao.md)).
> Nunca versione senhas, chaves SSH/GPG ou tokens.

## Licença

MIT
