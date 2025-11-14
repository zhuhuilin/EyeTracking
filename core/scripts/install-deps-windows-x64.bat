@echo off
REM Install dependencies for Windows x64

echo ============================================
echo Installing Dependencies for Windows x64
echo ============================================

set VCPKG_ROOT=C:\vcpkg

REM Check if vcpkg exists
if not exist "%VCPKG_ROOT%" (
    echo ERROR: vcpkg not found at %VCPKG_ROOT%
    echo Please install vcpkg first or update VCPKG_ROOT path
    exit /b 1
)

echo.
echo Installing OpenCV 4 with DNN module for x64-windows...
echo This may take 15-20 minutes as OpenCV will be built from source.
echo.

cd /d "%VCPKG_ROOT%"
vcpkg install opencv4[dnn]:x64-windows --recurse

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to install OpenCV
    exit /b %ERRORLEVEL%
)

echo.
echo ============================================
echo Dependencies installed successfully!
echo ============================================
echo.
echo Installed packages:
vcpkg list | findstr "x64-windows"
echo.
echo Installation location: %VCPKG_ROOT%\installed\x64-windows\
echo.
