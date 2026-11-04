@echo off
setlocal
where powershell.exe >nul 2>nul
if errorlevel 1 (
  echo ERROR: Windows PowerShell was not found.
  pause
  exit /b 1
)
echo Starting Smart Story backend with private local configuration...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0backend\tools\run_backend_windows.ps1"
if errorlevel 1 (
  echo Backend did not start. Review the error shown above.
  pause
  exit /b 1
)
pause
