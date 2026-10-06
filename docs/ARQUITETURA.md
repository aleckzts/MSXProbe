# Arquitetura

## Formato da ROM

- Cartucho **plain 16KB** em `4000h–7FFFh`, cabeçalho `"AB"` + endereço de INIT.
- Sem mapper de ROM: roda de cartucho real (EPROM 27128), de MegaFlashROM, ou
  carregado em RAM por SofaRun e similares.
- Bytes não usados ficam em `FFh` (como EPROM apagada).
- Logo após o cabeçalho há a assinatura `"MSXPROBE 0.2"` para identificar a
  ROM em dumps.
- Se precisarmos de mais espaço: 32KB plain (`4000h–BFFFh`) ainda funciona em
  quase todo carregador. Só depois disso pensar em mapper ASCII8/16.

## Entrada e ambiente

- A BIOS chama `INIT` durante a varredura de cartuchos. A ROM **nunca retorna**:
  assume a máquina; o usuário sai com reset.
- A pilha usa `HIMEM` se ele for ≥ `C400h` (caso de ter sido iniciada pelo DOS
  com páginas de sistema abaixo de `F380h`), senão `F380h`.
- Variáveis em `C000h–C3FFh` (page 3). Nada de RAM em page 2 é assumido.
- Usamos as rotinas da BIOS (page 0) sempre que possível — é o que garante
  compatibilidade entre fabricantes. Acesso direto a portas só onde é padrão
  absoluto (VDP `98h/99h`, PSG `A0h–A2h`, PPI `A8h`).

## Mapa de memória

| Endereço | Uso |
|---|---|
| `0000h–3FFFh` | BIOS (page 0) |
| `4000h–7FFFh` | MSX PROBE (page 1) |
| `8000h–BFFFh` | não usado (futuro: janela para testar RAM/mapper/MegaRAM) |
| `C000h–C3FFh` | variáveis (`src/ramvars.asm`) |
| pilha | abaixo de `HIMEM` |

## Abertura (src/intro.asm)

- **SCREEN 2** via `INIGRP`: a tabela de nomes fica sequencial (0..255 em cada
  terço), então o padrão da célula (linha *r*, coluna *c*) está em
  `r*256 + c*8` e a cor em `2000h + r*256 + c*8`. Ou seja, a tela vira um bitmap
  e dá para mover o logo **pixel a pixel** só reescrevendo VRAM.
- O logo (128×24 px) é guardado **por coluna de caractere** com 8 bytes zerados
  antes e depois (`tools/mklogo.py`). Para cada uma das 4 linhas de caractere
  cobertas, lemos 8 bytes a partir de `off = r*8 − y + 8` — sem testes de limite,
  e o padding apaga o rastro do logo ao subir.
- O degradê de cor também é por linha de pixel, então ele **acompanha** o logo.
- ~1KB por quadro (512 bytes de padrão + 512 de cor) com `OUTI / JP NZ`
  (29 T-states por byte com o wait-state M1 do MSX) — o mínimo seguro para o
  TMS9918 com a tela ligada. Cabe num quadro de 60Hz (~59.700 T).
- Sincronismo com `HALT` (interrupção do VDP). Velocidade: 2 px/quadro longe,
  1 px perto, 1 px a cada 2 quadros no final (desaceleração).
- Toda escrita de endereço no VDP é feita com interrupções desligadas: o
  tratador da BIOS lê o status do VDP, o que zera o latch da porta `99h`.

## Tela principal e testes (src/menu.asm)

- SCREEN 0, 40 colunas, impresso via BIOS (`POSIT`/`CHPUT`) — funciona em
  qualquer charset (japonês, internacional, brasileiro).
- Tabela `tests`: `dw nome, rotina` por teste. Adicionar um teste = uma linha na
  tabela + um `src/tests/t_xxx.asm` + o nome em `src/lang/en.asm`.
- **Contrato de um teste:** é chamado com o montador de strings (`out_str`,
  `out_dec`, `out_hex`, `out_slot`…) já apontando para o buffer de resultado
  (máx. 27 caracteres) e devolve em A o status (`ST_OK`, `ST_FAIL`, `ST_INFO`,
  `ST_NA`). Pode destruir a tela à vontade: o menu sempre redesenha tudo depois.
- Depois de cada teste o cursor vai para o próximo com status `ST_NONE`.
- Teclas: `get_key` espera **soltar todas as teclas** (matriz via `SNSMAT`,
  linhas 0–8) e limpa o buffer antes de aceitar uma nova. Sem isso, uma tecla
  ainda apertada ao trocar de modo de tela era lida de novo (visto no C-BIOS
  MSX2+) e a tela fechava sozinha. Teclas digitadas durante um teste são
  descartadas.
