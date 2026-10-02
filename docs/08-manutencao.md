# 08 · Manutenção

## Mensal (5 minutos)

### Diagnóstico em um comando: `doctor.sh`

```bash
./scripts/doctor.sh            # confere tudo e mostra um resumo
./scripts/doctor.sh --smart    # inclui a saúde dos discos (pede a senha do sudo)
```

O script **só lê e mostra**: não instala, não apaga e não altera nada. Ele confere:

| Verificação | Aviso quando | Problema quando |
|---|---|---|
| Último backup na nuvem (e se o timer está ligado) | há 3 dias ou mais | há 14 dias ou mais, ou o repositório não abre |
| Espaço livre em `/` e `/home` | 85% usado | 95% usado |
| Docker (`docker system df`) | o Docker não responde | (só informa o uso) |
| Runtimes Flatpak órfãos | existe algum | |
| Saúde dos discos (SMART) | `smartctl` ausente ou sem permissão | o disco **não** passa no teste |
| Repositório: alterações sem commit, commits sem push, último commit antigo | qualquer um deles | |

No fim mostra o resumo e termina com código 1 se houver algum **problema** (útil para automação).
O SMART precisa do pacote `smartmontools`, que não é instalado automaticamente.
Um disco com SMART reprovado pede **backup imediato**.

### Se o `doctor.sh` avisar, os comandos manuais são estes

```bash
cd ~/setup-imortal
./scripts/backup.sh /run/media/$USER/HD-Externo/setup-imortal
git add -A && git commit -m "backup $(date +%F)" && git push   # o backup.sh já verifica dados pessoais
```

- [ ] Rode `./scripts/doctor.sh` e resolva os avisos
- [ ] Confira se o backup na nuvem rodou: `./scripts/cloud-backup.sh status`
- [ ] Se usa iCloud Drive: reconecte a sessão quando expirar (`rclone config reconnect nuvem:`)
- [ ] `flatpak uninstall --unused` (remove runtimes órfãos)
- [ ] Espaço livre: `df -h /` e, no BTRFS, `sudo btrfs filesystem usage /` (mantenha 10–15% livre)

## A cada instalação de app novo

1. Prefira Flatpak. Se não existir, use Distrobox.
2. Ferramentas de desenvolvimento que precisam de integração com o sistema (Docker, IDEs, navegador principal)
   vão como app nativo do repositório oficial: receita em `scripts/modules/15-apps.sh` + `config/native-apps.txt`.
   Pacotes simples da distro vão em `packages/<distro>.txt`.
3. Se você configurou algo pelo terminal, **adicione o comando a um script**:
   se dá para fazer no terminal, dá para automatizar.

## Semestral

