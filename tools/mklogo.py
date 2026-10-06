#!/usr/bin/env python3
"""Converte assets/logo.txt em src/logo.inc para a abertura da ROM.

Formato de saida (SCREEN 2, ver src/intro.asm):
  - o logo ocupa LOGO_COLS colunas de caractere (8 px cada) x LOGO_H pixels;
  - os dados sao gravados por COLUNA de caractere: para cada coluna,
    PAD bytes zerados + LOGO_H bytes (1 byte = 8 pixels de uma linha,
    bit 7 = pixel da esquerda) + PAD bytes zerados.
  O padding permite que a rotina de desenho leia sempre 8 bytes seguidos
  sem testar limites, e apaga automaticamente o rastro do logo ao subir.
"""
import sys

SCALE = 2          # cada '#' vira um bloco 2x2
LOGO_COLS = 20     # 20 colunas de caractere = 160 px
LOGO_H = 24        # altura em pixels
PAD = 8            # linhas zeradas antes e depois de cada coluna


def main(src, dst):
    rows = []
    for line in open(src, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line or line.startswith("# ") or line == "#":
            continue
        rows.append(line)
    width = max(len(r) for r in rows)
    rows = [r.ljust(width, ".") for r in rows]

    if len(rows) * SCALE != LOGO_H:
        sys.exit(f"logo.txt: precisa de {LOGO_H // SCALE} linhas, tem {len(rows)}")
    px_w = width * SCALE
    if px_w > LOGO_COLS * 8:
        sys.exit(f"logo.txt: largura {px_w}px excede {LOGO_COLS * 8}px")

    # bitmap final, centralizado na largura disponivel
    left = (LOGO_COLS * 8 - px_w) // 2
    bitmap = []
    for r in rows:
        line = [0] * (LOGO_COLS * 8)
        for x, ch in enumerate(r):
            if ch == "#":
                for s in range(SCALE):
                    line[left + x * SCALE + s] = 1
        bitmap.extend([line] * SCALE)

    out = [
        "; GERADO AUTOMATICAMENTE por tools/mklogo.py a partir de assets/logo.txt",
        "; NAO EDITE - altere o .txt e rode make.",
        f"LOGO_COLS\tequ {LOGO_COLS}",
        f"LOGO_H\t\tequ {LOGO_H}",
        f"LOGO_PAD\tequ {PAD}",
        f"LOGO_STRIDE\tequ {LOGO_H + 2 * PAD}",
        "logo_data:",
    ]
    for c in range(LOGO_COLS):
        col = [0] * PAD
        for y in range(LOGO_H):
            b = 0
            for bit in range(8):
                b = (b << 1) | bitmap[y][c * 8 + bit]
            col.append(b)
        col += [0] * PAD
        out.append(f"\t; coluna {c}")
        for i in range(0, len(col), 10):
            out.append("\tdb " + ",".join(f"0x{v:02X}" for v in col[i:i + 10]))
    open(dst, "w").write("\n".join(out) + "\n")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
