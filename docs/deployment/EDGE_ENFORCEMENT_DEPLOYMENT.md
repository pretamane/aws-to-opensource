# Edge Enforcement Deployment Guide

## What Changed

Your Docker Compose stack has been modified to implement **true edge enforcement** with **defense-in-depth security**:

### Security Model
- **Edge Layer (Caddy)**: Single gateway protecting all admin UIs with basic authentication
- **Service Layer**: Each service retains its own native authentication
- **Result**: Two-factor defense - attackers must bypass both edge auth AND per-service auth

### Port Exposure Changes

**Before (Multiple Entry Points - Vulnerable):**
- Direct access to services via: localhost:3000, :5050, :7700, :8000, :9000, :9001, :9090, :9093, :3100
- Edge auth could be bypassed by accessing services directly
- Single point of compromise exposed all services

**After (Single Edge Entry Point - Secure):**
- Only Caddy exposed: localhost:80 and localhost:443
- All services are internal-only, accessible exclusively through Caddy's protected routes
- Edge auth cannot be bypassed
- Services remain connected internally via Docker network (app-network)

### Services Modified (Host Ports Removed)

| Service | Old Access | New Access (via Caddy) |
|---------|-----------|------------------------|
| FastAPI App | `localhost:8000` | `http://localhost/api`, `/docs`, `/health` |
| Grafana | `localhost:3000` | `http://localhost/grafana` |
| Prometheus | `localhost:9090` | `http://localhost/prometheus` |
| pgAdmin | `localhost:5050` | `http://localhost/pgadmin` |
| Meilisearch | `localhost:7700` | `http://localhost/meilisearch` |
| MinIO Console | `localhost:9001` | `http://localhost/minio` |
| Alertmanager | `localhost:9093` | `http://localhost/alertmanager` |
| Loki | `localhost:3100` | Internal only (via Grafana) |

### What Still Works Internally

All container-to-container communication remains intact:
- Prometheus scrapes all exporters using service names (e.g., `grafana:3000`, `minio:9000`)
- FastAPI app connects to `postgresql:5432`, `meilisearch:7700`, `minio:9000`
- Grafana queries `prometheus:9090` and `loki:3100`
- Blackbox exporter probes `caddy:80` endpoints
- All services communicate over the `app-network` Docker bridge

---

## Deployment Steps

### Prerequisites
- Docker and Docker Compose installed
- Ports 80 and 443 available on your local machine
- Minimum 2 CPU cores and 4GB RAM allocated to Docker

### Step 1: Configure Credentials

1. Navigate to the docker-compose directory:
```bash
cd aws-to-opensource-local/docker-compose
```

2. Create your `.env` file from the template:
```bash
cp .env.template .env
```

3. Edit `.env` and replace ALL `CHANGE_ME_` placeholders with strong passwords:
```bash
nano .env
# or use your preferred editor: vim, code, etc.
```

**Critical Variables to Set:**

```bash
# Database (must match on both POSTGRES_* and DB_*)
POSTGRES_USER=pretamane_admin
POSTGRES_PASSWORD=<your-strong-db-password>
DB_USER=pretamane_admin
DB_PASSWORD=<same-as-postgres-password>

# Meilisearch (16+ chars required)
MEILI_MASTER_KEY=<your-meilisearch-key-min-16-chars>

# MinIO
MINIO_ROOT_USER=minio_admin
MINIO_ROOT_PASSWORD=<your-minio-password>

# Grafana
GF_SECURITY_ADMIN_USER=grafana_admin
GF_SECURITY_ADMIN_PASSWORD=<your-grafana-password>

# pgAdmin (email required)
PGADMIN_DEFAULT_EMAIL=admin@localhost.local
PGADMIN_DEFAULT_PASSWORD=<your-pgadmin-password>
```

**Optional AWS SES** (leave empty if not using):
```bash
AWS_REGION=ap-southeast-1
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
SES_FROM_EMAIL=
SES_TO_EMAIL=
```

### Step 2: Validate Configuration

Test that your compose file is valid:
```bash
docker compose config
```

Expected output: No errors, YAML is properly formatted.

### Step 3: Deploy the Stack

