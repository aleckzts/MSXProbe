# Referência de hardware

Notas de referência para as próximas versões. Itens marcados **(a confirmar)**
precisam ser validados em documentação ou máquina real antes de virar código.

## Bytes de identificação da BIOS

| End. | Conteúdo |
|---|---|
| `0004h` | ponteiro da fonte (CGTABL) |
| `0006h` / `0007h` | porta base de leitura / escrita do VDP |
| `002Bh` | b0–3 charset (0=JP, 1=Int, 2=Coreia), b4–6 formato de data, b7 0=60Hz / 1=50Hz |
| `002Ch` | b0–3 teclado (0=JP 1=Int 2=FR 3=UK 4=DE 5=URSS 6=ES), b4–7 PRINT USING |
| `002Dh` | 0=MSX1 1=MSX2 2=MSX2+ 3=turbo R |

## Slots

Referência principal: [The MSX Red Book](https://github.com/gseidler/The-MSX-Red-Book), cap. 1 ("PPI Port A",
"Expanders") e cap. 4 (`RDSLT`, `027EH`, `02A3H`, `CHKRAM`).

- Porta `A8h` (PPI A): 2 bits por página com o slot primário
  (b0–1 page 0 … b6–7 page 3).
- Slot expandido: registrador de subslot em `FFFFh` daquele slot primário
  (lido **complementado**). Só é acessível com a page 3 apontando para o slot.
- `EXPTBL` (`FCC1h`): `[0]` = slot da BIOS; `[1..3]` bit 7 = slot expandido.
- `SLTTBL` (`FCC5h`): cópia dos registradores de subslot mantida pela BIOS.
- ID de slot (formato BIOS): `E000SSPP` — E = expandido, SS = subslot, PP = primário.
- `RDSLT`/`WRSLT` (`000Ch`/`0014h`) usam rotinas em RAM (`RDPRIM`, `F380h`)
  e funcionam para pages 0–2. Page 3 de outro slot exige rotina própria sem
  usar pilha.
- `ENASLT` (`0024h`) troca pages 1 e 2 com segurança.
- Custo do `RDSLT` (Red Book): por byte, calcula máscaras (`027EH`: OR/AND
  para A8h, slot replicado, máscara da página), troca o subslot (`02A3H`:
  página 3 → slot primário, lê `FFFFh` invertido, mistura, escreve, volta),
  troca o primário via `RDPRIM` (`F380h`) e desfaz o subslot. Para ler
  muitos bytes da mesma página vale trocar uma vez e ler direto (ver
  `snap` em `t_slots.asm`).
- No boot (`CHKRAM`) a BIOS procura RAM nas pages 2 e 3 dos 16 slots e
  detecta expansores escrevendo em `FFFFh` (o registrador de subslot lê de
  volta **invertido**); o resultado vai para `EXPTBL`/`SLTTBL`.

- **Conectores de cartucho:** por convenção, slot primário 1 = cartucho A
  (superior/frontal) e slot 2 = cartucho B. Não há registro na BIOS que diga
  quais slots são externos; algumas máquinas fogem da regra (anotar nos
  relatórios de teste).

### Identificação de ROMs (heurísticas)

| O quê | Como |
|---|---|
| BIOS / BASIC | slot `EXPTBL[0]`, pages 0 / 1 |
| SUB-ROM (MSX2+) | `"CD"` em `0000h`; slot em `EXBRSA` (`FAF8h`) |
| Cartucho | `"AB"` em `4000h` ou `8000h` |
| Disk ROM | slots listados em `DRVTBL` (`FB21h`); jump table `JP` em `4010h/4013h/4016h` (a confirmar em máquinas reais) |
| Espelho | página 0/2 com os mesmos 4 primeiros bytes da página 1 do slot |
| MSX-MUSIC | `"APRLOPLL"` (interno) ou `"PAC2OPLL"` (FM-PAC) em `4018h` |

## Memory Mapper

- Portas `FCh`–`FFh` = segmento (16KB) nas pages 0–3. BIOS inicializa
  `FC=3, FD=2, FE=1, FF=0`.
- Leitura das portas é **não confiável** (varia por fabricante) — não usar.
- Todos os mappers do sistema recebem a mesma escrita (portas compartilhadas).
- turbo R em modo R800 DRAM: os últimos segmentos guardam a cópia da BIOS
  e ficam protegidos contra escrita (a confirmar quantos).

## MegaRAM (padrão brasileiro, ACVS)

- Bancos de 8KB em `4000h–BFFFh` (4 janelas: 4000h, 6000h, 8000h, A000h).
- `IN A,(8Eh)` → modo ROM: escrever na janela **seleciona o banco**.
- `OUT (8Eh),A` → modo RAM: escrever na janela **grava dados**.
- Porta `8Eh` é global: afeta todas as MegaRAMs ao mesmo tempo.
- Tamanhos comuns: 256KB, 512KB, 768KB, 2MB (até 256 bancos).

## VDP

| Chip | Máquinas | Detecção |
|---|---|---|
| TMS9918A / 9928A / 9129 | MSX1 (NTSC / PAL / PAL-M) | `002Dh = 0`; 50/60Hz pelo bit 7 de `002Bh` |
| V9938 | MSX2 | status S#1 bits 1–5 = 0 |
| V9958 | MSX2+ / turbo R | status S#1 bits 1–5 = 2 |

- Para ler S#1: `R#15 = 1`, ler porta `99h`, voltar `R#15 = 0` (com DI).
  **Não fazer em MSX1**: o TMS ignora os bits altos do número do registrador e
  escreveria em R#7 (cor da borda).
- VRAM no MSX2: `MODE` (`FAFCh`) b1–2 = 0:16K 1:64K 2:128K. Endereços acima de
  16KB via R#14 (A14–A16).
- Timing do TMS9918 com tela ativa: ≥ 29 T-states entre acessos (≈ 8µs).

## Chips de som — métodos de detecção

| Chip | Portas / endereço | Detecção proposta |
|---|---|---|
| PSG AY-3-8910 / YM2149 | `A0h` reg, `A1h` escrita, `A2h` leitura | sempre presente; escrever/ler um registrador de período (R0) confirma funcionamento |
| SCC (Konami) | slot de cartucho, `9000h` = `3Fh` habilita, RAM de onda `9800h–987Fh` | escrever/ler a RAM de onda no slot |
| SCC+ / SCC-I | `BFFEh` = `20h`, registradores em `B800h` | idem, modo SCC+ (a confirmar valores) |
| MSX-MUSIC (YM2413) | portas `7Ch/7Dh`; ROM `"OPLL"` em `401Ch` | assinatura da ROM; FM-PAC precisa bit 0 de `7FF6h` = 1 |
| MSX-AUDIO (Y8950) | portas `C0h/C1h` | leitura do status em `C0h` após reset dos timers (a confirmar) |
| Moonsound (OPL4 / YMF278B) | FM `C4h–C7h`, wave `7Eh/7Fh` | registrador de wave 2 (ID do dispositivo) (a confirmar bits) |
| PCM turbo R | `A4h/A5h` | só se `002Dh = 3` |
| SN76489 (Franky / PlaySoniq) | `48h`? | a confirmar — chip só de escrita, detecção difícil |
| OPL3 / outros | — | investigar |
