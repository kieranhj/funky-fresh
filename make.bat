@echo off
echo Building CODE...
bin\beebasm.exe -i src\funky-fresh.asm -v > build\compile.txt

if %ERRORLEVEL% neq 0 (
	echo Failed to build code!
	exit /b 1
)

echo Building DISC...
mkdir disc
bin\beebasm.exe -i src\disc-layout.asm -do disc\funky-fresh.ssd -title "FUNKY FRESH" -boot FRESH -v

if %ERRORLEVEL% neq 0 (
	echo Failed to build disc image 'funky-fresh.ssd'
	exit /b 1
)
