@echo off
REM ============================================================================
REM  Maakt je UPLOADSLEUTEL voor Google Play en zet hem als geheim op GitHub.
REM
REM  - De sleutel komt in %USERPROFILE%\klimbos-sleutel\ (NIET in het project).
REM  - Kies een sterk wachtwoord en BEWAAR het goed (bijv. in een wachtwoordkluis).
REM    Raak je de sleutel kwijt, dan kan Google hem wel vervangen, maar dat kost
REM    gedoe. Deel hem nooit met iemand.
REM  - Je typt het wachtwoord zelf in; dit script slaat het nergens op.
REM ============================================================================
setlocal
set KEYTOOL="C:\Program Files\Eclipse Adoptium\jdk-25.0.1.8-hotspot\bin\keytool.exe"
set MAP=%USERPROFILE%\klimbos-sleutel
set SLEUTEL=%MAP%\klimbos-upload.keystore
set ALIAS=klimbos

if exist "%SLEUTEL%" (
  echo Er bestaat al een uploadsleutel: %SLEUTEL%
  echo Die wordt NIET overschreven. Ga verder met het zetten op GitHub.
) else (
  if not exist "%MAP%" mkdir "%MAP%"
  echo.
  echo Stap 1: de sleutel maken. Keytool vraagt een wachtwoord (twee keer^)
  echo en een paar gegevens (je naam mag, de rest mag je leeg laten^).
  echo.
  %KEYTOOL% -genkeypair -v -keystore "%SLEUTEL%" -alias %ALIAS% -keyalg RSA -keysize 2048 -validity 10000 -storetype PKCS12
  if errorlevel 1 goto fout
)

echo.
echo Stap 2: de sleutel als geheim op GitHub zetten (repo kgdivw/klimbos).
powershell -NoProfile -Command "[Convert]::ToBase64String([IO.File]::ReadAllBytes('%SLEUTEL%')) | gh secret set ANDROID_UPLOAD_KEYSTORE_BASE64 -R kgdivw/klimbos"
if errorlevel 1 goto fout
gh secret set ANDROID_UPLOAD_ALIAS -b %ALIAS% -R kgdivw/klimbos
if errorlevel 1 goto fout
echo.
echo Typ nu nog een keer HETZELFDE wachtwoord (het wordt geheim op GitHub bewaard):
gh secret set ANDROID_UPLOAD_PASSWORD -R kgdivw/klimbos
if errorlevel 1 goto fout

echo.
echo Klaar! Bij de volgende push bouwt GitHub ook HetKlimbos.aab voor de Play Store.
pause
exit /b 0

:fout
echo.
echo Er ging iets mis. Lees de melding hierboven.
pause
exit /b 1
