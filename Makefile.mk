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
assets: ./build/logo-mode2.exo \
		./build/doom-screen.exo ./build/scr-screen.exo \
		./build/twister1-mode2.exo ./build/twister2-mode2.exo \
		./build/funky-sequence.bin ./build/stripes-mode2.exo

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
./build/doom-screen.bin: ./data/gfx/Doom.png
	$(MKDIR_P) "./build"
	$(PYTHON2) $(PNG2BBC) -q -o $@ $< --160 2

./build/scr-screen.exo: ./build/scr-screen.bin
./build/scr-screen.bin: ./data/gfx/TitleScreen_BBC.png
	$(MKDIR_P) "./build"
	$(PYTHON2) $(PNG2BBC) -q -o $@ $< --160 2

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

./build/twister1-mode2.bin: ./data/raw/twister1-mode2.bin
	$(MKDIR_P) "./build"
	$(COPY) .\data\raw\twister1-mode2.bin build

./build/twister2-mode2.bin: ./data/raw/twister2-mode2.bin
	$(MKDIR_P) "./build"
	$(COPY) .\data\raw\twister2-mode2.bin build

./build/stripes-mode2.bin: ./data/raw/stripes-mode2.bin
	$(MKDIR_P) "./build"
	$(COPY) .\data\raw\stripes-mode2.bin build

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
