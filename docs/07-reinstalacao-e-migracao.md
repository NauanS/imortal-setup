# 07 · Reinstalação e migração: onde o setup se prova imortal

> ⚠️ **Antes de qualquer reinstalação:** backup completo da /home num disco externo.
> Preservar a partição funciona quase sempre, mas um clique errado no instalador formata tudo.
> O backup é o seu **plano B**.

## Cenário 1: mesma distro ou outra, **preservando a /home**

### Layout A (ext4)
No instalador, escolha o **particionamento manual** e configure:

| Partição | Ação | Ponto de montagem | Formatar? |
|---|---|---|---|
| EFI | usar | `/boot/efi` | **Não** (sim só se ninguém mais a usar) |
| raiz | usar | `/` | **Sim** |
| swap | usar | swap | tanto faz |
| home | usar | `/home` | ❌ **NÃO**: confira duas vezes |

### Layout B (BTRFS)
Aqui depende do instalador. Resumo seguro:
- **Fedora:** no editor de armazenamento, apague/recrie só o subvolume `root` e reaproveite `home` sem formatar.
- **Ubuntu/Mint:** escolha a partição BTRFS com ponto de montagem `/` e **sem formatar**.
  O instalador substitui o `@` e mantém o `@home`. **Teste antes numa VM**, porque o comportamento muda entre versões.
- **Arch:** monte manualmente, recrie só o `@` (`btrfs subvolume delete` + `create`) e preserve `@home`.
- **Na dúvida:** formate tudo e restaure a /home do backup (cenário 2). É mais lento, mas previsível.

### Depois de instalar
1. **Use o mesmo nome de usuário** de antes. Se o UID mudar (confira com `id`), corrija:
   `sudo chown -R $USER:$USER /home/$USER`
2. `cd ~/setup-imortal && ./scripts/install.sh`. Os dotfiles e o `~/.var/app` já estão lá.

## Cenário 2: disco novo ou formatação total

1. Instale seguindo os docs [02](02-particionamento.md) e [03](03-instalacao-por-distro.md).
2. Restaure a /home do backup (restic, Déjà Dup...). **Ou** restaure só o essencial:
   `git clone` do repositório + `./scripts/install.sh` + `./scripts/restore.sh DESTINO`.

## Cenário 3: trocar de interface (GNOME ↔ KDE)

O vídeo avisa que a /home separada ajuda menos aqui: configurações das duas interfaces
podem se misturar (temas, ícones, apps padrão, portais). Para uma troca limpa:

```bash
# Antes do primeiro login na interface nova (num TTY: Ctrl+Alt+F3)
mv ~/.config ~/.config.antigo
mv ~/.local/share ~/.local/share.antigo
```

Depois, traga de volta **só** o que é de apps (ex.: `~/.config.antigo/nvim`).
O `~/.var/app` (Flatpaks) **não** precisa ser mexido: é independente da interface.

## Cenário 4: teste periódico numa VM (recomendado)

```bash
flatpak install flathub org.gnome.Boxes
```

Crie uma VM de outra distro, clone o repositório, rode `./scripts/install.sh` e anote o que falhou.
**Meta: estar trabalhando em menos de 30 minutos.**

---

Próximo: [08 · Manutenção](08-manutencao.md)
