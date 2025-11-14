@echo off
REM Build script for Windows x64

echo ============================================
echo Building EyeTracking Core for Windows x64
echo ============================================

set SCRIPT_DIR=%~dp0
set CORE_DIR=%SCRIPT_DIR%..
set BUILD_DIR=%CORE_DIR%\build\windows-x64
set INSTALL_DIR=%CORE_DIR%\install\windows-x64
set CMAKE_EXE="C:\Program Files\CMake\bin\cmake.exe"
set VCPKG_ROOT=C:\vcpkg

REM Check if CMake exists
if not exist %CMAKE_EXE% (
    echo ERROR: CMake not found at %CMAKE_EXE%
    echo Please install CMake or update CMAKE_EXE path
    exit /b 1
)

REM Check if vcpkg exists
if not exist "%VCPKG_ROOT%" (
    echo ERROR: vcpkg not found at %VCPKG_ROOT%
    echo Please install vcpkg or update VCPKG_ROOT path
    exit /b 1
)

echo.
echo Configuration:
echo - Build Directory: %BUILD_DIR%
echo - Install Directory: %INSTALL_DIR%
echo - vcpkg Root: %VCPKG_ROOT%
echo.

REM Create build directory
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

REM Configure with CMake
echo Configuring CMake...
cd /d "%BUILD_DIR%"
%CMAKE_EXE% ..\.. ^
    -G "Visual Studio 17 2022" ^
    -A x64 ^
    -DCMAKE_TOOLCHAIN_FILE=%VCPKG_ROOT%/scripts/buildsystems/vcpkg.cmake ^
    -DVCPKG_TARGET_TRIPLET=x64-windows ^
    -DCMAKE_INSTALL_PREFIX=%INSTALL_DIR% ^
    -DCMAKE_BUILD_TYPE=Release

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: CMake configuration failed
    exit /b %ERRORLEVEL%
)

REM Build
echo.
echo Building...
%CMAKE_EXE% --build . --config Release

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Build failed
    exit /b %ERRORLEVEL%
)

REM Install
echo.
echo Installing to %INSTALL_DIR%...
%CMAKE_EXE% --install . --config Release

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Installation failed
    exit /b %ERRORLEVEL%
)

echo.
echo ============================================
echo Build completed successfully!
echo ============================================
echo Output: %INSTALL_DIR%
echo.

cd /d "%CORE_DIR%"
