ifeq ($(OS),Windows_NT)
RM_RF:=-cmd /c rd /s /q
MKDIR_P:=-cmd /c mkdir
COPY:=copy
BEEBASM?=bin\beebasm.exe
EXO?=bin\exomizer.exe
PYTHON2?=C:\Dev\Python27\python.exe
PYTHON3?=python.exe
else
RM_RF:=rm -Rf
MKDIR_P:=mkdir -p
COPY:=cp
BEEBASM?=beebasm
EXO?=exomizer
PYTHON3?=python
endif

VGM_CONVERTER=./bin/vgmconverter.py
VGM_PACKER=./bin/vgmpacker.py
PNG2BBC=./bin/png2bbc.py
PNG2BBC_DEPS:=./bin/png2bbc.py ./bin/bbc.py
EXO_AND_ARGS=$(EXO) level -B -c -M256

##########################################################################
##########################################################################

.PHONY:disc
disc: code
	$(RM_RF) "disc"
	$(MKDIR_P) "./disc"
	$(BEEBASM) -i src/disc-layout.asm -do disc/funky-fresh.ssd -title "FUNKY FRESH" -boot FRESH -v

.PHONY:code
code: music assets
	$(MKDIR_P) "./build"
	$(BEEBASM) -i src/funky-fresh.asm -v > ./compile.txt

.PHONY:music
music: ./build/beeb-demo.bbc.vgc

.PHONY:assets
assets: ./build/logo-with-stripes-mode2.exo ./build/logo-mode2.exo \
		./build/doom-screen.exo ./build/scr-screen.exo \
		./build/twister1-mode2.exo ./build/twister2-mode2.exo \
		./build/funky-sequence.bin ./build/stripes-mode2.exo \
		./build/zoom-2by160-mode2.exo ./build/frak-sprite.bin \
		./build/zoom-screen.exo ./build/checks-bitmask-0-to-3.exo \
		./build/checks-bitmask-4-to-7.exo ./build/diagonals-16.exo \
		./build/path-zoom-256.exo ./build/cube-widths-128.exo \
		./build/scroller-font.bin

##########################################################################
##########################################################################

.PHONY:clean
clean:
	$(RM_RF) "build"
	$(RM_RF) "disc"

##########################################################################
##########################################################################

./build/beeb-demo.bbc.vgc: ./build/beeb-demo.bbc.vgm
./build/beeb-demo.bbc.vgm: ./data/music/beeb-demo.vgm
	$(MKDIR_P) "./build"
	$(PYTHON2) $(VGM_CONVERTER) data/music/beeb-demo.vgm -t bbc -o build/beeb-demo.bbc.vgm

##########################################################################
##########################################################################

./build/doom-screen.exo: ./build/doom-screen.bin
./build/doom-screen.bin: ./data/gfx/Doom.png $(PNG2BBC_DEPS)
	$(MKDIR_P) "./build"
	$(PYTHON2) $(PNG2BBC) -q -o $@ $< --160 2

./build/scr-screen.exo: ./build/scr-screen.bin
./build/scr-screen.bin: ./data/gfx/TitleScreen_BBC.png $(PNG2BBC_DEPS)
	$(MKDIR_P) "./build"
	$(PYTHON2) $(PNG2BBC) -q -o $@ $< --160 2

./build/frak-sprite.bin: ./data/gfx/frak-sprite.png ./bin/png2bbc_pal.py ./bin/bbc.py
	$(MKDIR_P) "./build"
	$(PYTHON3) bin/png2bbc_pal.py -o $@ -c ./build/frak-lines.asm $< 2

./build/scroller-font.bin: ./data/gfx/Charset_1Bitplan.png ./bin/png2bbc_font.py ./bin/bbc.py
	$(MKDIR_P) "./build"
	$(PYTHON2) bin/png2bbc_font.py -o $@ --glyph-dim 16 15 --max-glyphs 55 --column -q $< 2

##########################################################################
##########################################################################

./build/funky-sequence.bin: ./data/rocket/track_list.txt \
							./data/rocket/funky_zoom.track ./data/rocket/funky_display_fx.track \
							./data/rocket/funky_task_1.track ./data/rocket/funky_task_2.track \
							./data/rocket/funky_x_pos.track ./data/rocket/funky_y_pos.track \
							./data/rocket/funky_anim_time.track
	$(MKDIR_P) "./build"
	$(PYTHON3) bin/rocket2bbc.py funky data/rocket/track_list.txt data/rocket -o ./build/funky-sequence.bin

##########################################################################
##########################################################################

# TODO: Try to avoid having raw binaries without source assets!
# TODO: Need a copy command that copes with forward slash directory separator.
./build/logo-mode2.bin: ./data/raw/logo-mode2.bin
	$(MKDIR_P) "./build"
	$(COPY) .\data\raw\logo-mode2.bin build

./build/logo-with-stripes-mode2.bin: ./data/raw/logo-with-stripes-mode2.bin
	$(MKDIR_P) "./build"
	$(COPY) .\data\raw\logo-with-stripes-mode2.bin build

./build/twister1-mode2.bin: ./data/raw/twister1-mode2.bin
	$(MKDIR_P) "./build"
	$(COPY) .\data\raw\twister1-mode2.bin build

./build/twister2-mode2.bin: ./data/raw/twister2-mode2.bin
	$(MKDIR_P) "./build"
	$(COPY) .\data\raw\twister2-mode2.bin build

./build/stripes-mode2.bin: ./data/raw/stripes-mode2.bin
	$(MKDIR_P) "./build"
	$(COPY) .\data\raw\stripes-mode2.bin build

./build/zoom-2by160-mode2.bin: ./data/raw/zoom-2by160-mode2.bin
	$(MKDIR_P) "./build"
	$(COPY) .\data\raw\zoom-2by160-mode2.bin build

./build/zoom-screen.bin: ./data/raw/zoom-screen.bin
	$(MKDIR_P) "./build"
	$(COPY) .\data\raw\zoom-screen.bin build

./build/checks-bitmask-0-to-3.bin: ./data/raw/checks-bitmask-0-to-3.bin
	$(MKDIR_P) "./build"
	$(COPY) .\data\raw\checks-bitmask-0-to-3.bin build

./build/checks-bitmask-4-to-7.bin: ./data/raw/checks-bitmask-4-to-7.bin
	$(MKDIR_P) "./build"
	$(COPY) .\data\raw\checks-bitmask-4-to-7.bin build

./build/diagonals-16.bin: ./data/raw/diagonals-16.bin
	$(MKDIR_P) "./build"
	$(COPY) .\data\raw\diagonals-16.bin build

./build/path-zoom-256.bin: ./data/raw/path-zoom-256.bin
	$(MKDIR_P) "./build"
	$(COPY) .\data\raw\path-zoom-256.bin build

./build/cube-widths-128.bin: ./data/raw/cube-widths-128.bin
	$(MKDIR_P) "./build"
	$(COPY) .\data\raw\cube-widths-128.bin build

##########################################################################
##########################################################################

# Rule to pack VGM files.
%.vgc : %.vgm
	$(MKDIR_P) "./build"
	$(PYTHON2) $(VGM_PACKER) $< -o $@

# Rule to convert PNG files, assumes MODE 2.
%.bin : %.png $(PNG2BBC_DEPS)
	$(MKDIR_P) "./build"
	$(PYTHON2) $(PNG2BBC) -q -o $@ $< 2

# Rule to EXO compress bin files.
%.exo : %.bin
	$(MKDIR_P) "./build"
	$(EXO_AND_ARGS) -o $@ $<@0x0000

##########################################################################
##########################################################################
