import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';

export function activate(context: vscode.ExtensionContext) {
    console.log('Cursor Note App extension is now active!');

    // Open Note App as Separate Panel
    const openSeparatePanel = vscode.commands.registerCommand('cursorNoteApp.open', () => {
        NoteAppPanel.createOrShow(context.extensionUri, 'separate');
    });

    // Open Note App as Attached Panel
    const openAttachedPanel = vscode.commands.registerCommand('cursorNoteApp.openAttached', () => {
        NoteAppPanel.createOrShow(context.extensionUri, 'attached');
    });

    // Save Notes Command
    const saveNotes = vscode.commands.registerCommand('cursorNoteApp.save', () => {
        if (NoteAppPanel.currentPanel) {
            NoteAppPanel.currentPanel.saveNotes();
        } else {
            vscode.window.showInformationMessage('Note App is not open. Please open it first.');
        }
    });

    // Clear Notes Command
    const clearNotes = vscode.commands.registerCommand('cursorNoteApp.clear', () => {
        if (NoteAppPanel.currentPanel) {
            NoteAppPanel.currentPanel.clearNotes();
        } else {
            vscode.window.showInformationMessage('Note App is not open. Please open it first.');
        }
    });

    context.subscriptions.push(openSeparatePanel, openAttachedPanel, saveNotes, clearNotes);

    // Restore panel if it was open when VS Code closed
    if (vscode.window.registerWebviewPanelSerializer) {
        vscode.window.registerWebviewPanelSerializer(NoteAppPanel.viewType, {
            async deserializeWebviewPanel(webviewPanel: vscode.WebviewPanel, state: any) {
                NoteAppPanel.revive(webviewPanel, context.extensionUri, state?.panelType || 'separate');
            }
        });
    }
}

class NoteAppPanel {
    public static currentPanel: NoteAppPanel | undefined;
    public static readonly viewType = 'cursorNoteApp';
    private readonly _panel: vscode.WebviewPanel;
    private readonly _extensionUri: vscode.Uri;
    private _disposables: vscode.Disposable[] = [];
    private _panelType: 'separate' | 'attached';

    public static createOrShow(extensionUri: vscode.Uri, panelType: 'separate' | 'attached') {
        const column = panelType === 'attached' 
            ? vscode.ViewColumn.Beside 
            : vscode.ViewColumn.One;

        // If we already have a panel, show it
        if (NoteAppPanel.currentPanel) {
            NoteAppPanel.currentPanel._panel.reveal(column);
            NoteAppPanel.currentPanel._panelType = panelType;
            return;
        }

        // Otherwise, create a new panel
        const panel = vscode.window.createWebviewPanel(
            NoteAppPanel.viewType,
            'Note App',
            column,
            {
                enableScripts: true,
                localResourceRoots: [vscode.Uri.joinPath(extensionUri, 'media')],
                retainContextWhenHidden: true
            }
        );

        NoteAppPanel.currentPanel = new NoteAppPanel(panel, extensionUri, panelType);
    }

    public static revive(panel: vscode.WebviewPanel, extensionUri: vscode.Uri, panelType: 'separate' | 'attached') {
        NoteAppPanel.currentPanel = new NoteAppPanel(panel, extensionUri, panelType);
    }

    private constructor(panel: vscode.WebviewPanel, extensionUri: vscode.Uri, panelType: 'separate' | 'attached') {
        this._panel = panel;
        this._extensionUri = extensionUri;
        this._panelType = panelType;

        // Set the webview's initial html content
        this._update();

        // Listen for when the panel is disposed
        this._panel.onDidDispose(() => this.dispose(), null, this._disposables);

        // Handle messages from the webview
        this._panel.webview.onDidReceiveMessage(
            message => {
                switch (message.command) {
                    case 'save':
                        this.saveNotesToFile(message.content);
                        return;
                    case 'load':
                        this.loadNotesFromFile();
                        return;
                    case 'alert':
                        vscode.window.showInformationMessage(message.text);
                        return;
                }
            },
            null,
            this._disposables
        );
    }

    public saveNotes() {
        this._panel.webview.postMessage({ command: 'saveRequest' });
    }

    public clearNotes() {
        vscode.window.showWarningMessage(
            'Are you sure you want to clear all notes?',
            { modal: true },
            'Clear'
        ).then(selection => {
            if (selection === 'Clear') {
                this._panel.webview.postMessage({ command: 'clearRequest' });
            }
        });
    }

