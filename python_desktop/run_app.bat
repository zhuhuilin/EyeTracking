@echo off
REM Eye Tracking Desktop App Launcher
REM This batch file launches the PyQt6 desktop application

echo ========================================
echo Eye Tracking Desktop App
echo ========================================
echo.

REM Check if venv exists
if not exist "venv\Scripts\python.exe" (
    echo ERROR: Virtual environment not found!
    echo Please run: python -m venv venv
    echo Then: venv\Scripts\pip install -r requirements.txt
    echo.
    pause
    exit /b 1
)

REM Activate venv and run the app
echo Starting application...
echo.

venv\Scripts\python.exe main.py

echo.
echo Application closed.
pause
