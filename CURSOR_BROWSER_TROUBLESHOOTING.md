# Cursor Built-in Browser Troubleshooting Guide

## Overview

Cursor has two browser capabilities:
1. **Simple Browser Panel** - Built-in VS Code browser panel (Ctrl+Shift+P → "Simple Browser: Show")
2. **MCP Browser Tools** - Programmatic browser control via Model Context Protocol (used by AI assistant)

This guide covers troubleshooting for both.

---

## MCP Browser Tools (AI Assistant Browser)

### Status:  WORKING

The MCP browser tools are fully functional and can:
- Navigate to URLs
- Take screenshots
- Interact with pages (click, type, hover)
- Read page content and accessibility snapshots
- Capture console messages
- Wait for elements or text

### Testing MCP Browser

**Test 1: External Site**
```bash
# Ask AI: "Navigate to https://www.example.com and take a screenshot"
# Expected: Browser navigates successfully, screenshot captured
```

**Test 2: Local Services**
```bash
# Ask AI: "Navigate to http://localhost:8080"
# Expected: 
#   - If services running: Page loads successfully
#   - If services stopped: Connection refused error (expected)
```

### Common MCP Browser Issues

#### Issue: Connection Refused on localhost
**Cause:** Docker services are not running
**Solution:** 
```bash
cd docker-compose
docker-compose up -d
```

#### Issue: Authentication Required
**Cause:** Service requires Basic Auth
**Solution:** MCP browser can handle Basic Auth, but you may need to provide credentials in the request

#### Issue: Blank Page or Timeout
**Cause:** Service is slow to start or has errors
**Solution:**
```bash
# Check service logs
docker-compose logs fastapi-app
docker-compose logs caddy
```

---

## Simple Browser Panel (VS Code Built-in)

## Issue: Browser Panel Not Loading Properly

### Common Issues & Solutions

## 1. **Browser Panel Shows Blank/White Screen**

### Cause:
- Browser panel might be blocked by security policies
- Content Security Policy (CSP) issues
- JavaScript errors

### Solution:
```bash
# Check if it's a CSP issue
# Try opening a simple HTML file first to test
```

**Steps:**
1. Open Command Palette: `Ctrl+Shift+P`
2. Type: `Simple Browser: Show`
3. Try loading: `https://example.com` (test if browser works at all)
4. If that works, try: `http://localhost:8080`

## 2. **Browser Panel Shows "Connection Refused"**

### Cause:
- No server running on the port
- Port is blocked
- Service not started

### Solution:
- This is expected if your Docker services are stopped
- The browser panel is working correctly - there's just nothing to connect to

## 3. **Browser Panel Shows "Loading..." Forever**

### Cause:
- Browser panel might be stuck
- Network timeout
- Cursor browser extension issue

### Solution:

**Option A: Restart Browser Panel**
1. Close the browser panel
2. Press `Ctrl+Shift+P`
3. Type: `Simple Browser: Show`
4. Enter URL again

**Option B: Clear Browser Cache**
1. Close Cursor completely
2. Restart Cursor
3. Try opening browser panel again

**Option C: Try Different URL**
1. Test with: `https://www.google.com`
2. If that works, the issue is with your local URL
3. If that doesn't work, it's a Cursor browser issue

## 4. **Browser Panel Shows Error Messages**

### Common Errors:

**"Failed to load resource"**
- Server is not running
- Wrong URL
- Port mismatch

**"CORS policy"**
- This shouldn't happen with Simple Browser
- Try a different URL format

**"ERR_CONNECTION_REFUSED"**
- Server is not running (expected if Docker is down)
- Port is not open
- Firewall blocking

## 5. **Browser Panel Not Docking to Bottom**

### Solution:
1. Click and drag the browser tab
2. Drag to the bottom panel area
3. Look for blue docking indicator
4. Release to dock

**Alternative:**
- Right-click browser tab
- Select "Move Panel to Bottom"
- Or use View menu → Appearance → Panel

## 6. **Browser Panel Not Opening at All**

### Cause:
- Cursor version doesn't support browser
- Extension not installed
- Browser feature disabled

### Solution:

**Check Cursor Version:**
- Go to Help → About
- Make sure you have a recent version
- Browser panel is available in Cursor 0.30+

**Try Alternative:**
- Use Browser Preview extension
- Install from Extensions panel
- Search: "Browser Preview"

## 7. **Browser Panel Shows Wrong Content**

### Cause:
- Cached content
- Wrong URL
- Redirect issues

### Solution:
1. Hard refresh: `Ctrl+Shift+R` (in browser panel)
2. Clear cache: Close and reopen browser panel
3. Verify URL is correct

## Testing Steps

### Step 1: Test Browser Panel with External Site
```
1. Press Ctrl+Shift+P
2. Type: Simple Browser: Show
3. Enter: https://www.google.com
4. Does it load? → Browser panel works
5. Does it not load? → Browser panel issue
```

### Step 2: Test Browser Panel with Local Server
```
1. Start your Docker services (if needed)
2. Press Ctrl+Shift+P
3. Type: Simple Browser: Show
4. Enter: http://localhost:8080
5. Does it load? → Everything works
6. Does it not load? → Check if services are running
```

### Step 3: Check Services Status
```bash
# Check if services are running
cd docker-compose
docker-compose ps

# If not running, start them
docker-compose up -d

# Check if port is accessible
curl http://localhost:8080
```

## Alternative Solutions

### Option 1: Use Browser Preview Extension
```
1. Install "Browser Preview" extension
2. Open Command Palette
3. Type: Browser Preview: Open Preview
4. Enter URL
```

### Option 2: Use External Browser
```
1. Open external browser (Chrome, Firefox)
2. Navigate to http://localhost:8080
3. Keep it open in separate window
```

### Option 3: Use Terminal Browser (lynx/links)
```bash
# Install text browser
sudo apt install lynx

# Open in terminal
lynx http://localhost:8080
```

## Quick Diagnostic Commands

```bash
# Check if port is open
netstat -tuln | grep 8080
# or
ss -tuln | grep 8080

# Check if services are running
docker ps

# Test connection
curl -I http://localhost:8080

# Check Cursor version
cursor --version
```

## Expected Behavior

### When Services are Running:
- Browser panel should load: `http://localhost:8080`
- Should show your portfolio website
- Should be able to navigate pages

### When Services are Stopped:
- Browser panel should show: "Connection Refused"
- This is NORMAL and EXPECTED
- Browser panel is working correctly

## Still Having Issues?

1. **Check Cursor Logs:**
   - Help → Toggle Developer Tools
   - Check Console for errors

2. **Try Different Browser:**
   - Use Browser Preview extension
   - Use external browser

3. **Report Issue:**
   - Cursor Forum: https://forum.cursor.com
   - GitHub Issues: https://github.com/getcursor/cursor/issues

## Summary

**The browser panel not loading is likely because:**
1.  Your Docker services are stopped (intentionally)
2.  Browser panel is working correctly
3.  It's trying to connect to localhost:8080 but nothing is there

**To test the browser panel:**
1. Start Docker services: `cd docker-compose && docker-compose up -d`
2. Open browser panel: `Ctrl+Shift+P` → `Simple Browser: Show`
3. Enter URL: `http://localhost:8080`
4. Should load your website

**If browser panel still doesn't work:**
- Try external site: `https://www.google.com`
- If that works → Browser panel is fine, issue is with local server
- If that doesn't work → Browser panel issue, try Browser Preview extension

