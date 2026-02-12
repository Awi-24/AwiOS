@echo off
REM Gera app_icon.ico e icones web a partir de icon/app_icon.png
cd /d "%~dp0.."
call flutter pub get
call dart run flutter_launcher_icons
echo.
echo Done. Rebuild: flutter clean ^&^& flutter build windows
pause
