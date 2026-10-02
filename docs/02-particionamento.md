# 02 · Particionamento: o layout "imortal"

> **Objetivo:** separar o que é **descartável** (o sistema) do que é **seu** (a /home),
> para poder formatar ou trocar de distro sem perder nada.

Calcule os tamanhos para a sua máquina (funciona no live USB):

```bash
./scripts/partition-calc.sh              # detecta RAM e disco
./scripts/partition-calc.sh --hibernate  # se você usa hibernação
./scripts/partition-calc.sh --disk 476 --ram 16   # simular outra máquina
```

---

## 1. Antes de tudo: /var, ~/.var e /home

Esses três costumam ser confundidos:

| Caminho | O que é | Precisa de partição própria? |
|---|---|---|
| `/home` | Seus arquivos **e** as configurações dos seus apps | **Sim.** É o coração do setup imortal |
| `~/.var/app` (= `/home/voce/.var/app`) | Configurações dos **Flatpaks** | Não. Já está **dentro da /home** |
| `/var` | Dados do sistema: logs, cache de pacotes, Flatpaks do sistema, bancos de dados | **Não** em desktop. Separar `/var` é prática de servidor |

O "ponto var" citado no vídeo é o `~/.var`, e não a `/var` do sistema. Com a
`/home` separada, as configurações dos Flatpaks já vêm junto.

> No **Layout B (BTRFS)** separamos `/var/log` e `/var/cache` em **subvolumes**, e não em partições.
> O motivo é outro: não queremos que um rollback de snapshot apague os logs que explicam o que deu errado.

---

## 2. Cada partição e o tamanho recomendado

### EFI (`/boot/efi`): **1 GiB**, FAT32
- Guarda o carregador de boot. Só existe em computadores UEFI, que são praticamente todos depois de 2012.
- 512 MiB costuma bastar, mas **1 GiB** dá folga para vários kernels (systemd-boot) e dual boot.
- **Dual boot com Windows:** **reaproveite** a EFI que já existe e **NÃO formate**.
  Se ela tiver só 100 MiB (padrão do Windows), funciona com GRUB, mas fica apertado para systemd-boot.

### `/boot` separado: **só se o instalador pedir** (1 GiB, ext4)
- O Fedora cria um `/boot` ext4 por padrão. Mantenha.
- Também é necessário com criptografia LUKS + GRUB em algumas distros.
- Nos demais casos, não crie.

### Raiz (`/`): **15% do disco, mínimo 40 GiB e máximo 100 GiB**
O que fica aqui: o sistema, os pacotes nativos, `/var` (logs, cache) e **os Flatpaks instalados no modo system** (`/var/lib/flatpak`).

| Disco | Raiz recomendada |
|---|---|
| 128 GB (~119 GiB) | 40 GiB |
| 256 GB (~238 GiB) | 40 GiB |
| 512 GB (~476 GiB) | ~70 GiB |
| 1 TB (~931 GiB) | 100 GiB |

- **Muitos Flatpaks grandes** (jogos, IDEs, suítes de edição): aumente 20–30 GiB,
  **ou** instale os Flatpaks no modo `user` (`FLATPAK_SCOPE=user`), que guarda os apps na /home.
  Nesse modo, os próprios apps sobrevivem à reinstalação.
- Os contêineres do **Distrobox** (Podman sem root) ficam em `~/.local/share/containers`, ou seja, na /home.

### Swap
A swap é usada quando a RAM enche e para **hibernar** (salvar a RAM no disco e desligar).

| RAM | Sem hibernação | Com hibernação |
|---|---|---|
| até 2 GiB | 2× a RAM | RAM + 2 GiB |
| 2–8 GiB | igual à RAM | RAM + 2 GiB |
| 8–64 GiB | metade da RAM, entre 4 e 8 GiB | RAM + 2 GiB |
| mais de 64 GiB | 4–8 GiB | RAM + 2 GiB (avalie se precisa hibernar) |

- **zram:** o Fedora (e cada vez mais distros) usa swap **comprimida na RAM** por padrão.
  Com zram, a swap em disco pode ser menor, só como reserva.
  **Para hibernar, a swap em disco é obrigatória**, porque a zram some ao desligar.