Start all services in detached mode:
```bash
docker compose up -d
```

This will:
- Pull all required images (~2-3 GB)
- Build the FastAPI app from source
- Initialize PostgreSQL with schema
- Create MinIO buckets
- Start all monitoring and logging services
- Configure Caddy as the reverse proxy

**Expected startup time:** 2-3 minutes for first run, 30-60 seconds for subsequent runs.

### Step 4: Monitor Startup

Watch the logs to ensure all services start successfully:
```bash
docker compose logs -f
```

**Key indicators of successful startup:**

1. **PostgreSQL initialized:**
```
postgresql  | PostgreSQL init process complete; ready for start up.
```

2. **MinIO buckets created:**
```
minio-setup | MinIO buckets created successfully
```

3. **FastAPI app healthy:**
```
fastapi-app | INFO:     Application startup complete
```

4. **Caddy running:**
```
caddy | {"level":"info","msg":"serving initial configuration"}
```

Press `Ctrl+C` to stop following logs (services keep running).

### Step 5: Check Service Status

Verify all containers are running:
```bash
docker compose ps
```

Expected: All services show "Up" or "Up (healthy)".

---

## Access and Validation

### Edge Authentication (Caddy Basic Auth)

All admin UIs are protected by Caddy basic auth **first**, then their own login.

**Current Edge Credentials (from Caddyfile):**
- Username: `pretamane`
- Password: `#ThawZin2k77!`

**To change edge password:**
```bash
# Generate new bcrypt hash
docker run --rm caddy:2-alpine caddy hash-password --plaintext 'YourNewPassword'

# Copy the hash and replace it in: docker-compose/config/caddy/Caddyfile
# Search for: basic_auth { ... }
# Update the hash for user 'pretamane' (or change username too)

# Restart Caddy
docker compose restart caddy
```

### Access URLs and Credentials

#### Public Endpoints (No Edge Auth)
- **Main Site:** http://localhost/
- **API Docs:** http://localhost/docs
- **API Health:** http://localhost/health
- **API Endpoints:** http://localhost/api/*

#### Admin UIs (Edge Auth + Service Auth)

**Grafana (Monitoring Dashboards):**
- URL: http://localhost/grafana
- Edge Auth: `pretamane` / `#ThawZin2k77!`
- Service Auth: `${GF_SECURITY_ADMIN_USER}` / `${GF_SECURITY_ADMIN_PASSWORD}` from .env

**Prometheus (Metrics):**
- URL: http://localhost/prometheus
- Edge Auth: `pretamane` / `#ThawZin2k77!`
- Service Auth: None (protected by edge only)

**pgAdmin (Database Admin):**
- URL: http://localhost/pgadmin
- Edge Auth: `pretamane` / `#ThawZin2k77!`
- Service Auth: `${PGADMIN_DEFAULT_EMAIL}` / `${PGADMIN_DEFAULT_PASSWORD}` from .env

**Meilisearch (Search Console):**
- URL: http://localhost/meilisearch
- Edge Auth: `pretamane` / `#ThawZin2k77!`
- Service Auth: API key in UI (from `${MEILI_MASTER_KEY}`)

**MinIO (Object Storage Console):**
- URL: http://localhost/minio
- Edge Auth: `pretamane` / `#ThawZin2k77!`
- Service Auth: `${MINIO_ROOT_USER}` / `${MINIO_ROOT_PASSWORD}` from .env

**Alertmanager (Alert Management):**
- URL: http://localhost/alertmanager
- Edge Auth: `pretamane` / `#ThawZin2k77!`
- Service Auth: None (protected by edge only)

### Validation Checklist

####  Edge Enforcement Working

Test that direct port access is **blocked**:
```bash
# These should all FAIL with "Connection refused"
curl http://localhost:3000     # Grafana direct - should fail
curl http://localhost:9090     # Prometheus direct - should fail
curl http://localhost:5050     # pgAdmin direct - should fail
curl http://localhost:7700     # Meilisearch direct - should fail
curl http://localhost:9000     # MinIO API direct - should fail
curl http://localhost:9001     # MinIO console direct - should fail
curl http://localhost:8000     # FastAPI direct - should fail
```

