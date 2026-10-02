# 06 · Dotfiles

Dotfiles são os arquivos de configuração ocultos (começam com `.`) da sua home.
Este repositório usa o **GNU Stow**: cada pasta dentro de `dotfiles/` é um "pacote" que **espelha a home**.

```
dotfiles/
├── shell/.config/shell/*.sh          →  ~/.config/shell/*.sh   (comum ao bash e ao zsh)
├── zsh/.zshrc                        →  ~/.zshrc
├── starship/.config/starship.toml    →  ~/.config/starship.toml
├── git/.gitconfig                    →  ~/.gitconfig
├── git/.config/git/ignore            →  ~/.config/git/ignore          (.gitignore global)
├── git/.config/git/delta.gitconfig   →  ~/.config/git/delta.gitconfig
└── nvim/.config/nvim/init.lua        →  ~/.config/nvim/init.lua   (exemplo)
```

`./scripts/install.sh dotfiles` cria **links simbólicos**. Quando você edita `~/.gitconfig`, está editando
o arquivo do repositório, e basta um `git commit` para salvar.

## Adicionar uma configuração nova

```bash
# Ex.: levar a config do Neovim para o repositório
mkdir -p ~/setup-imortal/dotfiles/nvim/.config
mv ~/.config/nvim ~/setup-imortal/dotfiles/nvim/.config/
cd ~/setup-imortal && ./scripts/install.sh dotfiles
git add dotfiles/nvim && git commit -m "adiciona nvim"
```

## O que versionar (e o que NÃO versionar)

| ✅ Versione | ❌ Nunca versione |
|---|---|
| `~/.config/shell/`, `.zshrc`, aliases | `~/.ssh/`, `~/.gnupg/` (chaves) |
| `.gitconfig` (sem nome/e-mail) | `~/.gitconfig.local`, tokens, `.env`, senhas, cookies |
| Editor (nvim, VS Code `settings.json`) | `~/.mozilla`, perfis de navegador |
| Terminal (kitty, alacritty, wezterm) | `~/.var/app` inteiro (contém tokens e sessões; vai para o backup, não para o Git) |
| Atalhos e preferências (`config/desktop/`, gerado pelo backup) | Caches e arquivos grandes |

## Repositório público: nada pessoal

Este repositório foi feito para ser **público**, para você clonar de qualquer lugar sem login. Por isso:

- **Nome e e-mail do Git** ficam em `~/.gitconfig.local`, fora do repositório. O `.gitconfig`
  versionado só faz `[include] path = ~/.gitconfig.local`. O `install.sh dotfiles` pergunta e cria esse arquivo.
  Use o e-mail *noreply* do GitHub (Settings → Emails → "Keep my email addresses private").
- **Caminhos da sua home** (`/home/seu-usuario`) viram `@HOME@` nos arquivos exportados pelo `backup.sh`
  e voltam ao normal na restauração, mesmo com outro nome de usuário.
- **Configurações que precisam de dados pessoais:** crie um arquivo `*.local` (ignorado pelo Git)
  e carregue a partir do arquivo versionado. Exemplo: `~/.config/shell/99-pessoal.local.sh` não é versionado.
- **Verificador automático:** procura seu usuário, nome da máquina, e-mails, chaves e tokens.

```bash
./scripts/check-privacy.sh                 # verifica agora (o backup.sh roda sempre)
./scripts/check-privacy.sh --install-hook  # verifica a cada git commit e bloqueia se achar algo
```

## Git: aliases, `.gitignore` global e delta

| Item | Arquivo | O que faz |
|---|---|---|
| Aliases | `.gitconfig` | `git st`, `git co`, `git br`, `git ci`, `git lg` (grafo), `git last`, `git unstage` |
| `.gitignore` global | `~/.config/git/ignore` | vale para todos os repositórios: `.idea/`, `.vscode/`, `.DS_Store`, `.env`, `*.pem`, `*.key`, chaves SSH |
| delta | `delta.gitconfig` | diffs com cores e números de linha. Só é ligado se o `delta` (pacote `git-delta`) estiver instalado |

**O que nunca entra no repositório:** nome, e-mail, credenciais e tokens. O `.gitconfig` versionado só tem
configurações genéricas e termina com `[include] path = ~/.gitconfig.local`. Tudo que é seu fica nesse arquivo
(modo 600, ignorado pelo Git), incluindo o `credential.helper` do `gh`.

Se você já tem um `~/.gitconfig` próprio, o `install.sh dotfiles` **copia o conteúdo dele para `~/.gitconfig.local`**
antes de ligar o do repositório (e ainda guarda o original em `~/.dotfiles-backup-*/`). Assim o login do GitHub
e a sua identidade continuam funcionando. O `.gitignore` global também funciona como rede de segurança contra
commitar `.env` e chaves por acidente.

Se a distro não tiver o pacote `git-delta`, o instalador avisa e segue sem ele; o Git continua normal.

## Shell: zsh, bash e Starship

O módulo `shell` (`./scripts/install.sh shell`) instala o **zsh** e deixa o terminal assim:

| Recurso | De onde vem | Onde fica |
|---|---|---|
| zsh | repositório da distro | sistema |
| zsh-autosuggestions (sugestão em cinza pelo histórico, aceite com `→`) | github.com/zsh-users | `~/.local/share/zsh/plugins/` |
| zsh-syntax-highlighting (comando válido/inválido colorido) | github.com/zsh-users | `~/.local/share/zsh/plugins/` |
| Starship (prompt com branch, status do Git e versões) | release oficial no GitHub, com checksum | `~/.local/bin/starship` |

**Uma pasta só para os dois shells:** tudo que é configuração do terminal (PATH, aliases, prompt)
fica em `~/.config/shell/*.sh`. O `~/.zshrc` e o `~/.bashrc` carregam essa mesma pasta. Quando você
adiciona um alias ali, ele vale no zsh **e** no bash, em qualquer máquina onde o repositório for aplicado.
Os arquivos precisam ser compatíveis com os dois (use `$ZSH_VERSION` / `$BASH_VERSION` para o que for específico).

- O instalador pergunta antes de trocar o shell padrão (`chsh`). O bash continua instalado.
- Não precisa de Nerd Font: o `starship.toml` usa o preset `plain-text-symbols`.
- Depois de trocar o shell, encerre a sessão e entre de novo.
- **Em qualquer terminal:** o módulo `dotfiles` acrescenta ao `~/.bashrc` uma garantia: se um bash
  **interativo** abrir (por exemplo pelo botão direito > "Abrir no terminal", no COSMIC, Konsole ou GNOME
  Terminal), ele passa para o zsh. Isso vale mesmo antes de você encerrar a sessão depois do `chsh`.
  Scripts (`bash script.sh`, `bash -c`) continuam no bash.
- Abrir um bash de propósito: `SETUP_IMORTAL_NO_ZSH=1 bash`.
- Voltar ao bash de vez: `chsh -s /bin/bash` e remova o bloco "abre o zsh" do `~/.bashrc`.

## Configurações da interface

`./scripts/backup.sh` exporta:
- **GNOME:** atalhos, preferências de janela, teclado, mouse e interface (via `dconf`). Extensões
  não são exportadas de propósito, porque variam entre distros.
- **KDE:** `kdeglobals`, `kglobalshortcutsrc`, `kwinrc`, layout de teclado, mouse e painel.

`./scripts/install.sh desktop` restaura, **se você estiver usando a mesma interface**.

---

Próximo: [07 · Reinstalação e migração](07-reinstalacao-e-migracao.md)
