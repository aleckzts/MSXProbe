# MSX PROBE — MSX Hardware Diagnostics

ROM de diagnóstico para MSX escrita em assembly Z80, no estilo dos anos 80.
O objetivo é rodar em **qualquer MSX** (MSX1, MSX2, MSX2+ e turbo R),
nacional (Gradiente Expert, Sharp Hotbit…), japonês (Sony, Panasonic…) ou
europeu (Philips…), e informar:

- versão do MSX, VDP, VRAM, CPU, frequência e tipo de teclado;
- teste de RAM, VRAM e memória expandida (Memory Mapper e MegaRAM);
- mapa de slots/subslots e quais ROMs estão instaladas;
- modos de tela disponíveis, chips de som, teclado, joystick, relógio, rede…

Interface em **inglês** (textos isolados em `src/lang/en.asm`, prontos para
tradução).

> **Estado atual — v0.2:** abertura estilo Konami → tela principal com os
> dados do boot e o menu de testes. Prontos: **SLOTS** (resumo no boot + mapa
> completo de slots/subslots), **VRAM**, **SOUND** (PSG + MSX-MUSIC) e
> **SCREEN** (submenu com todos os modos de tela do modelo). RAM, RTC e
> NETWORK aparecem como "Not available yet".
> Veja o [roadmap](docs/ROADMAP.md).

## Baixar e usar (sem compilar)

A última versão compilada está em **[`rom/msxprobe.rom`](rom/msxprobe.rom)**
(cartucho plain de 16KB, sem mapper).

1. Copie para o pendrive/cartão como `MSXPROBE.ROM`.
2. Carregue com SofaRun, ODO, ROMLOAD, MegaFlashROM, Carnivore… Se o
   carregador perguntar o tipo, escolha **plain/normal 16KB**.
3. Também roda em emuladores (openMSX, blueMSX, fMSX, WebMSX) como cartucho.

Procedimento de teste e modelo de relatório:
[docs/TESTE_MAQUINA_REAL.md](docs/TESTE_MAQUINA_REAL.md).

## Como usar

Depois da abertura, qualquer tecla leva à tela principal:

```
 MSX PROBE 0.2      Hardware Diagnostics
----------------------------------------
 MSX2+  VDP V9958  VRAM 128KB  60Hz
 CPU Z80  Kbd JP  Chars JP
----------------------------------------
   TEST     RESULT
   SLOTS    0:BIOS 1:PROBE 2:RAM 3:EXP    <- já roda no boot
   RAM      Not available yet             <- ENTER não faz nada
 > VRAM     -                             <- cursor no próximo teste
   SOUND    -
   SCREEN   -
   ...
----------------------------------------
 Up/Down:select ENTER:run ESC:intro
```

- **ENTER** (ou espaço) roda o teste sob o cursor. O resultado fica na linha
  do teste e o cursor pula para o **próximo teste ainda não feito** — basta ir
  apertando ENTER.
