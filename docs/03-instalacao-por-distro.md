# 03 · Instalação por distro

> Os nomes dos botões mudam de versão para versão dos instaladores.
> O que importa é o **resultado**, e ele pode ser conferido na [seção 7](#7-conferindo-o-resultado).

Resumo:

| Distro | Layout A (ext4) | Layout B (BTRFS) | Nomes dos subvolumes | Snapshots |
|---|---|---|---|---|
| Fedora | Particionamento manual | **Padrão** | `root`, `home` | Snapper |
| Ubuntu / Mint | Particionamento manual | Manual, escolhendo btrfs | `@`, `@home` | Timeshift |
| Debian | **Recomendado** | Complicado (ver abaixo) | `@rootfs` | Timeshift (rsync) |
| Arch (archinstall) | Opção no menu | Opção no menu | `@`, `@home`, `@log`, `@pkg`, `@.snapshots` | Snapper |
| openSUSE | Manual | **Padrão** | layout próprio | Snapper (pronto) |

---

## 1. Fedora (Workstation, KDE e demais edições)

**Layout B (padrão):** escolha "Usar o disco inteiro"/"Use entire disk". O Fedora cria:
EFI (~600 MiB) + `/boot` ext4 (1 GiB) + BTRFS com os subvolumes `root` → `/` e `home` → `/home`, e swap em **zram**.
Não precisa mudar nada.

- Os subvolumes **não** se chamam `@`, então o Timeshift não funciona. Use **Snapper + Btrfs Assistant**,
  que o `./scripts/install.sh snapshots` configura.
- Quer hibernar? Crie um swapfile (veja [Swapfile no BTRFS](#swapfile-no-btrfs)).

**Layout A:** no instalador, escolha o particionamento personalizado (editor de armazenamento/blivet-gui)
e crie as partições com os tamanhos do `partition-calc.sh`. Mantenha o `/boot` de 1 GiB que o Fedora pede.

## 2. Ubuntu, Linux Mint, Pop!_OS, Zorin

**Layout A:** escolha "Algo diferente"/"Instalação manual" e crie:
1. EFI: 1 GiB, "Partição de sistema EFI" (reaproveite a do Windows em dual boot, sem formatar)
2. `/`: tamanho do cálculo, ext4
3. swap: tamanho do cálculo, "área de troca"
4. `/home`: o resto, ext4

**Layout B:** no particionamento manual, crie EFI + **uma** partição com o resto, formato **btrfs**, ponto de montagem `/`.
O instalador cria automaticamente os subvolumes `@` e `@home`, que é exatamente o que o Timeshift precisa.
Depois de instalar, confira com `sudo btrfs subvolume list /`.

- Para ter `@log` e `@cache`, siga a [seção 6](#6-extra-criar-log-e-cache-depois-da-instalação) (opcional).
- Ubuntu e Mint criam um `/swap.img`/swapfile por padrão. No BTRFS, prefira o método da [seção Swapfile](#swapfile-no-btrfs).

## 3. Debian

Use o **Layout A**. No "Particionamento manual" do instalador, crie as 4 partições como no Ubuntu.
O instalador do Debian coloca a raiz BTRFS num subvolume `@rootfs` e não cria `@home`.
Isso funciona, mas não é compatível com o Timeshift no modo BTRFS. O `install.sh` detecta
esse caso e usa o Timeshift no modo rsync.

## 4. Arch Linux (archinstall)

Rode `archinstall` no live USB e, em **Disk configuration**:
- **Layout A:** "Use a best-effort default partition layout" → **ext4** → responda **sim** para
  "separate partition for /home". Ajuste os tamanhos no modo manual se quiser.
- **Layout B:** escolha **btrfs** → **sim** para "use BTRFS subvolumes with a default structure" → **sim** para compressão.
  Ele cria `@`, `@home`, `@log`, `@pkg` e `@.snapshots`, um layout excelente.
- **Swap:** o archinstall ativa **zram** por padrão. Para hibernar, crie um swapfile depois.
- O `./scripts/install.sh snapshots` detecta o `@.snapshots` e integra o Snapper (procedimento da ArchWiki).

## 5. openSUSE Tumbleweed / Leap

Aceite a **proposta padrão** do instalador: BTRFS com um conjunto completo de subvolumes e o **Snapper já
configurado**, inclusive com snapshots automáticos a cada `zypper`. Sem nada para mudar.
Para o Layout A, use o "Particionador especialista" (Expert Partitioner).

---

## Swapfile no BTRFS

Só necessário para **hibernar** ou se você não usa zram. Use o tamanho do `partition-calc.sh`:

```bash
# 1. Subvolume próprio (ele fica fora dos snapshots do sistema)
sudo btrfs subvolume create /swap

# 2. Cria o swapfile (btrfs-progs 6.1+ já desativa compressão e CoW)
sudo btrfs filesystem mkswapfile --size 8g --uuid clear /swap/swapfile

# 3. Ativa agora e em todo boot
sudo swapon /swap/swapfile
echo '/swap/swapfile none swap defaults 0 0' | sudo tee -a /etc/fstab

# 4. Confere
swapon --show
```

A hibernação precisa de passos extras (`resume=` e `resume_offset=` no kernel), que variam
de distro para distro. Veja o guia da sua distro por "hibernation btrfs swapfile".

---

## 6. Extra: criar @log e @cache depois da instalação

**Opcional e avançado.** Vale para Ubuntu e Mint no Layout B. Faça logo após instalar, antes de acumular dados:

```bash
# Monte a raiz do BTRFS (o "topo", fora do @)
DEV=$(findmnt -no SOURCE / | sed 's/\[.*\]//')
sudo mount -o subvolid=5 "$DEV" /mnt

# Crie os subvolumes e copie o conteúdo atual
sudo btrfs subvolume create /mnt/@log
sudo btrfs subvolume create /mnt/@cache
sudo cp -a /var/log/.   /mnt/@log/
sudo cp -a /var/cache/. /mnt/@cache/
sudo umount /mnt

# Adicione ao /etc/fstab (troque UUID pelo de "sudo blkid $DEV")
# UUID=xxxx  /var/log    btrfs  subvol=@log,compress=zstd:1,noatime    0 0
# UUID=xxxx  /var/cache  btrfs  subvol=@cache,compress=zstd:1,noatime  0 0
sudo nano /etc/fstab
sudo systemctl daemon-reload && sudo mount -a && reboot
```

Depois de reiniciar, confira com `findmnt /var/log`. Os arquivos antigos que ficaram dentro do `@`
são escondidos pelo novo mount e podem ser limpos mais tarde.

---

## 7. Conferindo o resultado

Rode estes comandos logo depois da primeira inicialização:

```bash
lsblk -f                         # partições, formatos e pontos de montagem
findmnt / /home /boot/efi        # o que está montado onde
swapon --show                    # swap ativa (zram aparece como /dev/zram0)
sudo btrfs subvolume list /      # (BTRFS) nomes dos subvolumes
```

✅ **Deu certo se** `/home` aparece numa **partição ou subvolume diferente** da `/`.

---

Próximo: [04 · Pós-instalação](04-pos-instalacao.md)
