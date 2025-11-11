# Cursor Browser Quick Reference

##  Status: FULLY WORKING

The Cursor Built-in Browser (MCP Browser Tools) is operational and ready to use.

---

## Quick Tests

### Test 1: External Site
```
Ask AI: "Navigate to https://www.example.com"
```

### Test 2: Localhost (after starting services)
```bash
# Start services
cd docker-compose && docker-compose up -d

# Then test
Ask AI: "Navigate to http://localhost:8080"
```

### Test 3: Screenshot
```
Ask AI: "Take a screenshot of the current page"
```

---

## Common Commands

### Navigation
- `browser_navigate(url)` - Navigate to URL
- `browser_snapshot()` - Get page structure
- `browser_take_screenshot()` - Capture screenshot

### Interaction
- `browser_click(element, ref)` - Click element
- `browser_type(element, ref, text)` - Type text
- `browser_hover(element, ref)` - Hover over element
- `browser_select_option(element, ref, values)` - Select dropdown

### Debugging
- `browser_console_messages()` - Get console logs
- `browser_network_requests()` - View network requests
- `browser_wait_for(text)` - Wait for text to appear

---

## Troubleshooting

### Connection Refused?
```bash
# Start Docker services
cd docker-compose && docker-compose up -d
```

### Authentication Required?
- Username: `pretamane`
- Password: `#ThawZin2k77!`

### Blank Page?
- Check service logs: `docker-compose logs [service]`
- Verify URL is correct
- Check if service is running: `docker-compose ps`

---

## Available Services (when running)

- **Main App:** http://localhost:8080
- **Grafana:** http://localhost:8080/grafana
- **Prometheus:** http://localhost:8080/prometheus
- **pgAdmin:** http://localhost:8080/pgadmin
- **Meilisearch:** http://localhost:8080/meilisearch
- **MinIO:** http://localhost:8080/minio

---

## Diagnostic Tools

```bash
# Run full diagnostic
bash .cursor/browser-diagnostic.sh

# Run Python test
python3 .cursor/browser-test.py
```

---

## Documentation

- **Status Report:** `.cursor/BROWSER_STATUS_REPORT.md`
- **Troubleshooting:** `CURSOR_BROWSER_TROUBLESHOOTING.md`
- **Quick Setup:** `QUICK_BROWSER_SETUP.md`

---

**Last Updated:** Current session  
**Status:**  Operational

