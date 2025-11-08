# Quick Start Guide - Edge Enforcement Deployment

## Overview

This is a fully containerized, production-ready stack with **edge enforcement** security model:
- **15+ services** orchestrated via Docker Compose
- **Single entry point** (Caddy reverse proxy on port 80/443)
- **Two-factor auth**: Edge authentication + per-service authentication
- **Full observability**: Prometheus, Grafana, Loki, Blackbox monitoring

## What You Get

- **FastAPI Application** with PostgreSQL, Meilisearch, MinIO
- **Monitoring Stack**: Prometheus + Grafana + Alertmanager
- **Logging Stack**: Loki + Promtail
- **Admin Tools**: pgAdmin, Meilisearch console, MinIO console
- **Security**: All admin UIs protected by Caddy basic auth + native auth

## Prerequisites

- Docker and Docker Compose installed
- Ports 80 and 443 available
- Minimum 2 CPU cores, 4GB RAM for Docker

## Quick Deploy (5 Steps)

### Step 1: Configure Credentials

```bash
cd aws-to-opensource-local/docker-compose
cp .env.template .env
nano .env  # or vim, code, etc.
```

**Replace all `CHANGE_ME_` placeholders** with strong passwords:
- `POSTGRES_PASSWORD` (must match `DB_PASSWORD`)
- `MEILI_MASTER_KEY` (16+ characters)
- `MINIO_ROOT_PASSWORD`
- `GF_SECURITY_ADMIN_PASSWORD`
- `PGADMIN_DEFAULT_PASSWORD`

### Step 2: Validate Configuration

```bash
docker compose config
```

Should complete without errors.

### Step 3: Deploy

```bash
docker compose up -d
```

Wait 2-3 minutes for first-time initialization.

### Step 4: Verify

```bash
docker compose ps
```

All services should show "Up" or "Up (healthy)".

### Step 5: Test Access

**Public API (no auth):**
```bash
curl http://localhost/health
```

**Admin UI (edge auth required):**
```bash
curl http://localhost/grafana
# Should return 401 Unauthorized (proving edge auth works)
```

## Access URLs

### Public Endpoints (No Authentication)
- Main site: http://localhost/
- API docs: http://localhost/docs
- API health: http://localhost/health

### Admin UIs (Edge Auth + Service Auth Required)

**First gate (Edge Auth - Caddy basic auth):**
- Username: `pretamane`
- Password: `#ThawZin2k77!`

**Second gate (Service Auth - from your .env):**
- Grafana: http://localhost/grafana → Login with `GF_SECURITY_ADMIN_USER` / `GF_SECURITY_ADMIN_PASSWORD`
- Prometheus: http://localhost/prometheus → Protected by edge auth only
- pgAdmin: http://localhost/pgadmin → Login with `PGADMIN_DEFAULT_EMAIL` / `PGADMIN_DEFAULT_PASSWORD`
- Meilisearch: http://localhost/meilisearch → API key from `MEILI_MASTER_KEY`
- MinIO: http://localhost/minio → Login with `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD`
- Alertmanager: http://localhost/alertmanager → Protected by edge auth only

## Automated Deployment

Use the included script for guided deployment:

```bash
cd aws-to-opensource-local
./deploy-edge-enforcement.sh
```

This script will:
- Check prerequisites
- Guide you through .env setup
- Validate configuration
- Deploy the stack
- Verify edge enforcement

## Validation Checklist

 **Edge enforcement working:**
```bash
# These should FAIL (connection refused):
curl http://localhost:3000   # Grafana direct
curl http://localhost:9090   # Prometheus direct
curl http://localhost:8000   # FastAPI direct
```

 **Caddy routing working:**
```bash
# These should SUCCEED:
curl http://localhost/health                              # 200 OK
curl http://localhost/grafana                             # 401 Unauthorized
curl -u pretamane:'#ThawZin2k77!' http://localhost/grafana  # 200 OK
```

 **Internal connectivity working:**
- Visit http://localhost/prometheus/targets
- All targets should show "UP"

## Common Commands

```bash
# View all logs
docker compose logs -f

# View specific service logs
docker compose logs -f fastapi-app
docker compose logs -f caddy

# Restart all services
docker compose restart

# Restart specific service
docker compose restart grafana

# Stop all services
docker compose down

# Stop and remove data ( destructive)
docker compose down -v
```

## Testing the Application

### Submit a contact form:
```bash
curl -X POST http://localhost/api/contact \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "email": "test@example.com",
    "message": "Testing the system"
  }'
```

### Upload a document:
```bash
echo "Test content" > test.txt
curl -X POST http://localhost/api/documents/upload \
  -F "contact_id=test_123" \
  -F "file=@test.txt"
```

### Search documents:
```bash
curl "http://localhost/api/search?q=test"
```

## Troubleshooting

### Services won't start
```bash
docker compose logs [service-name]
docker compose ps
```

### Port 80 in use
```bash
sudo lsof -i :80
# Stop the conflicting service or change Caddy port
```

### Can't access via Caddy
```bash
docker compose restart caddy
docker compose logs caddy
```

### Database connection errors
Check that `POSTGRES_PASSWORD` equals `DB_PASSWORD` in `.env`:
```bash
grep -E '^(POSTGRES_PASSWORD|DB_PASSWORD)' .env
```

## Security Notes

### Current Edge Credentials
- Username: `pretamane`
- Password: `#ThawZin2k77!`
- Location: `docker-compose/config/caddy/Caddyfile`

### To Change Edge Password:
```bash
# Generate new hash
docker run --rm caddy:2-alpine caddy hash-password --plaintext 'YourNewPassword'

# Copy the hash output
# Edit docker-compose/config/caddy/Caddyfile
# Replace the hash in all basic_auth blocks
# Restart Caddy
docker compose restart caddy
```

## What's Different from Standard Setup?

**Standard Setup (Vulnerable):**
- Services exposed on multiple ports (3000, 5050, 7700, 8000, 9000, 9001, 9090, 9093, 3100)
- Direct access bypasses security
- Single point of failure

**Edge Enforcement (Secure):**
- Only Caddy on ports 80/443
- All traffic goes through authenticated edge
- Defense-in-depth (edge auth + service auth)
- No bypass possible

## Next Steps

1. **Change default edge password** in Caddyfile (see Security Notes above)
2. **Explore Grafana dashboards**: http://localhost/grafana
3. **View Prometheus targets**: http://localhost/prometheus/targets
4. **Test the API**: http://localhost/docs
5. **Read full documentation**: `EDGE_ENFORCEMENT_DEPLOYMENT.md`

## Architecture Overview

```

  Internet / Local Browser                       

                    
                    
         
           Caddy (Port 80/443)   Edge Auth (Basic Auth)
           Reverse Proxy       
         
                    
        
           Docker Network      
           (app-network)       
        
                    
    
                                  
                                  
      
 FastAPI     Grafana      pgAdmin    Per-Service Auth
  App                              
      
                                  
                                  
      
 Postgres   Prometheus     MinIO   
      
```

## Support

- **Full Documentation**: `EDGE_ENFORCEMENT_DEPLOYMENT.md`
- **Original README**: `README.md`
- **Logs**: `docker compose logs -f`
- **Status**: `docker compose ps`

---

**Ready to deploy?** Run `./deploy-edge-enforcement.sh` or follow the 5-step quick deploy above.