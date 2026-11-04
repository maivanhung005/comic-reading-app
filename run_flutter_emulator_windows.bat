@echo off
setlocal
cd /d "%~dp0frontend"
where flutter >nul 2>nul
if errorlevel 1 (
  echo ERROR: Flutter SDK was not found in PATH.
  echo Install Flutter, add its bin folder to PATH, then retry.
  pause
  exit /b 1
)
if not exist "android\gradle\wrapper\gradle-wrapper.jar" (
  echo Initializing Android Gradle wrapper using Flutter SDK...
  flutter create --platforms=android .
  if errorlevel 1 (
    echo ERROR: Android platform initialization failed.
    pause
    exit /b 1
  )
)
flutter pub get
if errorlevel 1 (
  pause
  exit /b 1
)
flutter run --dart-define=COMIC_API_URL=http://10.0.2.2:8080/api
pause
