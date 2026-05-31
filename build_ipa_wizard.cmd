@echo off
setlocal

cd /d "%~dp0"

echo ================================================
echo           IPA Builder Wizard Launcher
echo ================================================
echo.

where python >nul 2>&1
if not "%ERRORLEVEL%"=="0" (
  echo [ERROR] Python not found in PATH.
  echo Install Python 3 and retry.
  pause
  exit /b 1
)

python "%~dp0build_ipa.py" --interactive
set EXIT_CODE=%ERRORLEVEL%

echo.
echo Script exit code: %EXIT_CODE%
if not "%EXIT_CODE%"=="0" (
  echo Build failed. Check logs in ipa_build_workspace\run-...\logs
)

pause
exit /b %EXIT_CODE%