    private async saveNotesToFile(content: string) {
        try {
            const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
            if (!workspaceFolder) {
                vscode.window.showErrorMessage('No workspace folder found. Please open a folder first.');
                return;
            }

            const notesPath = path.join(workspaceFolder.uri.fsPath, '.cursor-notes.json');
            fs.writeFileSync(notesPath, content, 'utf8');
            vscode.window.showInformationMessage('Notes saved successfully!');
        } catch (error) {
            vscode.window.showErrorMessage(`Failed to save notes: ${error}`);
        }
    }

    private async loadNotesFromFile() {
        try {
            const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
            if (!workspaceFolder) {
                return;
            }

            const notesPath = path.join(workspaceFolder.uri.fsPath, '.cursor-notes.json');
            if (fs.existsSync(notesPath)) {
                const content = fs.readFileSync(notesPath, 'utf8');
                this._panel.webview.postMessage({ command: 'loadData', data: content });
            }
        } catch (error) {
            console.error('Failed to load notes:', error);
        }
    }

    public dispose() {
        NoteAppPanel.currentPanel = undefined;

        // Clean up our resources
        this._panel.dispose();

        while (this._disposables.length) {
            const x = this._disposables.pop();
            if (x) {
                x.dispose();
            }
        }
    }

    private _update() {
        const webview = this._panel.webview;
        this._panel.webview.html = this._getHtmlForWebview(webview);
        
        // Load existing notes after a short delay
        setTimeout(() => {
            this.loadNotesFromFile();
        }, 500);
    }

    private _getHtmlForWebview(webview: vscode.Webview) {
        return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cursor Note App</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: var(--vscode-editor-background);
            color: var(--vscode-editor-foreground);
            padding: 20px;
            height: 100vh;
            display: flex;
            flex-direction: column;
        }

        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
            padding-bottom: 15px;
            border-bottom: 2px solid var(--vscode-panel-border);
        }

        .header h1 {
            font-size: 24px;
            font-weight: 600;
            color: var(--vscode-textLink-foreground);
        }

        .toolbar {
            display: flex;
            gap: 10px;
        }

        button {
            padding: 8px 16px;
            background: var(--vscode-button-background);
            color: var(--vscode-button-foreground);
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 14px;
            transition: opacity 0.2s;
        }

        button:hover {
            opacity: 0.8;
        }

        button.secondary {
            background: var(--vscode-button-secondaryBackground);
            color: var(--vscode-button-secondaryForeground);
        }

        button.danger {
            background: var(--vscode-errorForeground);
            color: var(--vscode-editor-background);
        }

        .notes-container {
            flex: 1;
            display: flex;
            flex-direction: column;
            gap: 15px;
            overflow-y: auto;
            padding-right: 10px;
        }

        .note-card {
            background: var(--vscode-editorWidget-background);
            border: 1px solid var(--vscode-panel-border);
            border-radius: 8px;
            padding: 15px;
            transition: transform 0.2s, box-shadow 0.2s;
            animation: slideIn 0.3s ease-out;
        }

        @keyframes slideIn {
            from {
                opacity: 0;
                transform: translateY(-10px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }

        .note-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
        }

        .note-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 10px;
        }

        .note-title {
            font-size: 18px;
            font-weight: 600;
            color: var(--vscode-textLink-foreground);
            flex: 1;
            border: none;
            background: transparent;
            color: var(--vscode-editor-foreground);
            padding: 5px;
            border-radius: 4px;
        }

        .note-title:focus {
            outline: 2px solid var(--vscode-focusBorder);
            outline-offset: 2px;
        }

        .note-date {
            font-size: 12px;
            color: var(--vscode-descriptionForeground);
            margin-left: 10px;
        }

        .note-actions {
            display: flex;
            gap: 5px;
        }

        .note-actions button {
            padding: 4px 8px;
            font-size: 12px;
            background: transparent;
            border: 1px solid var(--vscode-panel-border);
        }

        .note-content {
            font-size: 14px;
            line-height: 1.6;
            color: var(--vscode-editor-foreground);
            min-height: 60px;
            padding: 10px;
            border: 1px solid var(--vscode-panel-border);
            border-radius: 4px;
            background: var(--vscode-input-background);
            resize: vertical;
            font-family: inherit;
            width: 100%;
        }

        .note-content:focus {
            outline: 2px solid var(--vscode-focusBorder);
            outline-offset: 2px;
        }

        .add-note-btn {
            padding: 15px;
            background: var(--vscode-button-background);
            color: var(--vscode-button-foreground);
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-size: 16px;
            font-weight: 600;
            margin-top: 10px;
            transition: transform 0.2s;
        }

        .add-note-btn:hover {
            transform: scale(1.02);
        }

        .empty-state {
            text-align: center;
            padding: 60px 20px;
            color: var(--vscode-descriptionForeground);
        }

        .empty-state h2 {
            font-size: 20px;
            margin-bottom: 10px;
            color: var(--vscode-editor-foreground);
        }

        .empty-state p {
            font-size: 14px;
        }

        .status-bar {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 10px;
            background: var(--vscode-statusBar-background);
            color: var(--vscode-statusBar-foreground);
            border-top: 1px solid var(--vscode-panel-border);
            margin-top: 15px;
            font-size: 12px;
        }

        .status-indicator {
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .status-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: var(--vscode-testing-iconPassed);
        }

        .status-dot.saving {
            background: var(--vscode-testing-iconQueued);
            animation: pulse 1s infinite;
        }

        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }

        /* Scrollbar styling */
        .notes-container::-webkit-scrollbar {
            width: 8px;
        }

        .notes-container::-webkit-scrollbar-track {
            background: var(--vscode-scrollbarSlider-background);
        }

        .notes-container::-webkit-scrollbar-thumb {
            background: var(--vscode-scrollbarSlider-activeBackground);
            border-radius: 4px;
        }

        .notes-container::-webkit-scrollbar-thumb:hover {
            background: var(--vscode-scrollbarSlider-hoverBackground);
        }
    </style>
