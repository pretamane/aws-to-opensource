# Cloudflare Tunnel - Complete Access Guide

**Date:** October 23, 2025  
**Tunnel URL:** `https://happen-dependent-romance-dentists.trycloudflare.com`  
**Status:**  All Services Accessible

---

## Your Public Cloudflare Tunnel URL

```
https://happen-dependent-romance-dentists.trycloudflare.com
```

** This URL changes** every time `cloudflared` restarts. To get the current URL:
```bash
docker logs cloudflared | grep trycloudflare.com
```

---

## Public Endpoints (No Authentication Required)

| Endpoint | URL | Description |
|----------|-----|-------------|
| **Portfolio Website** | https://happen-dependent-romance-dentists.trycloudflare.com/ | Your main portfolio site |
| **API Documentation** | https://happen-dependent-romance-dentists.trycloudflare.com/docs | Interactive API docs (Swagger UI) |
| **API Root** | https://happen-dependent-romance-dentists.trycloudflare.com/api/ | REST API endpoints |
| **Health Check** | https://happen-dependent-romance-dentists.trycloudflare.com/health | Service health status |
| **Metrics** | https://happen-dependent-romance-dentists.trycloudflare.com/metrics | Prometheus metrics |
| **Stats** | https://happen-dependent-romance-dentists.trycloudflare.com/stats | Visitor statistics |

---

## Admin Endpoints (Basic Auth Required)

**Credentials:**
- **Username:** `pretamane`
- **Password:** `#ThawZin2k77!`

| Service | URL | Status | Description |
|---------|-----|--------|-------------|
| **Grafana** | https://happen-dependent-romance-dentists.trycloudflare.com/grafana |  200 | Monitoring dashboards |
| **Prometheus** | https://happen-dependent-romance-dentists.trycloudflare.com/prometheus |  302 | Metrics & alerts |
| **pgAdmin** | https://happen-dependent-romance-dentists.trycloudflare.com/pgadmin |  302 | PostgreSQL admin |
| **Meilisearch** | https://happen-dependent-romance-dentists.trycloudflare.com/meilisearch |  200 | Search admin UI |
| **Alertmanager** | https://happen-dependent-romance-dentists.trycloudflare.com/alertmanager |  200 | Alert management |
| **MinIO Console** | https://happen-dependent-romance-dentists.trycloudflare.com/minio |  200 | Object storage admin |
| **Loki API** | https://happen-dependent-romance-dentists.trycloudflare.com/loki |  404* | Log aggregation API |

*Loki 404 is expected (no web UI, access via Grafana)

---

## How to Access Protected Services

### Method 1: Browser (Recommended)
1. Navigate to any protected URL
2. Browser will prompt for credentials
3. Enter:
   - Username: `pretamane`
   - Password: `#ThawZin2k77!`
4. Browser will save credentials for the session

### Method 2: curl (Testing)
```bash
curl -u pretamane:'#ThawZin2k77!' https://happen-dependent-romance-dentists.trycloudflare.com/grafana/
```

### Method 3: Postman/API Client
1. Use "Basic Auth" authentication type
2. Username: `pretamane`
3. Password: `#ThawZin2k77!`

---

## Service-Specific Access Instructions

### Grafana Dashboards
```
URL: https://happen-dependent-romance-dentists.trycloudflare.com/grafana/
Auth: Basic Auth (pretamane / #ThawZin2k77!)
Then: Grafana login (admin / check .env for GF_SECURITY_ADMIN_PASSWORD)
```

### Prometheus
```
URL: https://happen-dependent-romance-dentists.trycloudflare.com/prometheus/
Auth: Basic Auth (pretamane / #ThawZin2k77!)
```
- Targets: `/prometheus/targets`
- Alerts: `/prometheus/alerts`
- Graph: `/prometheus/graph`

### pgAdmin
```
URL: https://happen-dependent-romance-dentists.trycloudflare.com/pgadmin/
Auth: Basic Auth (pretamane / #ThawZin2k77!)
Then: pgAdmin login (check docker-compose.yml for PGADMIN_DEFAULT_EMAIL/PASSWORD)
```

### Meilisearch
```
URL: https://happen-dependent-romance-dentists.trycloudflare.com/meilisearch/
Auth: Basic Auth (pretamane / #ThawZin2k77!)
```

### Alertmanager
```
URL: https://happen-dependent-romance-dentists.trycloudflare.com/alertmanager/
Auth: Basic Auth (pretamane / #ThawZin2k77!)
```

### MinIO Console
```
URL: https://happen-dependent-romance-dentists.trycloudflare.com/minio/
Auth: Basic Auth (pretamane / #ThawZin2k77!)
Then: MinIO login (check docker-compose.yml for MINIO_ROOT_USER/PASSWORD)
```

