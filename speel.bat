@echo off
REM Dubbelklik dit bestand om Het Klimbos te spelen.
cd /d "%~dp0"
"C:\Users\Gebruiker\Downloads\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64.exe" --path "%CD%"
if errorlevel 1 pause
