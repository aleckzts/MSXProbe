# Roadmap

## v0.1 — Abertura ✅

- [x] Ambiente: sjasmplus, openMSX (C-BIOS), Makefile, teste automático (`make shot`)
- [x] ROM plain 16KB, cabeçalho de cartucho, assinatura
- [x] Logo subindo pixel a pixel em SCREEN 2, desacelerando, com degradê
- [x] Flash + jingle no PSG ao parar
- [x] Linha do sistema: versão do MSX, 50/60Hz, teclado
- [ ] **Validar em máquina real** (SofaRun) — MSX1, MSX2, MSX2+

## v0.2 — Tela principal e primeiros testes ✅

- [x] Nome novo: **MSX PROBE**; interface em inglês (`src/lang/en.asm`)
- [x] Tela principal: dados do boot + menu; resultados ficam na tela;
      ENTER roda e pula para o próximo teste não feito
- [x] Boot: versão, VDP (TMS99x8 / V9938 / V9958), VRAM, CPU (turbo R), Hz,
      teclado, charset, slots da BIOS / da ROM / da RAM em page 3
- [x] VRAM: teste completo 16/64/128KB
- [x] SOUND: registradores do PSG + nota em cada canal + MSX-MUSIC/FM-PAC
- [x] SCREEN: submenu com os modos do modelo (0/40, 0/80, 1–8, 10/11, 12),
      cada um com resolução e cores máximas
- [x] SLOTS: resumo dos slots primários (primeiro do menu, roda sozinho no boot;
      saiu do cabeçalho)
- [x] Testes não implementados já mostram "Not available yet" e ignoram ENTER
- [x] Leitura de tecla espera soltar todas as teclas (evita tecla "fantasma")
- [ ] **Validar em máquina real**

## v0.3 — Slots e ROMs

- [x] KEYBOARD e JOYSTICK fora do menu (por enquanto)
- [x] Mapa de slots/subslots × pages 0–3 (ENTER em SLOTS)
- [x] Identificar BIOS, BASIC, SUB-ROM, Disk, MSX-MUSIC, cartuchos, RAM,
      espelhos, vazio; CART A / CART B; slots ativos por página
- [x] Resumo de SLOTS a partir do mapa (roda no boot)
- [ ] Nº de drives por interface de disco (`DRVTBL`), nome do cartucho/ROM
- [ ] Identificar mais ROMs: Kanji, MSX-DOS2/Nextor, firmware Panasonic/Sony,
      FM-PAC × MSX-MUSIC interno, SCC
- [ ] **Validar em máquina real**

## v0.4 — Memória

- [ ] Detecção de tamanho do Memory Mapper (não destrutivo), em todos os slots
- [ ] Teste de todos os segmentos do mapper (não destrutivo)
- [ ] RAM sem mapper (MSX1 64KB: Expert, Hotbit) — pages 0–3
- [ ] MegaRAM: detecção, tamanho e teste dos bancos
- [ ] Total de RAM detectada

## v0.5 — Som

- [x] PSG (teste de registradores + tom em cada canal) — v0.2
- [ ] SCC / SCC+
- [x] MSX-MUSIC (interno e FM-PAC, pela assinatura da ROM) — v0.2
- [ ] MSX-AUDIO
- [ ] Moonsound (OPL4)
- [ ] PCM do turbo R
- [ ] Teste audível opcional de cada chip

## v0.6 — Entrada, relógio e rede

- [ ] KEYBOARD (volta ao menu): matriz do teclado ao vivo (todas as teclas, inclusive SHIFT/CTRL/GRAPH/CODE)
- [ ] JOYSTICK (volta ao menu): portas 1 e 2 (direções + 2 botões), mouse/trackball (MSX2)
- [ ] RTC: relógio RP5C01 (MSX2 em diante): hora, bateria/SRAM
- [ ] NETWORK: detectar interfaces (GR8NET, ObsoNET, ESP8266 via UNAPI…) — a pesquisar
- [ ] SCREEN: sprites (modo 1 e 2), scroll horizontal (V9958), 192/212 linhas, entrelaçado

## Ideias

- Idiomas: português, espanhol, japonês (katakana?)
- Impressora, cassete (porta de saída/relay), luz CAPS/KANA
- "Beep codes" se a VRAM falhar (sem vídeo confiável)
- Relatório final numa tela única, fácil de fotografar
- Versão 32KB se faltar espaço