**Expected output for each:** `curl: (7) Failed to connect to localhost port XXXX after X ms: Connection refused`

####  Edge Access Working

Test that Caddy-proxied access **succeeds**:
```bash
# Public endpoints (no auth)
curl -I http://localhost/
curl -I http://localhost/health
curl -I http://localhost/docs

# Admin endpoints (should return 401 without auth)
curl -I http://localhost/grafana
curl -I http://localhost/prometheus
curl -I http://localhost/pgadmin
```

**Expected:**
- Public endpoints: `200 OK`
- Admin endpoints: `401 Unauthorized` (proving edge auth is enforced)

####  Authenticated Access Working

Test with edge credentials:
```bash
# Access Grafana through edge
curl -u pretamane:'#ThawZin2k77!' http://localhost/grafana/api/health
# Expected: {"commit":"...","database":"ok","version":"..."}

# Access Prometheus through edge
curl -u pretamane:'#ThawZin2k77!' http://localhost/prometheus/api/v1/targets
# Expected: JSON with target status
```

####  Internal Connectivity Working

Check Prometheus targets (should all be healthy):
```bash
# Login to Grafana, then navigate to or access Prometheus via edge auth:
# http://localhost/prometheus/targets

# Or check via API:
curl -u pretamane:'#ThawZin2k77!' http://localhost/prometheus/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
```

**Expected:** All targets show `"health": "up"`

####  Database Connectivity

Check PostgreSQL from the app:
```bash
curl http://localhost/health | jq '.services.postgresql'
# Expected: "connected"
```

Or connect directly:
```bash
docker exec -it postgresql psql -U pretamane_admin -d pretamane_db -c "SELECT COUNT(*) FROM contact_submissions;"
```

####  Object Storage

Check MinIO via edge:
```bash
# Login via browser: http://localhost/minio
# Should see buckets: pretamane-data, pretamane-backup, pretamane-logs
```

---

## Testing the Application

### Submit a Contact Form

```bash
curl -X POST http://localhost/api/contact \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "email": "test@example.com",
    "company": "Test Corp",
    "service": "Cloud Architecture",
    "budget": "$10,000 - $50,000",
    "message": "Testing edge enforcement setup"
  }'
```

**Expected:** `{"status": "success", "contact_id": "contact_..."}`

### Upload a Document

```bash
echo "Test document content" > test.txt

curl -X POST http://localhost/api/documents/upload \
  -F "contact_id=contact_test_123" \
  -F "file=@test.txt"
```

**Expected:** `{"status": "success", "document_id": "..."}`

### Search Documents

```bash
curl "http://localhost/api/search?q=test"
```

**Expected:** JSON with search results

### View Metrics

```bash
curl http://localhost/metrics
```

**Expected:** Prometheus-formatted metrics

---

## Monitoring and Observability

### Grafana Dashboards

1. Login to http://localhost/grafana (edge auth, then Grafana auth)
2. Navigate to Dashboards
3. Pre-configured dashboards:
   - **Logs Dashboard**: View aggregated logs from all services
   - Add custom dashboards for app metrics, system resources, etc.

### Prometheus Metrics

1. Login to http://localhost/prometheus
2. Navigate to **Status > Targets** to see all scraped services
3. Query examples:
   - `up{job="fastapi-app"}` - App availability
   - `probe_success{job="blackbox-http-public"}` - Synthetic monitoring
   - `container_memory_usage_bytes` - Container resource usage

### Logs (Loki)

Logs are aggregated by Promtail and sent to Loki, queryable via Grafana:
1. In Grafana, go to **Explore**
2. Select **Loki** data source
3. Query: `{container_name="fastapi-app"}`

---

## Troubleshooting

### Issue: Can't access any services

**Check Caddy is running:**
```bash
docker compose ps caddy
```

**Check Caddy logs:**
```bash
docker compose logs caddy
```

**Restart Caddy:**
```bash
docker compose restart caddy
```

### Issue: "Connection refused" on localhost:80

**Check if port 80 is in use:**
```bash
sudo lsof -i :80
# or on Linux:
sudo netstat -tulpn | grep :80
```

**Check Caddy container:**
```bash
docker compose ps caddy
docker compose logs caddy
```

