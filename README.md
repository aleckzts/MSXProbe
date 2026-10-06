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
- **SLOTS** com ENTER abre o **mapa de slots**: cada slot/subslot × páginas
  0000/4000/8000/C000 com o que há em cada uma (BIOS, BASIC, SUB-ROM, DISK,
  MUSIC, ROM, RAM, PROBE, DATA, MIRR = espelho), CART A / CART B (slots 1 e 2,
  pela convenção MSX) e os slots selecionados agora em cada página.
- **SCREEN** abre um submenu com os modos de tela que **aquele modelo** tem
  (MSX1: 0–3; MSX2: + 0/80 colunas e 4–8; MSX2+: + 10/11 e 12; modos 7, 8,
  10–12 só com 128KB de VRAM). Cada modo mostra a resolução e as cores
  máximas: texto com a fonte inteira e régua de colunas; bitmap com barras
  de cor, faixa de pixels alternados, grade de 256 cores (SCREEN 8) ou o plano
  de cores YJK (SCREEN 10–12).

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
