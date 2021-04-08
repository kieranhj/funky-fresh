@echo off
set PYTHON2=C:\Dev\Python27\python.exe
set PYTHON3=python.exe
set BEEBASM=bin\beebasm.exe
set VGMCONVERTER=%PYTHON2% bin\vgmconverter.py
set VGMPACKER=%PYTHON2% bin\vgmpacker.py

echo Building MUSIC...
%VGMCONVERTER% data\music\beeb-demo.vgm -t bbc -o build\beeb-demo.bbc.vgm

if %ERRORLEVEL% neq 0 (
	echo Failed to convert VGM!
	exit /b 1
)

%VGMPACKER% build\beeb-demo.bbc.vgm -o build\beeb-demo.bbc.vgc

if %ERRORLEVEL% neq 0 (
	echo Failed to pack VGM!
	exit /b 1
)

echo Building CODE...
%BEEBASM% -i src\funky-fresh.asm -v > build\compile.txt

if %ERRORLEVEL% neq 0 (
	echo Failed to build code!
	exit /b 1
)

echo Building DISC...
mkdir disc
del disc\funky-fresh.ssd
%BEEBASM% -i src\disc-layout.asm -do disc\funky-fresh.ssd -title "FUNKY FRESH" -boot FRESH -v

if %ERRORLEVEL% neq 0 (
	echo Failed to build disc image 'funky-fresh.ssd'
	exit /b 1
)
