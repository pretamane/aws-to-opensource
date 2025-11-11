#!/bin/bash

# Cursor Note App - Setup Script
echo " Setting up Cursor Note App extension..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo " Node.js is not installed. Please install Node.js first."
    exit 1
fi

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo " npm is not installed. Please install npm first."
    exit 1
fi

echo " Node.js and npm are installed"

# Install dependencies
echo " Installing dependencies..."
npm install

if [ $? -ne 0 ]; then
    echo " Failed to install dependencies"
    exit 1
fi

echo " Dependencies installed"

# Compile TypeScript
echo " Compiling TypeScript..."
npm run compile

if [ $? -ne 0 ]; then
    echo " Failed to compile TypeScript"
    exit 1
fi

echo " TypeScript compiled successfully"

echo ""
echo " Setup complete! Next steps:"
echo "1. Open this folder in Cursor IDE"
echo "2. Press F5 to launch Extension Development Host"
echo "3. In the new window, use Command Palette (Ctrl+Shift+P) and run:"
echo "   - 'Open Note App (Separate Panel)' or"
echo "   - 'Open Note App (Attached Panel)'"
echo ""
echo "To package for distribution:"
echo "  npm install -g @vscode/vsce"
echo "  vsce package"

