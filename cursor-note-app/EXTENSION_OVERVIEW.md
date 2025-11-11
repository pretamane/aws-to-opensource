# Cursor Note App Extension - Overview

## What is This?

A fully-functional VS Code/Cursor IDE extension that provides a beautiful note-taking widget that can be displayed as either:
- **Separate Panel** - Opens in the main editor area
- **Attached Panel** - Opens beside your code editor

## Project Structure

```
cursor-note-app/
├── src/
│   └── extension.ts      # Main extension code (TypeScript)
├── out/                  # Compiled JavaScript (generated after npm run compile)
├── package.json          # Extension manifest and configuration
├── tsconfig.json         # TypeScript compiler configuration
├── README.md            # Full documentation
├── QUICKSTART.md        # Quick start guide
├── setup.sh             # Setup script
├── .gitignore           # Git ignore rules
└── .vscodeignore        # Files to exclude from VSIX package
```

## Key Features

### 1. Dual Panel Modes
- **Separate Panel**: Full editor area for focused note-taking
- **Attached Panel**: Side-by-side with code for reference notes

### 2. Rich Note Management
- Create multiple notes with titles and content
- Edit notes inline
- Delete individual notes
- Clear all notes with confirmation
- Auto-save after 2 seconds of inactivity
- Manual save option

### 3. Persistent Storage
- Notes saved to `.cursor-notes.json` in workspace root
- Automatically loads notes when extension opens
- JSON format for easy editing/backup

### 4. Modern UI
- Matches Cursor's theme automatically
- Smooth animations
- Responsive design
- Status indicators
- Note count display

### 5. User Experience
- Command Palette integration
- Keyboard shortcut support (configurable)
- Auto-save with visual feedback
- Timestamp display (relative time)
- Empty state messaging

## Technical Implementation

### Extension Architecture

1. **Activation**: Extension activates on command execution
2. **Webview Panel**: Uses VS Code's webview API for custom UI
3. **Message Passing**: Bidirectional communication between extension and webview
4. **File System**: Reads/writes JSON file in workspace
5. **State Management**: Maintains panel state across sessions

### Technologies Used

- **TypeScript**: Extension code
- **HTML/CSS/JavaScript**: Webview UI
- **VS Code API**: Extension host integration
- **Node.js**: File system operations

### Key VS Code APIs

- `vscode.WebviewPanel` - Custom panel creation
- `vscode.commands` - Command registration
- `vscode.workspace` - Workspace access
- `fs` - File system operations
- `path` - Path manipulation

## Installation Methods

### Development Mode
1. Clone/navigate to extension directory
2. Run `npm install`
3. Run `npm run compile`
4. Press F5 in Cursor to launch Extension Development Host
5. Use commands to open Note App

### Production Mode
1. Package extension: `vsce package`
2. Install VSIX: `Extensions: Install from VSIX...`
3. Use commands from Command Palette

## Usage Flow

1. **Open Extension**: Use Command Palette → "Open Note App"
2. **Create Note**: Click "+ Add Note" button
3. **Edit Note**: Click on title/content fields
4. **Auto-save**: Changes save automatically after 2 seconds
5. **Delete Note**: Click "Delete" button on note card
6. **Clear All**: Click "Clear All" button (with confirmation)
7. **Close Panel**: Close panel - notes persist in `.cursor-notes.json`

## Data Format

Notes are stored in JSON format:

```json
[
  {
    "id": 0,
    "title": "Note Title",
    "content": "Note content...",
    "date": "2025-01-21T10:30:00.000Z"
  }
]
```

## Customization Options

### Change Auto-save Interval
Edit `src/extension.ts`, find the timeout value (default: 2000ms)

### Modify UI Colors
Colors automatically adapt to Cursor theme via CSS variables:
- `--vscode-editor-background`
- `--vscode-editor-foreground`
- `--vscode-button-background`
- etc.

### Add Keyboard Shortcuts
1. Open Keyboard Shortcuts (`Ctrl+K Ctrl+S`)
2. Search for `cursorNoteApp.open`
3. Add custom keybinding

## Commands Available

- `cursorNoteApp.open` - Open as separate panel
- `cursorNoteApp.openAttached` - Open as attached panel
- `cursorNoteApp.save` - Save notes manually
- `cursorNoteApp.clear` - Clear all notes

## Browser Compatibility

The webview uses standard web technologies supported by:
- Chromium (VS Code/Cursor's webview)
- Modern CSS (Flexbox, Grid)
- ES6+ JavaScript

## Performance Considerations

- Notes are loaded once on panel open
- Auto-save is debounced (2 seconds)
- File I/O is asynchronous
- Panel state is retained when hidden
- No external dependencies in webview

## Security

- Notes stored locally in workspace
- No external API calls
- Input sanitization via `escapeHtml()`
- File operations scoped to workspace
- No sensitive data transmission

## Future Enhancements

Potential improvements:
- Markdown support
- Note categories/tags
- Search functionality
- Export to different formats
- Sync across workspaces
- Rich text editing
- Note templates
- Keyboard shortcuts for actions
- Drag-and-drop reordering

## Troubleshooting

### Common Issues

1. **Extension not loading**: Run `npm install` and `npm run compile`
2. **Notes not saving**: Check workspace folder permissions
3. **Panel not opening**: Ensure Extension Development Host is running
4. **UI not rendering**: Check browser console in webview dev tools

### Debug Mode

1. Open Extension Development Host (F5)
2. Open Developer Tools (`Help → Toggle Developer Tools`)
3. Check Console for errors
4. Check Output panel for extension logs

## License

Provided as-is for use with Cursor IDE.

## Support

For issues or questions:
1. Check README.md for detailed documentation
2. Check QUICKSTART.md for setup help
3. Review extension code in `src/extension.ts`
4. Check VS Code extension documentation

---

**Built with ️ for Cursor IDE**

