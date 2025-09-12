@echo off
echo 🚀 Starting Android Emulator + Flutter App...

REM Ganti ID emulator sesuai punya kamu
set EMULATOR_NAME=pixel_2

REM Jalankan emulator
echo ▶️ Launching emulator %EMULATOR_NAME%...
start "" "%USERPROFILE%\AppData\Local\Android\Sdk\emulator\emulator.exe" -avd %EMULATOR_NAME%

REM Tunggu emulator siap
echo ⏳ Waiting for emulator to boot...
:wait_for_emulator
"%USERPROFILE%\AppData\Local\Android\Sdk\platform-tools\adb.exe" wait-for-device
for /f "tokens=*" %%i in ('"%USERPROFILE%\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell getprop sys.boot_completed 2^>nul') do (
    if "%%i"=="1" goto booted
)
timeout /t 5 >nul
goto wait_for_emulator

:booted
echo ✅ Emulator is ready!

REM Jalankan Flutter app
echo ▶️ Running Flutter app...
flutter run
