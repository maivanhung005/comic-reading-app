@echo off
setlocal
cd /d "%~dp0frontend"
echo ================================================
echo Comic Reading App - Android setup
echo ================================================
where flutter >nul 2>nul
if errorlevel 1 (
  echo ERROR: Flutter SDK was not found in PATH.
  echo Install Flutter, add its bin folder to PATH, then run this file again.
  pause
  exit /b 1
)
if not exist "android\gradle\wrapper\gradle-wrapper.jar" (
  echo Android scaffold/wrapper is missing. Initializing it with Flutter...
  flutter create --platforms=android .
  if errorlevel 1 (
    echo ERROR: Flutter could not initialize the Android platform.
    pause
    exit /b 1
  )
  echo.
  echo IMPORTANT: Check android\settings.gradle and gradle-wrapper.properties
  echo after initialization; restore this project's required AGP/Gradle versions if they changed.
) else (
  echo Android scaffold already exists. Keeping the configured Gradle files unchanged.
)
flutter pub get
if errorlevel 1 (
  echo ERROR: flutter pub get failed. Check Internet and Flutter SDK settings.
  pause
  exit /b 1
)
echo.
echo Setup complete. Open the frontend folder in Android Studio and press Run.
pause
