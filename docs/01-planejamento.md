# 01 · Planejamento (antes de formatar)

> Regra de ouro: **nada é formatado antes de existir uma cópia fora do computador.**

## 1. Mentalidade (as duas regras do vídeo)

1. **Não customize fundo demais.** Fique perto do padrão da interface. Cada ajuste é algo que você vai ter que refazer.
2. **Não se apegue a recursos exclusivos** de uma distro ou interface. Para cada um, tenha um plano B que funcione em qualquer lugar.

## 2. Inventário

Preencha esta tabela (pode ser em `config/reference/inventario.md`; o repositório é público, então nada pessoal):

| App/recurso | Hoje instalado como | Existe no Flathub? | Versão web? | Plano |
|---|---|---|---|---|
| Ex.: VS Code | .deb | Sim | Sim (vscode.dev) | Nativo (`config/native-apps.txt`) |
| Ex.: autotiling do Pop!_OS | exclusivo | — | — | Extensão "Tiling Shell" ou aceitar perder |

- Consulte `flatpak search NOME` ou https://flathub.org.
- O que não existe como Flatpak: **Distrobox** (`config/distrobox.ini`) ou pacote nativo em `packages/<distro>.txt`.

## 3. Checklist antes de formatar

- [ ] Rode `./scripts/backup.sh /caminho/do/HD-externo` (exporta Flatpaks, atalhos e `~/.var/app`)
- [ ] Rode `./scripts/cloud-backup.sh run` (backup completo da /home na nuvem) e confira com `status`
- [ ] `git commit` + `git push` do repositório
- [ ] **Backup completo da /home** num disco externo (veja o [doc 05](05-snapshots-e-backup.md)), mesmo que você pretenda preservar a partição
- [ ] **Chaves SSH/GPG** (`~/.ssh`, `~/.gnupg`): copie para um pendrive criptografado ou para o gerenciador de senhas. **Nunca para o Git.**
- [ ] Senhas: tudo no gerenciador de senhas (Bitwarden, KeePassXC...), com acesso testado em outro aparelho
- [ ] Navegador: sincronização ligada e conferida (favoritos, extensões e senhas)
- [ ] Anote seu **nome de usuário** atual (`whoami`). Use o **mesmo** na reinstalação.
- [ ] Anote a estrutura atual do disco: `lsblk -f > config/reference/disco-antes.txt` (ignorado pelo Git)
- [ ] Dual boot? Anote qual partição é a EFI do Windows e **não a formate**

## 4. Pendrive de instalação

- **Ventoy** (https://ventoy.net): coloque várias ISOs num pendrive só. Ótimo para testar distros.
- Ou a ferramenta oficial da distro: Fedora Media Writer, balenaEtcher etc.
- Dê boot no live USB e rode `./scripts/partition-calc.sh` (clone o repositório ou copie a pasta para o pendrive).

## 5. Firmware (BIOS/UEFI)

- Confirme que o modo de boot é **UEFI** (não "Legacy/CSM").
- **Secure Boot:** Fedora, Ubuntu, Mint, Debian e openSUSE funcionam com ele ligado. O Arch exige configuração extra.
  Drivers NVIDIA proprietários com Secure Boot pedem cadastro de chave (MOK) no primeiro boot.

---

Próximo: [02 · Particionamento](02-particionamento.md)