- Teste sem rotina (`dw nome, 0` na tabela) já nasce `ST_NA` com
  "Not available yet" e o ENTER é ignorado.

## Teste SCREEN (src/tests/t_screen.asm)

- Tabela `scr_modes`: versão mínima do MSX, flag "precisa de 128KB de VRAM",
  rótulo e rotina. O submenu lista só os modos disponíveis.
- Texto e SCREEN 1–3: rotinas da BIOS principal (`INITXT`, `INIT32`,
  `INIGRP`, `INIMLT`); SCREEN 4–8: `CHGMOD`. SCREEN 10/11 e 12 = `CHGMOD 8`
  + R#25 do V9958 (`08h` YJK, `18h` YJK+YAE), sem depender do BIOS do MSX2+.
  Ao voltar para o texto, R#25 = 0.
- Bitmap: tela desligada, uma linha por vez — um gerador preenche `linebuf`
  (256 bytes alinhados) e `OTIR` manda para a VRAM. O endereço de cada linha
  é calculado com R#14 (A14–A16), então funciona acima de 16KB.
- YJK: a cada 4 pixels, J e K (6 bits com sinal) ficam nos 3 bits baixos dos 4
  bytes (K baixo, K alto, J baixo, J alto). K varia na horizontal (calculado
  uma vez), J na vertical (só 2 bytes por grupo mudam por linha).
- **Paleta MSX2:** a BIOS guarda uma cópia da paleta na VRAM; depois do teste de
  VRAM ela vira lixo. `set_palette` grava a paleta padrão direto no VDP
  (R#16 + porta `9Ah`) sempre que a tela é reinicializada — sem depender do
  SUB-ROM (o `INIPLT` do C-BIOS não resolve).

## Idiomas

Todos os textos estão em `src/lang/en.asm`. Para outro idioma: copiar o arquivo
com os mesmos rótulos e traduzir (somente ASCII — a parte alta da fonte muda
entre máquinas japonesas, brasileiras e europeias).

## Som (src/sound.asm)

- Mini driver por quadro: lista de eventos `(quadro, canal, período, volume,
  taxa de decaimento)`. Volume cai 1 a cada *taxa* quadros (envelope por
  software — mais previsível que o envelope de hardware do AY).
- Registrador 7 do PSG é sempre escrito com bit 7 = 1 e bit 6 = 0
  (porta B saída, porta A entrada) — obrigatório no MSX.

## Estratégia planejada para os testes de memória

Registrada aqui para não perder o raciocínio (ainda não implementado):

1. **Testes não destrutivos** byte a byte (salva, escreve `00/FF/55/AA`,
   confere, restaura) com interrupções desligadas. Necessário porque, rodando
   via SofaRun, a própria ROM e a pilha estão em segmentos do mapper/MegaRAM.
2. **Janela em page 2** (`8000h–BFFFh`): todo segmento de mapper (`OUT (FEh)`)
   e todo banco de MegaRAM passa por ela.
3. **Problema do código se testando**: se o segmento na janela for o mesmo da
   page 1 (nossa ROM) ou da page 3 (pilha/variáveis), o laço de teste pode
   alterar os próprios bytes. Solução: duas cópias do laço — uma na ROM em
   offset `3xxxh` da página (ex. `7000h`) e outra copiada para RAM em offset
   `01xxh` (ex. `C100h`). A metade baixa (`0000–1FFFh`) do segmento é testada
   pelo laço da ROM, a metade alta pelo laço da RAM. Nenhum laço altera a si
   mesmo, sem precisar saber qual segmento é qual.
4. **Tamanho do mapper sem destruir**: para s = 0..255 salva o byte 0 do
   segmento s e escreve s; lê o segmento 0 → valor = 256 − N; restaura em
   ordem **decrescente** (o último a restaurar cada segmento físico é o alias
   de menor número, que guardou o valor original).
5. **MegaRAM**: `IN (8Eh)` = modo seleção de banco (ROM), `OUT (8Eh)` = modo
   escrita (RAM). Banco de 8KB escolhido escrevendo em `8000h`. Mesmo método
   de tamanho do mapper, com bancos de 8KB.
6. **Page 3** (`C000h–FFFFh`) de slot expandido: `FFFFh` é o registrador de
   subslot — nunca testar esse byte diretamente.
7. **VRAM** (implementado em `t_vram.asm`): destrutivo, com tela desligada e a
   cor da borda indicando o progresso; MSX2 em blocos de 16KB via R#14; dois
   passes (semente 00h/FFh) com dado = end. baixo XOR alto XOR semente XOR
   bloco*9, o que pega bits presos e blocos espelhados.
