# MSX PROBE - MSX Hardware Diagnostics
# Uso:
#   make            monta build/msxprobe.rom
#   make run        roda no openMSX (MSX2+ C-BIOS BR)
#   make run1/run2  roda como MSX1 / MSX2 (C-BIOS BR)
#   make shot       roda MSX1/2/2+ navegando no menu, salva PNG/WAV em build/shots
#   make shot-screen idem, passando por todos os modos do teste SCREEN
#   make release    copia a ROM para rom/ (versao publicada no git)
#   make tools      (re)instala sjasmplus e openMSX
#   make clean

SJASM   := tools/bin/sjasmplus
OPENMSX := flatpak run org.openmsx.openMSX
ROM     := build/msxprobe.rom
SRC     := $(wildcard src/*.asm src/*/*.asm src/inc/*.inc)

all: $(ROM)

build/logo.inc: assets/logo.txt tools/mklogo.py
	@mkdir -p build
	python3 tools/mklogo.py $< $@

$(ROM): $(SRC) build/logo.inc
	@mkdir -p build
	$(SJASM) --nologo --msg=war -Isrc -Ibuild --lst=build/msxprobe.lst --sym=build/msxprobe.sym src/msxprobe.asm
	@ls -l $(ROM)

run: $(ROM)
	$(OPENMSX) -machine C-BIOS_MSX2+_BR -carta $(abspath $(ROM))
run1: $(ROM)
	$(OPENMSX) -machine C-BIOS_MSX1_BR -carta $(abspath $(ROM))
run2: $(ROM)
	$(OPENMSX) -machine C-BIOS_MSX2_BR -carta $(abspath $(ROM))

# Screenshots automaticos (MSX1, MSX2, MSX2+) - ver tools/shot.tcl
shot: $(ROM)
	tools/shot.sh $(abspath $(ROM)) $(abspath build)

# Every mode of the SCREEN sub-menu, on MSX1/2/2+
shot-screen: $(ROM)
	tools/shot.sh $(abspath $(ROM)) $(abspath build) shot_screens.tcl

# Published ROM (committed to git for people who do not want to build)
release: $(ROM)
	@mkdir -p rom
	cp $(ROM) rom/msxprobe.rom
	@echo "rom/msxprobe.rom atualizada - lembre de commitar"

tools:
	tools/setup.sh

clean:
	rm -rf build

.PHONY: all run run1 run2 shot shot-screen release tools clean
