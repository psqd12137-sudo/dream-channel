@echo off
setlocal
if "%~1"=="" (
  echo Drag a presentation-pack folder onto this file.
  echo See PRESENTATION_PACK.md for the required directory layout.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0import_presentation_pack.ps1" -PackPath "%~1" -ProjectPath "%~dp0.."
if errorlevel 1 pause
endlocal
