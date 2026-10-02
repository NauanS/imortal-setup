# 05 · Snapshots e backup

| | Snapshot | Backup |
|---|---|---|
| Protege contra | atualização quebrada, config errada | SSD morto, roubo, formatação, ransomware |
| Onde fica | **no mesmo disco** | **outro disco/nuvem** |
| O que cobre | sistema (`/`) | seus dados (`/home`) |
| Ferramenta | Snapper / Timeshift | Déjà Dup, restic, Borg, Pika Backup |

Você precisa dos **dois**.

## 1. Snapshots do sistema

O `./scripts/install.sh snapshots` escolhe e instala a ferramenta. Uso no dia a dia:

**Timeshift** (Ubuntu, Mint, Debian, ext4)
```bash
sudo timeshift --create --comments "antes do upgrade"
sudo timeshift --list
sudo timeshift --restore          # interativo
```

**Snapper** (Fedora, Arch, openSUSE)
```bash
sudo snapper -c root create -d "antes do upgrade"
sudo snapper -c root list
sudo snapper -c root undochange 42..0   # desfaz as mudanças desde o snapshot 42
```
- Interface gráfica: **Btrfs Assistant** (Fedora e Arch) ou YaST (openSUSE).
- No Arch, o **snap-pac** cria snapshots automaticamente a cada `pacman`.
- Para **dar boot num snapshot** quando o sistema nem inicia: openSUSE já oferece isso no GRUB.
  No Arch, instale `grub-btrfs`. No Fedora, o `/boot` fica fora do BTRFS, então use `undochange`
  pelo live USB ou por um kernel anterior.

## 2. Backup da /home (regra 3-2-1)

**3** cópias, em **2** mídias diferentes, **1** fora de casa. A nuvem resolve o "fora de casa".

### Opção A: nuvem (Google Drive, Dropbox, OneDrive, MEGA, iCloud...), recomendada

O `scripts/cloud-backup.sh` junta duas ferramentas:
- **rclone:** conecta em praticamente qualquer nuvem.
- **restic:** faz o backup **criptografado no seu computador antes de enviar**. O provedor
  só vê arquivos embaralhados e não consegue ler seus documentos, chaves SSH ou tokens.
  O backup também é incremental (só envia o que mudou) e guarda histórico: 7 diários, 4 semanais e 6 mensais.

```bash
./scripts/cloud-backup.sh setup        # uma vez: conecta a nuvem, define a senha e cria o repositório
./scripts/cloud-backup.sh run          # backup agora
./scripts/cloud-backup.sh timer on     # backup automático diário
./scripts/cloud-backup.sh status       # último backup e estado do timer
```

**No setup**, o assistente do rclone (`rclone config`) pergunta o provedor. Para a maioria:
`n` (novo) → nome `nuvem` → escolha o provedor na lista → aceite os padrões → faça login no navegador.

| Provedor | Grátis | Tipo no rclone | Observações |
|---|---|---|---|
| Google Drive | 15 GB (dividido com Gmail/Fotos) | `drive` | Funciona bem. Para muitos arquivos, crie seu próprio *client ID* (guia do rclone) e evite limites de uso |
| Dropbox | 2 GB | `dropbox` | Simples; pouco espaço grátis |
| OneDrive | 5 GB | `onedrive` | Escolha "OneDrive Personal" no assistente |
| MEGA | 20 GB | `mega` | Bom espaço grátis. Com 2FA ativo, use rclone recente |
| pCloud | até 10 GB | `pcloud` | Escolha a região (EU/US) certa da conta |
| iCloud Drive | 5 GB | `iclouddrive` | Exige rclone **1.69+** e código 2FA. A sessão **expira periodicamente** e precisa ser reconectada (`rclone config reconnect nuvem:`). É a opção menos estável para backup automático |
| Backblaze B2 | 10 GB | `b2` | Pago depois de 10 GB, mas barato e feito para backup (sem limites de API). Melhor custo para volumes grandes |

> 🔑 **A senha do backup é tudo.** Sem ela, ninguém recupera os dados, nem você.
> Guarde no gerenciador de senhas **e** em papel. Ela fica em `~/.config/setup-imortal/restic-password`,
> e a conexão com a nuvem em `~/.config/rclone/rclone.conf`. **Nenhum dos dois vai para o repositório.**

**O que vai para o backup:** a /home inteira, **menos** o que está em `config/backup-excludes.txt`:
caches, lixeira, Downloads, apps Flatpak reinstaláveis, imagens de contêiner, `node_modules`, `.venv` etc.
Edite essa lista à vontade. Se o espaço grátis não bastar, exclua pastas grandes (vídeos, jogos) ou use o B2.

**Na máquina nova:**
```bash
./scripts/cloud-backup.sh setup            # mesma nuvem, mesma pasta, MESMA senha → reconecta
./scripts/cloud-backup.sh restore-flatpak  # só as configurações dos Flatpaks (~/.var/app), direto no lugar
./scripts/cloud-backup.sh restore          # tudo em ~/restaurado-backup, para você copiar o que quiser
```

> Sincronizar ≠ backup. O cliente do Google Drive/Dropbox **sincroniza**: se você apagar
> ou um vírus criptografar um arquivo, a nuvem replica o estrago. O restic guarda **versões**.

### Opção B: HD externo com interface (Déjà Dup ou Pika Backup)
```bash
flatpak install flathub org.gnome.DejaDup     # ou: org.gnome.World.PikaBackup
```
Aponte para o HD externo e agende um backup diário. Exclua `~/.cache`, `~/Downloads` e `~/.local/share/Trash`.
O Déjà Dup também aceita Google Drive e OneDrive diretamente, se você preferir interface gráfica.

### Opção C: HD externo com restic (terminal)
```bash
restic init -r /run/media/$USER/HD/restic
restic -r /run/media/$USER/HD/restic backup ~ --exclude-file config/backup-excludes.txt --exclude-caches
restic -r /run/media/$USER/HD/restic restore latest --target ~/restaurado
```

**O ideal:** nuvem (A) **e** HD externo (B ou C). São duas mídias, uma delas fora de casa.

### Configurações dos Flatpaks
Vão junto com o backup da /home (A, B ou C). O `./scripts/backup.sh DESTINO` também copia
só o `~/.var/app` para um HD, útil como cópia rápida antes de formatar.

## 3. Teste a restauração

**Um backup que nunca foi restaurado não é um backup.** A cada seis meses, restaure
e confira os arquivos. Com a nuvem: `./scripts/cloud-backup.sh restore /tmp/teste-restore`.

---

Próximo: [06 · Dotfiles](06-dotfiles.md)
