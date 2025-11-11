# Browser Panel in Cursor - Setup Guide

## Option 1: Use Cursor's Built-in Browser (Recommended)

1. **Open Browser Tab:**
   - Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
   - Type "Browser" or "Open Browser"
   - Select the browser option

2. **Dock to Bottom Panel:**
   - Click and drag the browser tab
   - Drag it to the bottom panel area
   - Release to dock it

3. **Navigate to your app:**
   - Enter: `http://localhost:8080`

## Option 2: Install Browser Preview Extension

1. **Install Extension:**
   - Open Extensions (Ctrl+Shift+X)
   - Search for "Browser Preview"
   - Install "Browser Preview" by Auchenberg

2. **Open Browser Preview:**
   - Press `Ctrl+Shift+P`
   - Type "Browser Preview: Open Preview"
   - Enter URL: `http://localhost:8080`

3. **Dock to Bottom:**
   - Right-click the preview tab
   - Select "Move to Bottom Panel" or drag it down

## Option 3: Use Simple Browser (Built-in)

1. **Open Simple Browser:**
   - Press `Ctrl+Shift+P`
   - Type "Simple Browser: Show"
   - Enter URL: `http://localhost:8080`

2. **This opens in a new editor tab**

## Option 4: Use Preview HTML File

1. **Open the preview file:**
   - Open `preview-server.html` in Cursor
   - Right-click → "Open with Live Server" (if installed)
   - Or use the Simple Browser on the HTML file

## Quick Access

Create a keyboard shortcut:
1. Go to File → Preferences → Keyboard Shortcuts
2. Search for "browser"
3. Add custom shortcut for browser preview

## Troubleshooting

- If browser tab won't dock: Try restarting Cursor
- If localhost:8080 won't load: Make sure your Docker Compose stack is running
- If extension won't install: Check Cursor's extension compatibility

