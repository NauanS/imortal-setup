# AGENTS.md — Setup Imortal

Instruções para agentes de IA (Claude Code, Codex, Cursor, Copilot, Gemini CLI e similares)
que trabalham neste repositório.

**Comece pelo README:** leia o [README.md](README.md) antes de qualquer tarefa.
Ele descreve o projeto, a estrutura de pastas e aponta para todos os guias em `docs/`.
Leia o guia relacionado à tarefa antes de alterar qualquer coisa.

---

## O que é este projeto

Um ambiente Linux que se recria em minutos em qualquer distro. O princípio:

> **O sistema é descartável. Dados, configurações e fluxos, não.**

- O que importa vive na **/home** (partição separada), no **repositório** (scripts, listas de
  apps e dotfiles) e no **backup criptografado na nuvem** (restic + rclone).
- Preferência por **interfaces padrão** (KDE Plasma ou GNOME), **apps universais**
  (Flatpak, Distrobox) e **automação** com shell script.
- Regras do projeto: não customizar o sistema a fundo e não depender de recursos exclusivos
  de uma distro.

O usuário principal usa **Kubuntu (KDE Plasma)**, é programador e mantém o repositório **público**.

## Regras inegociáveis

1. **Repositório público: nada pessoal.** Nunca adicione nomes, e-mails, nomes de usuário,
   nomes de máquina, caminhos `/home/<usuário>`, tokens, senhas ou chaves.
   - Identidade do Git fica em `~/.gitconfig.local` (fora do repositório).
   - Segredos da nuvem ficam em `~/.config/setup-imortal/` e `~/.config/rclone/`.
   - Caminhos da home exportados viram `@HOME@` (`anonymize_dir` / `deanonymize` em `common.sh`).`
   - Antes de concluir qualquer tarefa, rode `./scripts/check-privacy.sh`.
2. **As quatro famílias de distro são suportadas:** `fedora` (dnf), `debian` (apt: Debian,
   Ubuntu, Mint, Pop!\_OS), `arch` (pacman + AUR) e `opensuse` (zypper). Toda funcionalidade
   que instala algo precisa tratar as quatro, ou avisar claramente quando não se aplica.
   Distros imutáveis (Silverblue, Aurora, Bluefin) **não** são suportadas.
3. **Nada destrutivo sem confirmação.** Scripts que apagam, formatam ou sobrescrevem:
   - mostram o que será afetado antes;
   - pedem confirmação explícita (para formatar, o usuário digita o nome do disco);
   - scripts de disco (`montar-hd.sh`, `formatar-usb.sh`) **só aceitam discos USB** e
     recusam discos com `/`, `/home`, `/boot` ou swap montados.
4. **Idempotência:** rodar um script ou módulo duas vezes não pode quebrar nada nem duplicar
   configurações. Verifique se algo já existe antes de criar.
5. **Fontes oficiais:** apps nativos vêm do repositório oficial do fabricante (Docker, Google,
   Microsoft). Nunca use scripts ou repositórios de terceiros desconhecidos.

## Onde colocar cada coisa

O guia completo está em [docs/09-adicionar-programas.md](docs/09-adicionar-programas.md). Resumo:

| O quê                                                            | Onde                                                                                          |
| ---------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| Ferramenta de terminal com o mesmo nome em todas as distros      | `packages/common.txt`                                                                         |
| Pacote com nome diferente ou exclusivo de uma distro             | `packages/<distro>.txt`                                                                       |
| App com janela disponível no Flathub                             | `config/flatpaks.txt`                                                                         |
| App que exige integração com o sistema (Docker, Chrome, VS Code) | `config/native-apps.txt` + função `install_<nome>` em `scripts/modules/15-apps.sh`            |
| Pacote de uma distro usado em outra (ex.: AUR)                   | `config/distrobox.ini`                                                                        |
| Configuração em texto (shell, git, editor)                       | `dotfiles/<pacote>/` espelhando a home (GNU Stow)                                             |
| O que não vai para o backup na nuvem                             | `config/backup-excludes.txt`                                                                  |
| Novo módulo do instalador                                        | `scripts/modules/NN-nome.sh` com `module_main()` + registrar em `ALL_MODULES` no `install.sh` |
| Script utilitário avulso                                         | `scripts/nome.sh`                                                                             |

## Convenções dos scripts

- **Bash**, começando com `#!/usr/bin/env bash` e `set -euo pipefail` (ou `set -uo pipefail`
  quando o script trata erros manualmente).
- Cabeçalho com comentário explicando **uso** e **o que o script faz**: o `--help` lê dele.
- Scripts do projeto carregam `scripts/lib/common.sh` e usam as funções dele em vez de reinventar:
  - Saída: `info`, `ok`, `warn`, `die`
  - Execução: `run` (respeita `--dry-run`), `as_root` (sudo só quando preciso), `confirm`
  - Distro: `detect_distro` (define `$DISTRO`), `pkg_refresh`, `pkg_install`, `pkg_installed`, `aur_install`
  - Arquivos: `read_list` (lê listas ignorando `#`), `write_root_file`, `download`
- **Todo comando que altera o sistema passa por `run` ou `as_root`**, para o `--dry-run` funcionar.
- Rodar como usuário normal; recusar execução como root, salvo exceção justificada.
- Mensagens para o usuário em **português do Brasil**, claras e sem jargão desnecessário.
- Listas de configuração (`*.txt`): um item por linha, comentários com `#`.

## Documentação

- Toda a documentação é em **português do Brasil**, em Markdown, dentro de `docs/`,
  numerada (`NN-tema.md`) e ligada a partir da tabela "Passo a passo" do `README.md`.
- Ao criar ou alterar um script, atualize **no mesmo trabalho**:
  - a seção "Estrutura" do `README.md`;
  - o guia em `docs/` que explica o uso (quando usar, comando, o que acontece, cuidados).
- Use tabelas para comparar opções e blocos de código para comandos copiáveis.
- Não afirme versões, nomes de pacotes ou comandos de distro sem verificar.

## Como validar antes de concluir

```bash
shellcheck -x -S warning scripts/*.sh scripts/modules/*.sh scripts/lib/common.sh
./scripts/install.sh --dry-run          # simula o instalador inteiro
./scripts/check-privacy.sh              # nenhum dado pessoal
```

- Teste os links relativos dos docs que você alterou.
- Mudanças que instalam ou apagam algo devem ser testadas numa **VM** antes do uso real
  (veja `docs/07-reinstalacao-e-migracao.md`). Diga ao usuário o que foi e o que não foi testado.

## Commits

- Mensagens curtas em português, no imperativo: `adiciona htop`, `corrige montagem de NTFS`.
- Um assunto por commit.
- Nunca commite arquivos `*.local`, `.env`, chaves ou o conteúdo de `~/.var/app`
  (o `.gitignore` já cobre os casos comuns).