- **↑/↓** escolhe outro teste (pode repetir um já feito).
- **ESC** volta para a abertura (os resultados são mantidos).
- **SLOTS** com ENTER abre o **mapa de slots** no formato do
  [MSX Red Book](https://github.com/gseidler/The-MSX-Red-Book): a grade slot primário × subslot × página (fig. 44) e
  os registradores de slot bit a bit (fig. 1 e 2) — veja a
  [legenda do mapa de slots](#legenda-do-mapa-de-slots-slots).
- **SCREEN** abre um submenu com os modos de tela que **aquele modelo** tem
  (MSX1: 0–3; MSX2: + 0/80 colunas e 4–8; MSX2+: + 10/11 e 12; modos 7, 8,
  10–12 só com 128KB de VRAM). Cada modo mostra a resolução e as cores
  máximas: texto com a fonte inteira e régua de colunas; bitmap com barras
  de cor, faixa de pixels alternados, grade de 256 cores (SCREEN 8) ou o plano
  de cores YJK (SCREEN 10–12).

## Legenda do mapa de slots (SLOTS)

A tela segue a forma como o [MSX Red Book](https://github.com/gseidler/The-MSX-Red-Book) expõe os slots: a tabela
`SLTATR` (fig. 44 — uma linha por slot primário, um bloco por subslot, quatro
páginas em cada bloco) e os registradores de slot (fig. 1 — porta `A8H`;
fig. 2 — `FFFFH` de cada slot expandido), bit 7 à esquerda = página 3.

```
 SLOT MAP                         MSX2
----------------------------------------
      SS0      SS1      SS2      SS3
    0 4 8 C  0 4 8 C  0 4 8 C  0 4 8 C
PS0 BIBADA..
PS1 RARARARA
PS2 ........ ........ MIPRMIDA ........
PS3 SU...... ........ RARARARA ........
----------------------------------------
 BI BIOS   BA BASIC  SU SUB     DK DISK
 MU MUSIC  RO ROM    RA RAM     PR PROBE
 DA DATA   MI MIRROR .. EMPTY
 PS1:CART A  PS2:CART B (convention)
----------------------------------------
 REGISTER 76543210 PAGE 3   2   1   0
 PORT A8H 01011000      1   1   2   0
 FFFFH(2) 00001000      0   0   2   0
 FFFFH(3) 00000000      0   0   0   0
 SLOT NOW               1   1   2-2 0

 A8H=PSLOT#  FFFFH(n)=SSLOT# of PSn
```

(MSX2 com um expansor de slots no slot 2 e o MSX PROBE no subslot 2-2.)

**Grade (Red Book fig. 44)**

| Item | Significado |
|---|---|
| `PS0`–`PS3` | Slot primário (*Primary Slot*), uma linha cada. |
| `SS0`–`SS3` | Subslot (*Secondary Slot*). Slot primário **não expandido** só tem o bloco `SS0`; os outros ficam em branco. |
| `0 4 8 C` | As 4 páginas de 16KB de cada bloco: 0000h, 4000h, 8000h, C000h. |
| 2 letras | O que há naquela página — siglas abaixo. |

**Registradores (Red Book fig. 1 e 2)**

| Linha | Significado |
|---|---|
| `PORT A8H` | *Primary Slot Register* (PPI porta A): 2 bits por página com o slot primário (`PSLOT#`). Valor em binário e o número por página. |
| `FFFFH(n)` | *Secondary Slot Register* do slot primário `n` expandido (lido do hardware, já desinvertido): 2 bits por página com o subslot (`SSLOT#`). |
| `SLOT NOW` | Slot selecionado **agora** em cada página, no formato `primário-subslot`. |

**Siglas das células**

| Código | Nome | Significado | Como é detectado |
|---|---|---|---|
| `BI` | BIOS | BIOS principal do MSX (rotinas de sistema). | Slot indicado pela própria BIOS (`EXPTBL`), página 0000h. |
| `BA` | BASIC | Interpretador MSX-BASIC (segunda metade da ROM principal). | Mesmo slot da BIOS, página 4000h. |
| `SU` | SUB | SUB-ROM do MSX2/2+/turbo R (BASIC estendido, rotinas gráficas, paleta…). | Cabeçalho `"CD"` em 0000h. |
| `DK` | DISK | ROM de interface de disco (Disk BASIC / MSX-DOS, Nextor). | Slot listado em `DRVTBL` ou tabela de saltos do driver em 4010h. |
| `MU` | MUSIC | ROM do MSX-MUSIC (FM, YM2413): interno ou cartucho FM-PAC. | Texto `"OPLL"` em 401Ch. |
| `RO` | ROM | ROM com cabeçalho de cartucho (jogo, programa, ferramenta…). | Cabeçalho `"AB"` no início da página. |
| `RA` | RAM | Memória RAM (inclui Memory Mapper; o teste de RAM detalha). | Sonda não destrutiva: lê, escreve o complemento, confere e restaura. |
| `PR` | PROBE | O próprio MSX PROBE (este programa). | Slot de onde o programa está rodando. |
| `MI` | MIRR | **Espelho**: a mesma ROM da página 4000h aparecendo de novo em outra página (comum em cartuchos de 16KB, por decodificação parcial de endereços). | Primeiros 4 bytes iguais aos da página 4000h do mesmo slot. |
| `DA` | DATA | Há algo ali (não lê tudo `FFh`), mas não é RAM nem tem cabeçalho conhecido: ROM sem cabeçalho, bancos de MegaROM, Kanji, firmware… | Amostras de bytes diferentes de `FFh`. |
| `..` | vazio | Vazio: nada respondendo naquela página. | Todas as amostras lidas como `FFh`. |

**Notas e resumo do menu**

| Sigla | Significado |
|---|---|
| `CART A` / `CART B` | Conectores de cartucho. Por **convenção** do MSX, slot primário 1 = cartucho A e slot 2 = cartucho B; não há como ler isso do hardware, e algumas máquinas fogem da regra. |
| `EXP` | (linha SLOTS do menu) Slot primário **expandido**: tem subslots (`x-0` a `x-3`), detalhados no mapa. |
| `-` | (linha SLOTS do menu) Nada encontrado naquele slot primário. |

Na linha SLOTS do menu cada slot primário não expandido mostra o item mais
relevante encontrado nele, nesta ordem: PROBE, BIOS, DISK, MUSIC, ROM, RAM,
SUB, DATA.

## Compilar

### Linux (ambiente usado no projeto)

Pré-requisitos: `git`, `make`, `g++`, `python3` e `flatpak` (para o emulador).

```sh
# Debian/Ubuntu (Fedora/Arch: pacotes equivalentes)
sudo apt install git make g++ python3 flatpak

git clone <url-do-repositório> msxprobe
cd msxprobe
tools/setup.sh     # compila o sjasmplus em tools/bin e instala o openMSX (flatpak --user)
make               # gera build/msxprobe.rom
make run           # abre no openMSX como MSX2+ (C-BIOS BR) — make run1 / run2: MSX1 / MSX2
make release       # copia a ROM para rom/ (a versão publicada)
```

Testes automáticos no emulador (abrem janelas do openMSX e apertam as teclas
sozinhos; screenshots e áudio em `build/shots/`):

```sh
make shot          # abertura + menu, em MSX1/MSX2/MSX2+
make shot-screen   # todos os modos do teste SCREEN
make shot-slots    # mapa de slots
pip install pillow # opcional, só para montar mosaicos das imagens
```

> Às vezes o openMSX (flatpak) trava no meio de uma rodada automática; o
> `shot.sh` tem limite de 180s por máquina — basta rodar de novo.

O C-BIOS é uma BIOS livre (sem BASIC) que vem com o openMSX. Para emular
máquinas reais (Expert, Hotbit, HB-F1XD, FS-A1WSX…) coloque as ROMs de
sistema em `~/.var/app/org.openmsx.openMSX/.openMSX/share/systemroms/` e use
`flatpak run org.openmsx.openMSX -machine <nome> -carta build/msxprobe.rom`.

### Windows (não testado)

> ⚠️ O autor não tem ambiente Windows para testar estes passos. Correções são
> bem-vindas.

**Opção 1 — WSL2 (recomendada):** instale o Ubuntu pelo WSL
(`wsl --install`) e siga os passos de Linux acima dentro dele. O openMSX pode
ser o instalador nativo do Windows em vez do flatpak.

**Opção 2 — nativo:**

1. Baixe o **sjasmplus 1.21** para Windows em
   <https://github.com/z00m128/sjasmplus/releases> e coloque `sjasmplus.exe`
   em `tools\bin\`.
2. Instale o **Python 3** (<https://www.python.org>).
3. Instale o **openMSX** (<https://openmsx.org>) para testar.
4. No diretório do projeto, rode (cmd ou PowerShell):

   ```bat
   mkdir build
   python tools\mklogo.py assets\logo.txt build\logo.inc
   tools\bin\sjasmplus.exe --nologo -Isrc -Ibuild src\msxprobe.asm
   ```

   A ROM sai em `build\msxprobe.rom`. (Com GNU make — por exemplo via MSYS2 —
   o `make` também deve funcionar, trocando `SJASM` no `Makefile` para
   `tools/bin/sjasmplus.exe`.)

## Estrutura

```
rom/msxprobe.rom     ROM publicada (última versão)
assets/logo.txt      arte do logo em ASCII (editável)
src/msxprobe.asm     ponto de entrada, cabeçalho de cartucho, layout da ROM
src/intro.asm        abertura (logo subindo em SCREEN 2)
src/menu.asm         tela principal: info do boot + menu + resultados
src/text.asm         SCREEN 0, leitura de teclado e montador de strings (out_*)
src/gfx.asm          rotinas de VRAM, texto em SCREEN 2, paleta MSX2
src/sound.asm        mini driver de som para o PSG + jingle
src/sysinfo.asm      detecção no boot (versão, VDP, VRAM, CPU, Hz, teclado, slots)
src/slotutil.asm     utilitários de slot
src/tests/t_*.asm    um arquivo por teste
src/lang/en.asm      todos os textos da interface (inglês)
src/ramvars.asm      variáveis em RAM (C000h+)
src/inc/msx.inc      endereços da BIOS, variáveis de sistema, portas
tools/setup.sh       instala sjasmplus e openMSX (Linux, sem sudo)
tools/mklogo.py      gera build/logo.inc a partir de assets/logo.txt
tools/shot*.tcl/.sh  testes automáticos no emulador
docs/                documentação técnica e de testes
```

## Documentação

- [docs/ARQUITETURA.md](docs/ARQUITETURA.md) — layout da ROM, memória, técnicas usadas
- [docs/HARDWARE.md](docs/HARDWARE.md) — referência de slots, BIOS, mappers, MegaRAM, VDP e chips de som
- [docs/ROADMAP.md](docs/ROADMAP.md) — o que vem a seguir
- [docs/TESTE_MAQUINA_REAL.md](docs/TESTE_MAQUINA_REAL.md) — procedimento e relatório de testes

## Referências

- **The MSX Red Book** (Avalon Software, Kuma Computers, 1985) — referência
  quase completa do MSX1: PPI e registradores de slot (cap. 1), BIOS e as
  rotinas de troca de slot `RDSLT`/`WRSLT`/`ENASLT` (cap. 4), `SLTATR` e a
  área de trabalho (cap. 6). Versão em Markdown:
  <https://github.com/gseidler/The-MSX-Red-Book>. O mapa de slots segue as figuras 1, 2 e 44 do livro.
