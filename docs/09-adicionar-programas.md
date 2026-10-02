# 09 · Como adicionar programas ao setup

> Regra de ouro: **se você instalou na mão, coloque no repositório.**
> O que não estiver aqui não volta na próxima reinstalação.

## Onde colocar cada programa

Siga as perguntas na ordem e pare na primeira resposta "sim":

| #   | Pergunta                                                                               | Se sim, coloque em                                                 | Exemplos                                         |
| --- | -------------------------------------------------------------------------------------- | ------------------------------------------------------------------ | ------------------------------------------------ |
| 1   | Precisa de integração forte com o sistema (serviço, grupo, repositório do fabricante)? | `config/native-apps.txt` + receita em `scripts/modules/15-apps.sh` | Docker, Google Chrome, VS Code                   |
| 2   | É um app com janela e existe no [Flathub](https://flathub.org)?                        | `config/flatpaks.txt`                                              | VLC, Obsidian, GIMP, Bitwarden                   |
| 3   | É uma ferramenta de terminal com o **mesmo nome** em todas as distros?                 | `packages/common.txt`                                              | htop, btop, tree, jq, ncdu                       |
| 4   | O pacote só existe ou tem **nome diferente** numa distro?                              | `packages/<distro>.txt`                                            | `build-essential` (Debian) / `base-devel` (Arch) |
| 5   | Só existe numa distro (ex.: AUR) e você usa em outra?                                  | `config/distrobox.ini`                                             | pacotes do AUR rodando no Ubuntu                 |

## Como adicionar, caso a caso

### Pacote nativo simples (`packages/`)

1. Descubra o nome do pacote: `apt search nome`, `dnf search nome`, `pacman -Ss nome` ou `zypper search nome`.
2. Se o nome for igual nas quatro famílias, adicione uma linha em `packages/common.txt`.
   Se não, adicione em cada `packages/<distro>.txt` com o nome certo.
3. Instale agora: `./scripts/install.sh base`

### App Flatpak (`config/flatpaks.txt`)

1. Encontre o ID do app: `flatpak search nome` ou a página dele no Flathub
   (ex.: `org.videolan.VLC`).
2. Adicione o ID numa linha nova em `config/flatpaks.txt`.
3. Instale agora: `./scripts/install.sh flatpak`

> Se você instalou Flatpaks pela loja de apps, rode `./scripts/backup.sh`: ele
> regrava o `config/flatpaks.txt` com todos os apps instalados.

### App nativo do fabricante (`config/native-apps.txt`)

1. Em `scripts/modules/15-apps.sh`, crie uma função `install_<nome>` (troque `-` por `_`)
   copiando o modelo de uma existente (`install_vscode` é a mais simples).
   Use o repositório **oficial** do fabricante e trate as quatro famílias:
   `fedora`, `debian`, `arch` e `opensuse`.
2. Adicione `<nome>` numa linha nova em `config/native-apps.txt`.
3. Teste sem instalar: `./scripts/install.sh --dry-run apps`
4. Instale: `./scripts/install.sh apps`

### Contêiner Distrobox (`config/distrobox.ini`)

1. Descomente ou adicione um bloco seguindo o exemplo do próprio arquivo.
2. Crie: `./scripts/install.sh distrobox`

## Depois de adicionar

```bash
git add -A
git commit -m "adiciona <programa>"
git push
```

O `check-privacy.sh` roda no commit (se você instalou o hook) e bloqueia se houver algo pessoal.

## Configurações de programas

Instalar é só metade. Se você personalizou o programa:

| Onde fica a configuração                                             | O que fazer                                             |
| -------------------------------------------------------------------- | ------------------------------------------------------- |
| Arquivo de texto em `~/.config/` ou na home (ex.: `.bashrc`, `nvim`) | Leve para `dotfiles/` (veja o [doc 06](06-dotfiles.md)) |
| App Flatpak (`~/.var/app/`)                                          | Já vai no backup da nuvem; **não** coloque no Git       |
| Atalhos e preferências do KDE/GNOME                                  | `./scripts/backup.sh` exporta para `config/desktop/`    |
| Contém senha, token ou e-mail                                        | **Nunca** no Git. Use um arquivo `*.local` (ignorado)   |
