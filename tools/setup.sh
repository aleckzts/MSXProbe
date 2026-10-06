#!/bin/sh
# Instala as ferramentas do projeto (sem sudo):
#   - sjasmplus (assembler Z80) compilado em tools/bin
#   - openMSX (emulador) via flatpak de usuario
set -e
cd "$(dirname "$0")"
SJ_VER=v1.21.0

if [ ! -x bin/sjasmplus ]; then
    echo "== sjasmplus $SJ_VER"
    mkdir -p src bin
    [ -d src/sjasmplus ] || git clone --depth 1 --branch $SJ_VER https://github.com/z00m128/sjasmplus.git src/sjasmplus
    make -C src/sjasmplus -j"$(nproc)" USE_LUA=0
    cp src/sjasmplus/sjasmplus bin/
fi
bin/sjasmplus --version | head -1

if ! flatpak info --user org.openmsx.openMSX >/dev/null 2>&1; then
    echo "== openMSX (flatpak)"
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install --user -y --noninteractive flathub org.openmsx.openMSX
fi
flatpak info --user org.openmsx.openMSX | grep -i version

python3 --version
python3 -c "import PIL" 2>/dev/null || echo "(opcional) pip install pillow - so para montar mosaicos de screenshots"
echo "OK. Rode 'make' e depois 'make run'."
