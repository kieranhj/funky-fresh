# Wrapper so that `make` works from PowerShell / Windows Terminal.
# GNU make runs recipes with cmd.exe here (no sh on PATH).
# The real build is Makefile.mk, run with the bundled bin\snmake.exe as make.bat does
# (make.bat runs snmake with -f, so nothing here recurses into this file).
SNMAKE := bin\snmake.exe -f Makefile.mk

.PHONY: all disc code clean help

all: disc

disc:
	$(SNMAKE) disc

code:
	$(SNMAKE) code

clean:
	$(SNMAKE) clean

help:
	@echo make        - build disc\funky-fresh.ssd (Makefile.mk "disc": assets, music, code, then the disc)
	@echo make code   - assemble only (listing in compile.txt)
	@echo make clean  - delete build\ and disc\
	@echo make help   - this list
	@echo run.bat runs the demo in an emulator (not run by make)
