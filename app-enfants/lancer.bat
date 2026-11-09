@echo off
REM ==================================================================
REM   Lance "Le Jardin du Tawhid" en local.
REM   Windows : double-cliquez sur ce fichier.
REM   Depuis PowerShell, ecrivez :  .\lancer.bat
REM ==================================================================
setlocal
set PORT=8000
cd /d "%~dp0"

set PY=
where python >nul 2>nul && set PY=python
if "%PY%"=="" where py >nul 2>nul && set PY=py

if "%PY%"=="" (
  echo.
  echo   ATTENTION : Python est introuvable.
  echo.
  echo   1. Installez-le depuis https://www.python.org
  echo      ^(cochez "Add Python to PATH" pendant l'installation^)
  echo   2. Puis relancez ce fichier.
  echo.
  echo   Alternative si vous avez Node.js :  npx serve .
  echo.
  pause
  exit /b 1
)

echo.
echo   Le Jardin du Tawhid
echo   -------------------------------------------------
echo.
echo   Sur cet ordinateur :
echo      http://localhost:%PORT%
echo.
echo   Sur un telephone ^(meme Wi-Fi^) :

for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4"') do (
  for /f "tokens=* delims= " %%b in ("%%a") do echo      http://%%b:%PORT%
)

echo.
echo   Ouvrez ce lien, puis "Installer l'application".
echo   Laissez cette fenetre ouverte. Ctrl+C pour arreter.
echo   -------------------------------------------------
echo.

%PY% -m http.server %PORT% --bind 0.0.0.0
pause