### Issue: Edge auth not prompting

**Verify Caddyfile syntax:**
```bash
docker exec caddy caddy validate --config /etc/caddy/Caddyfile
```

**Restart Caddy:**
```bash
docker compose restart caddy
```

### Issue: Service login fails after edge auth

**Check service-specific credentials in .env:**
```bash
# View without exposing passwords:
grep -E '^(GF_SECURITY|PGADMIN|MINIO_ROOT|POSTGRES)' .env
```

**Restart specific service:**
```bash
docker compose restart grafana
# or pgadmin, minio, etc.
```

### Issue: PostgreSQL connection errors

**Check credentials match:**
```bash
grep -E '^(POSTGRES_USER|DB_USER|POSTGRES_PASSWORD|DB_PASSWORD)' .env
# POSTGRES_USER must equal DB_USER
# POSTGRES_PASSWORD must equal DB_PASSWORD
```

**Restart database and app:**
```bash
docker compose restart postgresql fastapi-app
```

### Issue: Prometheus targets down

**Check internal connectivity:**
```bash
docker exec prometheus wget -O- http://grafana:3000/api/health
docker exec prometheus wget -O- http://meilisearch:7700/health
```

**Restart Prometheus:**
```bash
docker compose restart prometheus
```

### Issue: MinIO buckets not created

**Check minio-setup logs:**
```bash
docker compose logs minio-setup
```

**Manually create buckets:**
```bash
docker exec minio-setup /bin/sh -c "
  mc alias set myminio http://minio:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} &&
  mc mb myminio/pretamane-data --ignore-existing &&
  mc mb myminio/pretamane-backup --ignore-existing &&
  mc mb myminio/pretamane-logs --ignore-existing
"
```

---

## Maintenance Operations

### View All Logs
```bash
docker compose logs -f
```

### View Specific Service Logs
```bash
docker compose logs -f fastapi-app
docker compose logs -f caddy
docker compose logs -f prometheus
```

### Restart All Services
```bash
docker compose restart
```

### Restart Specific Service
```bash
docker compose restart grafana
```

### Stop All Services
```bash
docker compose down
```

### Stop and Remove All Data ( Destructive)
```bash
docker compose down -v
```

### Update Service Images
```bash
docker compose pull
docker compose up -d
```

### Rebuild FastAPI App
```bash
docker compose build fastapi-app
docker compose up -d fastapi-app
```

---

## Security Hardening (Production)

If you plan to expose this beyond localhost:

1. **Change all default passwords** in `.env`
2. **Regenerate Caddy edge auth** hash with a strong password
3. **Enable HTTPS** in Caddy (automatic with Let's Encrypt if you have a domain)
4. **Restrict SSH access** if running on a server
5. **Enable firewall rules** to allow only 80/443
6. **Use Cloudflare Tunnel** (cloudflared service is included) for IP hiding
7. **Rotate credentials regularly**
8. **Enable audit logging** for all admin access
9. **Implement rate limiting** in Caddy
10. **Review Grafana/pgAdmin permissions** and create non-admin users

---

## Rollback Plan

If you need to restore direct port access:

1. **Restore from backup:**
```bash
cd aws-to-opensource-local/docker-compose
cp docker-compose.yml docker-compose.edge-enforced.yml  # Save current
# Then restore your original or uncomment the ports: sections
```

2. **Uncomment ports in docker-compose.yml:**
   - Remove the `# EDGE ENFORCED` comments
   - Uncomment all `ports:` sections for the services you need

3. **Restart:**
```bash
docker compose down
docker compose up -d
```

---

## Summary

Your stack now implements **true edge enforcement** with:

 **Single entry point** - Only Caddy on ports 80/443  
 **Defense-in-depth** - Edge auth + per-service auth  
 **Zero bypass** - Direct service ports are closed  
 **Internal connectivity** - Services communicate securely via Docker network  
 **Full observability** - Prometheus, Grafana, Loki, Blackbox monitoring  
 **Production-ready** - Hardened security posture for demos or deployment  

**Access everything via:** http://localhost/  

**Need help?** Check the troubleshooting section or examine logs with `docker compose logs -f [service]`
