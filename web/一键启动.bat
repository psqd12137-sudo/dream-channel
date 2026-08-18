@echo off
setlocal
cd /d "%~dp0"
set "PORT=8787"
where py >nul 2>nul
if %errorlevel% equ 0 (
  start "织梦频道网页游戏" "http://127.0.0.1:%PORT%/"
  py -3 -m http.server %PORT% --bind 127.0.0.1
  goto :eof
)
where python >nul 2>nul
if %errorlevel% equ 0 (
  start "织梦频道网页游戏" "http://127.0.0.1:%PORT%/"
  python -m http.server %PORT% --bind 127.0.0.1
  goto :eof
)
echo 未找到 Python 3，请先安装 Python 3。
pause