---

## Security Status

### What's Protected 
-  **EC2 IP Hidden** - Direct access to `54.179.230.219` ports 80/443 blocked
-  **Basic Auth** - All admin tools require authentication
-  **HTTPS** - Cloudflare provides TLS encryption
-  **Security Headers** - HSTS, CSP, X-Frame-Options, etc.
-  **DDoS Protection** - Cloudflare edge network
-  **CrowdSec** - Auto-banning malicious IPs on origin
-  **fail2ban** - SSH brute-force protection

### Recent Fixes 
-  Fixed CSP header to allow CDN resources (Font Awesome, etc.)
-  Added MinIO Console route (`/minio`)
-  Added Loki API route (`/loki`)
-  Corrected Basic Auth password hash
-  All admin services now accessible via tunnel

---

## Testing Checklist

- [x] Portfolio website loads correctly
- [x] API documentation accessible
- [x] Grafana dashboard accessible with auth
- [x] Prometheus accessible with auth
- [x] pgAdmin accessible with auth
- [x] Meilisearch accessible with auth
- [x] Alertmanager accessible with auth
- [x] MinIO console accessible with auth
- [x] Loki API responds (404 expected)
- [x] Direct EC2 IP blocked (ports 80/443 closed)
- [x] Basic Auth protecting all admin endpoints

---

## Troubleshooting

### Can't Access Service?

**1. Check Cloudflare Tunnel is running:**
```bash
docker ps | grep cloudflared
docker logs cloudflared
```

**2. Get current tunnel URL:**
```bash
docker logs cloudflared | grep trycloudflare.com
```

**3. Test service locally (on EC2):**
```bash
# Test Grafana
curl -I http://localhost:3000

# Test Prometheus
curl -I http://localhost:9090

# Test MinIO Console
curl -I http://localhost:9001
```

**4. Test Caddy routing:**
```bash
# Without auth (should return 401)
curl -I https://YOUR-TUNNEL-URL/grafana

# With auth (should return 200 or 302)
curl -I -u pretamane:'#ThawZin2k77!' https://YOUR-TUNNEL-URL/grafana
```

### Tunnel URL Changed?

This is normal! Quick Tunnel URLs rotate on restart. To update:
```bash
# Get new URL
NEW_URL=$(docker logs cloudflared | grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' | tail -1)
echo "New URL: $NEW_URL"

# Update bookmarks
```

### Wrong Password Hash?

Regenerate password hash:
```bash
docker run --rm caddy:2-alpine caddy hash-password --plaintext '#ThawZin2k77!'
```

Then update `Caddyfile` and restart Caddy:
```bash
docker-compose restart caddy
```

---

## Quick Commands

### Get Tunnel URL
```bash
docker logs cloudflared | grep trycloudflare.com
```

### Restart Tunnel (Get New URL)
```bash
docker-compose restart cloudflared
sleep 5
docker logs cloudflared | grep trycloudflare.com
```

### Restart Caddy (After Config Change)
```bash
docker-compose restart caddy
```

### Check Service Status
```bash
docker-compose ps
```

### View Logs
```bash
# Cloudflare Tunnel
docker logs cloudflared

# Caddy
docker logs caddy

# Specific service
docker logs <service-name>
```

---

## What's Next?

### Phase 2 Upgrade (When Ready)
Get a domain (free or $0.99/year) and upgrade to:
-  **Permanent URL** (your-domain.com)
-  **Cloudflare WAF** - Advanced firewall
-  **Geo-blocking** - Block countries at edge
-  **Rate limiting** - Better DDoS protection
-  **Cloudflare Access** - Zero-trust SSO (replace Basic Auth)
-  **Analytics** - Full Cloudflare dashboard

Still $0 additional cost!

---

## Files Modified

1. `docker-compose/config/caddy/Caddyfile`
   - Fixed CSP header (allow CDN resources)
   - Added MinIO Console route
   - Added Loki API route
   - Corrected Basic Auth password hash

2. `upload-caddy.sh` (created)
   - Quick Caddyfile upload script via SSM

---

## Summary

 **All Services Working**
- 6 admin tools accessible via Cloudflare Tunnel
- Basic Auth protecting all admin endpoints
- EC2 IP completely hidden
- HTTPS encryption via Cloudflare
- Security headers active

**Your Tunnel URL:**
```
https://happen-dependent-romance-dentists.trycloudflare.com
```

**Admin Credentials:**
- Username: `pretamane`
- Password: `#ThawZin2k77!`

---

**Status:**  Complete  
**Last Updated:** October 23, 2025  
**Version:** 1.1.0