- [ ] Teste de restauração do backup ([doc 05](05-snapshots-e-backup.md#3-teste-a-restauração))
- [ ] Teste completo numa VM ([doc 07](07-reinstalacao-e-migracao.md#cenário-4-teste-periódico-numa-vm-recomendado))
- [ ] Revise `config/flatpaks.txt` e remova o que você não usa mais

## Sinais de que o setup está "mortal" de novo

- Você instalou algo "só para testar" com `sudo make install` e esqueceu
- Há customizações que só existem na sua máquina e não estão no repositório
- O último `git push` foi há meses

## A cada instalação de app novo

Coloque o programa no repositório seguindo o [doc 09](09-adicionar-programas.md),
para ele voltar sozinho na próxima reinstalação.

## HD externo não monta

Quando um HD externo NTFS foi desconectado sem ejetar, ou usado num Windows com
"Inicialização rápida" ligada, ele fica marcado como "sujo" e o Linux se recusa a montá-lo.

```bash
./scripts/montar-hd.sh              # encontra e monta todos os HDs USB com NTFS
./scripts/montar-hd.sh /dev/sdc1    # ou só uma partição específica
```

O script tenta montar normalmente. Se falhar, pergunta antes de rodar `ntfsfix -d`
(que limpa a marca de "sujo") e tenta de novo. Por segurança, só mexe em discos USB:
nunca toca nas partições internas do Windows.

Para evitar o problema:

- Sempre clique em **Ejetar** antes de desconectar o HD.
- No Windows: Painel de Controle → Opções de Energia → "Escolher a função dos botões
  de energia" → desmarque **"Ligar inicialização rápida"**.
- Se o HD não precisa funcionar no Windows, considere formatá-lo em **exFAT** ou **ext4**.

## Discos externos (HD USB e pendrive)

Dois scripts cuidam dos discos externos:

| Script            | Quando usar                                | Apaga dados?  |
| ----------------- | ------------------------------------------ | ------------- |
| `montar-hd.sh`    | O HD não monta ou dá erro ao abrir         | **Não**       |
| `formatar-usb.sh` | Você quer apagar o disco e mudar o formato | **Sim, tudo** |

Por segurança, os dois **só mexem em discos conectados via USB**. As partições internas
(o SSD do sistema e o do Windows) nunca aparecem nem são aceitas, mesmo que você digite o nome delas.

### HD não monta: `montar-hd.sh`

**Sintoma:** você conecta o HD, ele aparece no Dolphin, mas dá erro ao abrir
("não foi possível montar", "volume is dirty" ou parecido).

**Causa:** HDs em **NTFS** (o formato do Windows) ficam marcados como "sujos" quando:

- são desconectados sem clicar em **Ejetar**; ou
- foram usados num Windows com a **Inicialização rápida** ligada, que hiberna em vez de desligar.

O Linux se recusa a montar um disco "sujo" para não arriscar corromper os arquivos.

**Como usar:**

```bash
./scripts/montar-hd.sh              # encontra e tenta montar todos os HDs USB com NTFS
./scripts/montar-hd.sh /dev/sdc1    # ou só uma partição (veja o nome com: lsblk -f)
```

**O que acontece:**

1. O script tenta montar o HD normalmente, do mesmo jeito que o Dolphin.
2. Se não conseguir, mostra o erro e **pergunta** se pode rodar o `ntfsfix -d`, que
   limpa a marca de "sujo". Nada é alterado sem você responder `s`.
3. Tenta montar de novo e mostra onde o disco ficou acessível (ex.: `/media/seu-usuario/Dados`).
4. Avisa se o HD está numa porta **USB 2.0**. Prefira as portas USB 3.0 (azuis ou com
   o símbolo "SS"): são cerca de 3 vezes mais rápidas.

**Se mesmo assim não montar:** conecte o HD num Windows e rode `chkdsk /f` nele
(Explorador de Arquivos → botão direito no disco → Propriedades → Ferramentas → Verificar).

### Formatar um disco: `formatar-usb.sh`

> ⚠️ **Formatar apaga TODOS os arquivos do disco.** Copie o que for importante antes.

**Como usar:**

```bash
./scripts/formatar-usb.sh
```

O script faz quatro perguntas, nesta ordem:

1. **Qual disco?** Ele lista os discos USB conectados com tamanho, fabricante e formato
   atual. Digite o número correspondente.
2. **Qual formato?** Escolha pela tabela abaixo (o padrão é exFAT).
3. **Qual nome?** O nome que vai aparecer no Dolphin (padrão: `Dados`).
4. **Confirmação:** ele mostra o que será apagado e pede que você **digite o nome do disco**
   (ex.: `sdc`). Se digitar diferente, nada é alterado.

Depois disso, o disco é formatado com uma única partição ocupando todo o espaço e já
fica montado, pronto para usar. Se faltar o programa de formatação, o script instala sozinho.

**Qual formato escolher:**

| Formato            | Funciona em                          | Indicado para                                                                            |
| ------------------ | ------------------------------------ | ---------------------------------------------------------------------------------------- |
| **exFAT** (padrão) | Linux, Windows, Mac, TVs, videogames | HD ou pendrive que passa entre computadores. Não tem o problema de "disco sujo"          |
| **ext4**           | Só Linux                             | Disco usado só no Linux: backups, projetos. Mais resistente a falhas e guarda permissões |
| **NTFS**           | Windows (Linux lê e grava)           | Só se o disco for usado principalmente no Windows                                        |

> exFAT não guarda permissões de arquivo nem links simbólicos. Para backup de
> projetos de programação, prefira **ext4**.

### Para evitar problemas

- **Sempre clique em Ejetar** antes de puxar o cabo (no Dolphin, ou no ícone de
  dispositivos do painel). Isso garante que tudo foi gravado.
- **Se você também usa Windows**, desligue a Inicialização rápida:
  Painel de Controle → Opções de Energia → "Escolher a função dos botões de energia" →
  "Alterar configurações não disponíveis no momento" → desmarque **"Ligar inicialização rápida"**.
- **Use portas USB 3.0** e o cabo original do HD. Cabos ruins causam desconexões e erros de leitura.
- **Para saber o nome de um disco** (`sdb`, `sdc`...), rode `lsblk -f` com ele conectado.
  O tamanho e o nome (LABEL) ajudam a identificar qual é qual.
