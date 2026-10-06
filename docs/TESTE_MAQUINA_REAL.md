# Teste em máquina real

## Preparação

1. Use `rom/msxprobe.rom` (versão publicada) ou gere com `make` → `build/msxprobe.rom` (exatamente 16384 bytes).
2. Copie para o pendrive/cartão. Use nome 8.3 em maiúsculas: `MSXPROBE.ROM`.
3. No MSX, carregue com o **SofaRun** (ou ODO, ROMLOAD, MGLOCM, OPFXSD,
   Carnivore/MegaFlashROM…). Se o carregador perguntar o tipo de mapper,
   escolha **"plain/normal 16KB"** (sem mapper).

## O que deve aparecer (v0.2)

1. **Abertura:** o logo **MSX PROBE** (degradê branco → amarelo → vermelho)
   sobe do rodapé, desacelera e para no meio; flash branco + jingle;
   `MSX HARDWARE DIAGNOSTICS`, `VERSION 0.2 - 2026`, `PRESS ANY KEY` piscando.
2. **Tela principal** (texto branco em fundo azul, 40 colunas): duas linhas com
   o que foi detectado no boot e o menu de testes.
3. **SLOTS** já aparece preenchido (roda no boot, é instantâneo), ex.
   `0:BIOS 1:PROBE 2:- 3:EXP`; o cursor começa em RAM.
4. Testes ainda não implementados (RAM, KEYBOARD, JOYSTICK, RTC, NETWORK) já
   aparecem como `Not available yet` e ENTER não faz nada neles.
5. Aperte **ENTER** seguidas vezes:
   - **VRAM** → a tela apaga e a **borda muda de cor** a cada bloco de 16KB
     (até ~8s em 128KB); volta com `OK 16KB tested` / `OK 128KB tested` ou
     `FAIL bits xxh blk n`.
   - **SOUND** → três notas, uma em cada canal (A, B, C), e o resultado
     `PSG OK, no FM` ou `PSG OK, MSX-MUSIC 3-3` / `FM-PAC 1`.
   - **SCREEN** → submenu com os modos daquele modelo (MSX1: 4, MSX2: 10,
     MSX2+: 12). ENTER mostra o modo, qualquer tecla volta, o cursor vai para
     o próximo; ESC volta ao menu com `12 modes, 12 viewed`.
     - texto (SCREEN 0 com 40/80 colunas, SCREEN 1): régua de colunas na 1ª
       linha + todos os caracteres da fonte;
     - SCREEN 2/4/5/7: 16 barras de cor + faixa xadrez de 1 pixel;
     - SCREEN 3: 16 barras + xadrez de blocos 4x4;
     - SCREEN 6: 4 barras (512 de largura) + faixa de 1 pixel;
     - SCREEN 8: grade com as 256 cores;
     - SCREEN 10/11: plano de cores YJK + 16 cores da paleta embaixo;
     - SCREEN 12: plano de cores YJK + faixa cinza de 1 pixel.

## O que observar e anotar

- A abertura rodou completa? O logo sobe liso ou com "rasgos"?
- As linhas do topo batem com a máquina? (MSX1/2/2+/turbo R, VDP, VRAM, 50/60Hz,
  teclado, charset). *Máquinas brasileiras: anote o que aparece em
  `Kbd` e `Chars` — queremos mapear o que cada modelo informa.*
- VRAM: resultado e quanto tempo levou.
- SOUND: ouviu as três notas, em canais diferentes? O FM foi detectado (se houver)?
- SCREEN: a lista de modos bate com o modelo? Algum modo com imagem errada,
  tremendo ou faltando pedaço? Na 80 colunas, a régua chega a 80?
- Alguma tela fechou sozinha, sem você apertar tecla?
- SLOTS: confere com o que você sabe da máquina e dos cartuchos?
- Depois do teste de VRAM, as cores da tela principal voltaram normais (MSX2/2+)?

## Modelo de relatório

Copie e preencha (pode colar no chat):

```
Máquina ........: (ex. Gradiente Expert XP-800 / Sony HB-F1XD / Panasonic FS-A1WSX)
Modelo MSX .....: (MSX1 / MSX2 / MSX2+ / turbo R)
Expansões ......: (ex. Mapper 512KB slot 2, MegaRAM 256KB, FM-PAC slot 1, interface de disco)
Carregador .....: (ex. SofaRun 8.x, modo mapper / modo MegaRAM)
Versão ........: MSX PROBE 0.2
Resultado ......: OK / travou / problemas
Linhas do topo .: (as 2 linhas exatas)
Resultados .....: (SLOTS / VRAM / SOUND / SCREEN, texto exato)
Observações ....:
```

Fotos ou vídeo curto da tela ajudam muito.

## Dicas de diagnóstico

- **Tela não muda / volta pro BASIC**: o carregador não reconheceu como ROM
  16KB plain. Tente forçar o tipo.
- **Trava no logo**: anote em que posição; pode ser timing de VDP em alguma
  máquina específica — o código usa intervalos de 29 T-states, que é o mínimo
  seguro para TMS9918 com tela ativa.
- **Sem som**: verifique volume/saída de áudio; o PSG é obrigatório em todo
  MSX, então silêncio total indica problema no carregador ou no hardware.
