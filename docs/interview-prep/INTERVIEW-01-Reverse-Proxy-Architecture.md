# Interview Guide: Reverse Proxy Architecture (Caddy)

##  Selling Point
"I implemented a centralized edge security layer using Caddy as a reverse proxy, consolidating 8+ services behind a single entry point with path-based routing and unified security policies."

##  The Problem We Solved

**Before**: Multiple services, each wanting their own port:
- FastAPI: 8000
- Grafana: 3000
- Prometheus: 9090
- MinIO Console: 9001
- pgAdmin: 5050
- Meilisearch: 7700

**Issues**:
-  Users must remember 6+ different ports
-  Each port needs firewall rules
-  No unified authentication layer
-  Need separate TLS certificates per port
-  Large attack surface (6 open ports)

**After**: One edge port (8080), path-based routing:
```
http://localhost:8080/          → Static website
http://localhost:8080/api/*     → FastAPI
http://localhost:8080/grafana   → Monitoring
http://localhost:8080/minio     → Object storage
```

##  How Services Connect

```
Internet/User
    ↓

  Caddy Reverse Proxy (:8080)        
  - Security Headers                 
  - Basic Auth                       
  - Path Routing                     

    ↓ ↓ ↓ ↓ ↓ ↓
         → MinIO (9001)
        → Meilisearch (7700)
       → pgAdmin (80)
      → Prometheus (9090)
     → Grafana (3000)
    → FastAPI (8000)
```

**Key Point**: All backend services are NOT exposed externally - only Caddy port 8080 is public.

##  Path Routing Deep Dive

### Simple Routing Example
```nginx
handle /api/* {
    reverse_proxy fastapi-app:8000
}
```

**What happens**:
1. User requests: `GET http://localhost:8080/api/health`
2. Caddy matches: `/api/*` → routes to FastAPI
3. Caddy forwards: `GET http://fastapi-app:8000/api/health`
4. FastAPI receives original path intact

### Subpath Application Problem (MinIO)

**Challenge**: MinIO Console expects to be at root `/`, but we want it at `/minio`

**The Issue**:
- MinIO HTML: `<base href="/">`
- Browser loads: `<link href="./static/css/main.css">`
- Browser requests: `http://localhost:8080/static/css/main.css`  (wrong)
- Should request: `http://localhost:8080/minio/static/css/main.css` 

**Solution - Two Parts**:

**1. Caddy strips prefix**:
```nginx
handle /minio* {
    uri strip_prefix /minio
    reverse_proxy minio:9001
}
```
Request `/minio/static/css/main.css` becomes `/static/css/main.css` to MinIO.

**2. MinIO knows its subpath**:
```yaml
environment:
  - MINIO_BROWSER_REDIRECT_URL=http://localhost:8080/minio
```
MinIO now emits: `<base href="/minio/">` 

**Interview Insight**: "Many web apps assume they're at root. When proxying behind a subpath, you need BOTH proxy path-stripping AND app-level configuration to tell the app its base path."

##  Security Headers Applied Globally

```nginx
header {
    Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    X-Content-Type-Options "nosniff"
    X-Frame-Options "SAMEORIGIN"
    Content-Security-Policy "default-src 'self'; ..."
}
```

**Key Point**: Headers applied ONCE at edge, protect ALL services behind it.

##  Basic Auth on Admin Tools

```nginx
handle /grafana* {
    basic_auth {
        pretamane $2a$14$VBOm...  # bcrypt hash
    }
    reverse_proxy grafana:3000
}
```

**Why Basic Auth?**
-  Simple, no external auth service needed
-  Better than nothing (originally unprotected)
-  Works until we implement OIDC

**Production Upgrade Path**: Replace with OAuth2/OIDC using Authelia or Keycloak.

##  Trade-offs & Alternatives

| Approach | Pros | Cons | When to Use |
|----------|------|------|-------------|
| **Caddy** | Auto-HTTPS, simple config | Smaller community | Modern stacks, rapid dev |
| **Nginx** | Battle-tested, huge ecosystem | Complex syntax | Enterprise with existing expertise |
| **Traefik** | Auto-discovery, Docker/K8s native | Overkill for simple cases | Kubernetes deployments |
| **Envoy** | Advanced L7 features | Steeper learning curve | Service mesh architectures |

**Our Choice**: Caddy for simplicity, security defaults, and auto-HTTPS capability.

##  Real Troubleshooting Story

**Problem**: MinIO Console loaded but CSS/JS returned as HTML (200 OK but wrong content)

**Debugging**:
```bash
curl -I http://localhost:8080/minio/static/css/main.css
# Content-Type: text/html  ← Should be text/css!
```

**Root Cause**: Used `handle_path` which strips path BEFORE matching, so MinIO couldn't find `/static/css/main.css`.

**Fix**: Changed to `handle` + `uri strip_prefix`:
```nginx
handle /minio* {           # Match WITH prefix
    uri strip_prefix /minio  # THEN strip for backend
    reverse_proxy minio:9001
}
```

**Interview Takeaway**: "I debugged by checking response headers and content, identified path-stripping was happening too early, adjusted Caddy directive order, verified assets now return correct Content-Type."

##  Production Improvements

- **TLS**: Enable HTTPS with Let's Encrypt (Caddy does this automatically)
- **Rate Limiting**: Add per-path rate limits to prevent abuse
- **WAF**: Add ModSecurity for application firewall rules
- **Multiple Replicas**: Run 2+ Caddy instances behind load balancer for HA
- **Metrics**: Enable Caddy's Prometheus metrics exporter

##  Interview Talking Points

1. **"Single point of control"**: All security, logging, and monitoring happens at one edge layer.
2. **"Path-based routing reduces complexity"**: Users remember one URL, we manage routing centrally.
3. **"Subpath compatibility requires two-sided config"**: Proxy must strip prefix, app must know its base path.
4. **"Security by default"**: HSTS, CSP, and auth headers applied globally at edge.
5. **"Troubleshooting methodology"**: Check headers first, verify content-type, adjust path handling.
