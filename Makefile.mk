ifeq ($(OS),Windows_NT)
RM_RF:=-cmd /c rd /s /q
MKDIR_P:=-cmd /c mkdir
BEEBASM?=bin\beebasm.exe
EXO?=bin\exomizer.exe
PYTHON2?=C:\Dev\Python27\python.exe
PYTHON3?=python.exe
else
RM_RF:=rm -Rf
MKDIR_P:=mkdir -p
BEEBASM?=beebasm
EXO?=exomizer
PYTHON3?=python
endif


##########################################################################
##########################################################################

.PHONY:disc
disc: code music
	$(RM_RF) "disc"
	$(MKDIR_P) "./disc"
	$(BEEBASM) -i src/disc-layout.asm -do disc/funky-fresh.ssd -title "FUNKY FRESH" -boot FRESH -v

.PHONY:code
code: music
	$(MKDIR_P) "./build"
	$(BEEBASM) -i src/funky-fresh.asm -v > build/compile.txt

.PHONY:music
music: build/beeb-demo.bbc.vgc

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
	$(PYTHON2) bin/vgmconverter.py data/music/beeb-demo.vgm -t bbc -o build/beeb-demo.bbc.vgm

##########################################################################
##########################################################################

# Rule to pack VGM files.
%.vgc : %.vgm
	$(MKDIR_P) "./build"
	$(PYTHON2) bin/vgmpacker.py $< -o $@

##########################################################################
##########################################################################
