@echo off
setlocal
cd /d "%~dp0"
echo =====================================================
echo  SMART STORY - CONG CU NHAP TRUYEN
echo =====================================================
python --version >nul 2>&1
if errorlevel 1 (
  echo Khong tim thay Python. Cai Python 3.10+ tu python.org va chon Add Python to PATH.
  pause
  exit /b 1
)
echo.
echo Cai cac thu vien can thiet (lan dau co the mat vai phut)...
python -m pip install -r requirements-importer.txt
if errorlevel 1 (
  echo Cai thu vien that bai. Kiem tra ket noi Internet va pip.
  pause
  exit /b 1
)
echo.
python import_comics.py
set IMPORT_EXIT=%ERRORLEVEL%
echo.
if not "%IMPORT_EXIT%"=="0" echo Cong cu ket thuc voi ma loi %IMPORT_EXIT%. Hay xem thong bao o tren.
pause
exit /b %IMPORT_EXIT%
