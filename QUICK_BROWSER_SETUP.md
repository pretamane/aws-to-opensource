# Quick Browser Panel Setup in Cursor

##  Fastest Way to Open Browser in Bottom Panel

### Method 1: Simple Browser (Built-in) ⭐ RECOMMENDED

1. **Press:** `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)

2. **Type:** `Simple Browser: Show`

3. **Enter URL:** `http://localhost:8080`

4. **Dock to Bottom:**
   - Click the browser tab
   - Drag it DOWN to the bottom panel area
   - Release to dock it

### Method 2: Browser Preview Extension

1. **Install Extension:**
   - Press `Ctrl+Shift+X` to open Extensions
   - Search: `Browser Preview`
   - Install: "Browser Preview" by Auchenberg

2. **Open Preview:**
   - Press `Ctrl+Shift+P`
   - Type: `Browser Preview: Open Preview`
   - Enter: `http://localhost:8080`

3. **Dock to Bottom:**
   - Right-click the preview tab
   - Select "Move Panel to Bottom" or drag it down

### Method 3: Keyboard Shortcut (Custom)

1. **Set Up Shortcut:**
   - Press `Ctrl+K Ctrl+S` (Keyboard Shortcuts)
   - Search: `simple browser`
   - Click the "+" to add shortcut
   - Press your preferred keys (e.g., `Ctrl+Shift+B`)

2. **Use Shortcut:**
   - Press your custom shortcut
   - Enter URL: `http://localhost:8080`

##  Dock to Bottom Panel

**To move browser to bottom panel:**

1. **Click and hold** the browser tab
2. **Drag** it toward the **bottom** of the window
3. **Look for** the blue docking indicator
4. **Release** when you see the bottom panel highlight

**Alternative:**
- Right-click the tab → "Move Panel to Bottom"
- Or use View → Appearance → Move Panel to Bottom

##  Quick Access URLs

- **Main App:** http://localhost:8080
- **API Docs:** http://localhost:8080/docs
- **Grafana:** http://localhost:8080/grafana
- **Prometheus:** http://localhost:8080/prometheus

##  Troubleshooting

**Browser won't dock?**
- Try restarting Cursor
- Check if bottom panel is enabled (View → Appearance → Panel)

**Localhost won't load?**
- Check if Docker Compose is running: `cd docker-compose && docker-compose ps`
- Start services: `docker-compose up -d`

**Extension won't install?**
- Check Cursor's extension compatibility
- Try the built-in Simple Browser instead

##  Pro Tips

1. **Keep Browser Open:** The browser will stay in the bottom panel even when you switch tabs
2. **Multiple URLs:** You can open multiple browser tabs and dock them
3. **Auto-reload:** Some extensions support auto-reload on file changes
4. **DevTools:** Right-click in browser → "Inspect" to open DevTools

---

**Need Help?** Check `.cursor/browser-preview.md` for detailed instructions.