</head>
<body>
    <div class="header">
        <h1> Note App</h1>
        <div class="toolbar">
            <button id="saveBtn" class="secondary"> Save</button>
            <button id="clearBtn" class="danger">️ Clear All</button>
        </div>
    </div>

    <div class="notes-container" id="notesContainer">
        <div class="empty-state" id="emptyState">
            <h2>No notes yet</h2>
            <p>Click "Add Note" to create your first note</p>
        </div>
    </div>

    <button class="add-note-btn" id="addNoteBtn">+ Add Note</button>

    <div class="status-bar">
        <div class="status-indicator">
            <div class="status-dot" id="statusDot"></div>
            <span id="statusText">Ready</span>
        </div>
        <span id="noteCount">0 notes</span>
    </div>

    <script>
        const vscode = acquireVsCodeApi();
        let notes = [];
        let noteIdCounter = 0;

        // DOM elements
        const notesContainer = document.getElementById('notesContainer');
        const emptyState = document.getElementById('emptyState');
        const addNoteBtn = document.getElementById('addNoteBtn');
        const saveBtn = document.getElementById('saveBtn');
        const clearBtn = document.getElementById('clearBtn');
        const statusText = document.getElementById('statusText');
        const statusDot = document.getElementById('statusDot');
        const noteCount = document.getElementById('noteCount');

        // Initialize
        function init() {
            addNoteBtn.addEventListener('click', addNote);
            saveBtn.addEventListener('click', saveNotes);
            clearBtn.addEventListener('click', clearAllNotes);
            
            // Listen for messages from extension
            window.addEventListener('message', event => {
                const message = event.data;
                switch (message.command) {
                    case 'loadData':
                        loadNotes(JSON.parse(message.data));
                        break;
                    case 'saveRequest':
                        saveNotes();
                        break;
                    case 'clearRequest':
                        clearAllNotes(true);
                        break;
                }
            });

            // Auto-save on change (debounced)
            let saveTimeout;
            notesContainer.addEventListener('input', () => {
                clearTimeout(saveTimeout);
                saveTimeout = setTimeout(() => {
                    updateStatus('Auto-saving...', 'saving');
                    saveNotes(true);
                }, 2000);
            });
        }

        function addNote() {
            const note = {
                id: noteIdCounter++,
                title: 'New Note',
                content: '',
                date: new Date().toISOString()
            };
            notes.unshift(note);
            renderNotes();
            updateStatus('Note added', 'ready');
        }

        function deleteNote(id) {
            notes = notes.filter(note => note.id !== id);
            renderNotes();
            updateStatus('Note deleted', 'ready');
        }

        function updateNote(id, field, value) {
            const note = notes.find(n => n.id === id);
            if (note) {
                note[field] = value;
                if (field === 'title' || field === 'content') {
                    note.date = new Date().toISOString();
                }
            }
        }

        function renderNotes() {
            if (notes.length === 0) {
                emptyState.style.display = 'block';
                notesContainer.innerHTML = '';
                notesContainer.appendChild(emptyState);
            } else {
                emptyState.style.display = 'none';
                notesContainer.innerHTML = '';
                notes.forEach(note => {
                    const noteCard = createNoteCard(note);
                    notesContainer.appendChild(noteCard);
                });
            }
            updateNoteCount();
        }

        function createNoteCard(note) {
            const card = document.createElement('div');
            card.className = 'note-card';
            const titleEscaped = escapeHtml(note.title);
            const contentEscaped = escapeHtml(note.content);
            const dateFormatted = formatDate(note.date);
            card.innerHTML = \`
                <div class="note-header">
                    <input 
                        type="text" 
                        class="note-title" 
                        value="\${titleEscaped}" 
                        placeholder="Note title..."
                        data-id="\${note.id}"
                        data-field="title"
                    />
                    <span class="note-date">\${dateFormatted}</span>
                    <div class="note-actions">
                        <button onclick="deleteNote(\${note.id})">Delete</button>
                    </div>
                </div>
                <textarea 
                    class="note-content" 
                    placeholder="Write your note here..."
                    data-id="\${note.id}"
                    data-field="content"
                >\${contentEscaped}</textarea>
            \`;
            
            // Add event listeners
            const titleInput = card.querySelector('.note-title');
            const contentInput = card.querySelector('.note-content');
            
            titleInput.addEventListener('input', (e) => {
                updateNote(note.id, 'title', e.target.value);
            });
            
            contentInput.addEventListener('input', (e) => {
                updateNote(note.id, 'content', e.target.value);
            });
            
            return card;
        }

        function saveNotes(silent = false) {
            const data = JSON.stringify(notes, null, 2);
            vscode.postMessage({
                command: 'save',
                content: data
            });
            if (!silent) {
                updateStatus('Saved!', 'ready');
                setTimeout(() => updateStatus('Ready', 'ready'), 2000);
            } else {
                setTimeout(() => updateStatus('Auto-saved', 'ready'), 1000);
                setTimeout(() => updateStatus('Ready', 'ready'), 3000);
            }
        }

        function loadNotes(loadedNotes) {
            if (loadedNotes && Array.isArray(loadedNotes)) {
                notes = loadedNotes;
                if (notes.length > 0) {
                    noteIdCounter = Math.max(...notes.map(n => n.id || 0)) + 1;
                }
                renderNotes();
                updateStatus('Notes loaded', 'ready');
                setTimeout(() => updateStatus('Ready', 'ready'), 2000);
            }
        }

        function clearAllNotes(confirmed = false) {
            if (!confirmed) {
                vscode.postMessage({
                    command: 'alert',
                    text: 'Use the Clear All button in the toolbar to clear all notes'
                });
                return;
            }
            notes = [];
            renderNotes();
            updateStatus('All notes cleared', 'ready');
            saveNotes(true);
        }

        function updateNoteCount() {
            const count = notes.length;
            const plural = count !== 1 ? 's' : '';
            noteCount.textContent = count + ' note' + plural;
        }

        function updateStatus(text, state) {
            statusText.textContent = text;
            statusDot.className = 'status-dot ' + (state === 'saving' ? 'saving' : '');
        }

        function formatDate(dateString) {
            const date = new Date(dateString);
            const now = new Date();
            const diff = now - date;
            const seconds = Math.floor(diff / 1000);
            const minutes = Math.floor(seconds / 60);
            const hours = Math.floor(minutes / 60);
            const days = Math.floor(hours / 24);

            if (seconds < 60) return 'Just now';
            if (minutes < 60) return minutes + 'm ago';
            if (hours < 24) return hours + 'h ago';
            if (days < 7) return days + 'd ago';
            return date.toLocaleDateString();
        }

        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        // Make deleteNote available globally
        window.deleteNote = deleteNote;

        // Initialize on load
        init();
    </script>
</body>
</html>`;
    }
}

export function deactivate() {}

