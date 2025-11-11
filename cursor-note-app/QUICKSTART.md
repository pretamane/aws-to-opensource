# Quick Start Guide

## Installation (3 Steps)

### Step 1: Install Dependencies
```bash
cd cursor-note-app
npm install
```

### Step 2: Compile Extension
```bash
npm run compile
```

### Step 3: Run in Cursor
1. Open the `cursor-note-app` folder in Cursor IDE
2. Press `F5` to launch Extension Development Host
3. In the new window, press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
4. Type: `Open Note App (Separate Panel)` or `Open Note App (Attached Panel)`

## Alternative: Use Setup Script

```bash
cd cursor-note-app
./setup.sh
```

Then follow Step 3 above.

## Usage

### Opening the Note App

**Separate Panel** (opens in main editor area):
- Command: `Open Note App (Separate Panel)`
- Best for: Full-screen note taking

**Attached Panel** (opens beside your code):
- Command: `Open Note App (Attached Panel)`
- Best for: Taking notes while coding

### Features

- **Add Note**: Click "+ Add Note" button
- **Edit Note**: Click on title or content to edit
- **Delete Note**: Click "Delete" button on any note
- **Auto-save**: Notes save automatically after 2 seconds
- **Manual Save**: Click " Save" button
- **Clear All**: Click "️ Clear All" button (with confirmation)

### Data Storage

Notes are saved to `.cursor-notes.json` in your workspace root.

## Packaging for Distribution

To create a `.vsix` file for installation:

```bash
# Install vsce globally
npm install -g @vscode/vsce

# Package the extension
vsce package
```

Then install the `.vsix` file in Cursor:
1. Open Command Palette (`Ctrl+Shift+P`)
2. Run: `Extensions: Install from VSIX...`
3. Select the generated `.vsix` file

## Troubleshooting

### Extension not loading
- Make sure you've run `npm install` and `npm run compile`
- Check the Output panel in Cursor for errors
- Restart Cursor IDE

### Notes not saving
- Ensure you have a workspace folder open
- Check file permissions in your workspace
- Verify `.cursor-notes.json` can be created

### Panel not opening
- Make sure you're in the Extension Development Host window (launched with F5)
- Check that the extension is activated
- Try reloading the window (`Ctrl+R` or `Cmd+R`)

## Next Steps

- Read the full [README.md](README.md) for detailed documentation
- Customize colors and behavior in `src/extension.ts`
- Add keyboard shortcuts in Cursor's Keyboard Shortcuts settings

---

**Happy Note Taking! **