- **Partição ou arquivo?** Um *swapfile* é mais flexível (dá para mudar o tamanho depois).
  No BTRFS, ele precisa de um subvolume próprio. O passo a passo está no [doc 03](03-instalacao-por-distro.md#swapfile-no-btrfs).
- Hibernação com **Secure Boot** ativo não funciona na maioria das distros (lockdown do kernel).

### `/home`: **todo o resto do disco**
É onde fica tudo o que importa: documentos, `~/.config`, `~/.local`, `~/.var/app`, dotfiles e contêineres.
Quanto maior, melhor.

---

## 3. Layout A: ext4 clássico (partições fixas)

**Vantagens:** simples, funciona em qualquer instalador e é fácil de entender e de recuperar.
**Desvantagem:** os tamanhos são fixos. Se a raiz encher, redimensionar dá trabalho.

Exemplo para **512 GB / 16 GiB de RAM, sem hibernar**:

```
/dev/nvme0n1
├─ nvme0n1p1    1 GiB   FAT32  /boot/efi   (flag: boot, esp)
├─ nvme0n1p2   70 GiB   ext4   /
├─ nvme0n1p3    8 GiB   swap
└─ nvme0n1p4  397 GiB   ext4   /home
```

- Snapshots: **Timeshift no modo RSYNC** (copia a raiz para outro local; ocupa mais espaço).
- Coloque a swap **antes** da /home. Assim, a /home fica no fim do disco e é fácil de aumentar depois.

---

## 4. Layout B: BTRFS com subvolumes (espaço compartilhado)

**Vantagens:** não é preciso adivinhar tamanhos, porque todos os subvolumes compartilham o espaço.
Os snapshots são instantâneos e baratos, e a compressão (zstd) economiza de 20 a 40% em texto e código.
**Desvantagem:** os nomes dos subvolumes mudam de distro para distro, e um erro de configuração é mais difícil de entender.

```
/dev/nvme0n1
├─ nvme0n1p1    1 GiB   FAT32  /boot/efi
└─ nvme0n1p2  475 GiB   BTRFS  (opções: compress=zstd:1,noatime)
   ├─ @            →  /
   ├─ @home        →  /home
   ├─ @log         →  /var/log
   ├─ @cache       →  /var/cache
   ├─ @snapshots   →  /.snapshots   (só se usar Snapper)
   └─ @swap        →  /swap         (swapfile)
```

Por que cada subvolume existe:

| Subvolume | Motivo |
|---|---|
| `@` | Sistema. É ele que vai para os snapshots e volta no tempo |
| `@home` | Seus dados. **Fica fora** dos snapshots do sistema: voltar o sistema no tempo não pode apagar seu trabalho de hoje |
| `@log`, `@cache` | Fora dos snapshots, para que um rollback não apague logs e os snapshots não fiquem inchados de cache |
| `@snapshots` | Onde o Snapper guarda os snapshots |
| `@swap` | Um swapfile não funciona dentro de um subvolume com snapshots nem com compressão |

**Regras importantes do BTRFS:**
- **Timeshift** só funciona se os subvolumes se chamarem exatamente **`@` e `@home`**.
- **Mantenha 10–15% do disco livre.** Snapshots ocupam espaço no mesmo volume, e um BTRFS 100% cheio fica difícil de recuperar.
- **Snapshot não é backup.** Se o SSD morrer, os snapshots morrem junto (veja o [doc 05](05-snapshots-e-backup.md)).

---

## 5. Qual layout escolher?

| Situação | Recomendação |
|---|---|
| Iniciante, quer simplicidade | **A (ext4)** |
| Quer voltar no tempo após uma atualização ruim em segundos | **B (BTRFS)** |
| Disco < 100 GiB | **B**: partições fixas desperdiçam espaço |
| Fedora ou openSUSE | **B**: já é o padrão, basta aceitar |
| Debian puro | **A**: o instalador do Debian não cria subvolumes de forma prática |
| HD mecânico antigo | **A** |

## 6. Criptografia (LUKS)

Em **notebooks**, ative a criptografia de disco no instalador ("Criptografar o disco"/"Encrypt").
Se o notebook for roubado, seus dados continuam protegidos. Funciona com os dois layouts.
**Anote a senha num gerenciador de senhas**: sem ela, não há recuperação.

---

Próximo: [03 · Instalação por distro](03-instalacao-por-distro.md)
