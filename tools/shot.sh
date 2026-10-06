#!/bin/sh
# Uso: tools/shot.sh <rom absoluta> <diretorio de saida> [script.tcl]
# Roda a ROM em MSX1, MSX2 e MSX2+ (C-BIOS BR) e gera PNG/WAV em <saida>/shots
set -e
ROM="$1"; OUT="$2/shots"; SCRIPT="${3:-shot.tcl}"
mkdir -p "$OUT"
DIR=$(cd "$(dirname "$0")" && pwd)
for M in C-BIOS_MSX1_BR C-BIOS_MSX2_BR C-BIOS_MSX2+_BR; do
    echo "== $M"
    SHOT_OUT="$OUT/$M" timeout 180 flatpak run --filesystem="$OUT" --filesystem="$DIR" \
        --filesystem="$(dirname "$ROM")" org.openmsx.openMSX \
        -machine "$M" -carta "$ROM" -script "$DIR/$SCRIPT" \
        || echo "   (openMSX nao terminou sozinho em $M - timeout)"
done
ls -1 "$OUT" | grep png | wc -l
