#!/bin/bash

# Install dependencies for macOS

set -e

echo "============================================"
echo "Installing Dependencies for macOS"
echo "============================================"

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "ERROR: Homebrew not found"
    echo "Please install Homebrew first:"
    echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

echo ""
echo "Installing OpenCV 4 via Homebrew..."
echo ""

# Install OpenCV
brew install opencv

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install OpenCV"
    exit 1
fi

echo ""
echo "============================================"
echo "Dependencies installed successfully!"
echo "============================================"
echo ""
echo "Installed packages:"
brew list | grep opencv
echo ""
echo "OpenCV location:"
brew --prefix opencv
echo ""
echo "Headers: $(brew --prefix opencv)/include"
echo "Libraries: $(brew --prefix opencv)/lib"
echo ""
