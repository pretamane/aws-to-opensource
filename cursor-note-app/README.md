# Cursor Note App Widget

A beautiful, feature-rich note-taking widget for Cursor IDE that can be displayed as either a **separate panel** or an **attached panel** alongside your code editor.

## Features

-  **Rich Note Editor** - Create, edit, and organize notes with titles and content
-  **Auto-save** - Automatically saves your notes after 2 seconds of inactivity
-  **Modern UI** - Beautiful interface that matches Cursor's theme
-  **Persistent Storage** - Notes are saved to `.cursor-notes.json` in your workspace
-  **Panel Modes** - Open as separate panel or attached beside editor
- ️ **Quick Actions** - Delete individual notes or clear all notes
- ⏰ **Timestamps** - Each note shows when it was last modified
-  **Command Palette** - Access all features via Cursor's command palette

## Installation

### Method 1: Install from Source (Development)

1. **Clone or navigate to the extension directory:**
   ```bash
   cd cursor-note-app
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Compile TypeScript:**
   ```bash
   npm run compile
   ```

4. **Open in Cursor/VS Code:**
   - Open the `cursor-note-app` folder in Cursor
   - Press `F5` to launch a new Extension Development Host window
   - In the new window, use the commands to open the Note App

### Method 2: Package and Install (Production)

1. **Install vsce (VS Code Extension Manager):**
   ```bash
   npm install -g @vscode/vsce
   ```

2. **Package the extension:**
   ```bash
   cd cursor-note-app
   vsce package
   ```

3. **Install the packaged extension:**
   - In Cursor, open the Command Palette (`Ctrl+Shift+P` / `Cmd+Shift+P`)
   - Run: `Extensions: Install from VSIX...`
   - Select the generated `.vsix` file

## Usage

### Opening the Note App

**Option 1: Separate Panel**
- Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
- Type: `Open Note App (Separate Panel)`
- The note app opens in a new panel

**Option 2: Attached Panel**
- Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
- Type: `Open Note App (Attached Panel)`
- The note app opens beside your editor

### Using the Note App

1. **Add a Note:**
   - Click the "+ Add Note" button at the bottom
   - A new note card will appear

2. **Edit Notes:**
   - Click on the title to edit it
   - Click in the content area to edit the note body
   - Changes are auto-saved after 2 seconds

3. **Delete a Note:**
   - Click the "Delete" button on any note card

4. **Save Notes:**
   - Notes auto-save automatically
   - Or click the " Save" button to manually save

5. **Clear All Notes:**
   - Click the "️ Clear All" button
   - Confirm the action when prompted

### Keyboard Shortcuts

You can add custom keyboard shortcuts in Cursor:

1. Open Keyboard Shortcuts: `Ctrl+K Ctrl+S` (or `Cmd+K Cmd+S` on Mac)
2. Search for: `cursorNoteApp.open`
3. Add your preferred keybinding

Example:
```json
{
    "key": "ctrl+alt+n",
    "command": "cursorNoteApp.open"
}
```

## Data Storage

Notes are saved to `.cursor-notes.json` in your workspace root. This file is automatically created when you save your first note.

**Example `.cursor-notes.json`:**
```json
[
  {
    "id": 0,
    "title": "My First Note",
    "content": "This is the content of my note.",
    "date": "2025-01-21T10:30:00.000Z"
  }
]
```

## Commands

The extension provides the following commands:

- `cursorNoteApp.open` - Open Note App (Separate Panel)
- `cursorNoteApp.openAttached` - Open Note App (Attached Panel)
- `cursorNoteApp.save` - Save Notes
- `cursorNoteApp.clear` - Clear All Notes

## Development

### Project Structure

```
cursor-note-app/
├── src/
│   └── extension.ts      # Main extension code
├── out/                  # Compiled JavaScript (generated)
├── package.json          # Extension manifest
├── tsconfig.json         # TypeScript configuration
└── README.md            # This file
```

### Building

```bash
# Compile TypeScript
npm run compile

# Watch for changes
npm run watch
```

### Debugging

1. Open the extension folder in Cursor
2. Press `F5` to launch Extension Development Host
3. Set breakpoints in `src/extension.ts`
4. Use the debugger to step through code

## Customization

### Changing Colors

The extension uses Cursor's built-in theme variables, so it automatically adapts to your theme. The colors used include:

- `--vscode-editor-background` - Background color
- `--vscode-editor-foreground` - Text color
- `--vscode-textLink-foreground` - Link/header color
- `--vscode-button-background` - Button background
- `--vscode-panel-border` - Border color

### Modifying Auto-save Interval

In `src/extension.ts`, find the auto-save timeout and modify:

```typescript
saveTimeout = setTimeout(() => {
    updateStatus('Auto-saving...', 'saving');
    saveNotes(true);
}, 2000); // Change 2000 to your desired milliseconds
```

## Troubleshooting

### Notes not saving

- Check that you have a workspace folder open
- Verify write permissions in the workspace directory
- Check the Cursor Output panel for error messages

### Panel not opening

- Make sure the extension is activated
- Check the Command Palette for available commands
- Restart Cursor if the extension was just installed

### Notes not loading

- Verify that `.cursor-notes.json` exists in your workspace root
- Check that the JSON file is valid
- Try saving a new note to recreate the file

## Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## License

This extension is provided as-is for use with Cursor IDE.

## Requirements

- Cursor IDE or VS Code 1.74.0 or higher
- Node.js and npm (for development)

## Changelog

### Version 1.0.0
- Initial release
- Separate and attached panel modes
- Auto-save functionality
- Rich note editor
- Persistent storage
- Delete and clear features

---

**Enjoy taking notes in Cursor! **

