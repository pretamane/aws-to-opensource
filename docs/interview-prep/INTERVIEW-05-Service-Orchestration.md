# Interview Guide: Service Orchestration (Docker Compose)

##  Selling Point
"I orchestrated 12+ containerized services with dependency management, health checks, and automated initialization, ensuring reliable startup order and graceful failure handling."

##  Complete Service Architecture

```

                    Edge Layer (Port 8080)                   
                                                 
    Caddy    → Reverse Proxy + Security Headers           
                                                 

         
         → Static Website (pretamane-website/)
         
    
         Application Layer                
                          
        FastAPI                         
        - /api/*                        
        - /docs                         
        - /metrics                      
                          
    
                
    
                    Data Layer       
                                     
                
      PostgreSQL  MinIO S3         
      - Contacts  - Uploads        
      - Docs      - Backups        
                
                                        
                       
       Meilisearch                   
       - Doc Search                  
                       
    
          
    
        Observability Layer            
              
      Prometheus   Grafana        
      - Metrics   -Dashboard      
              
                                       
              
        Loki       Promtail       
      - Logs      -Shipper        
              
                                       
                     
       Blackbox                      
       - HTTP Probes                 
                     
    
```

##  Service Dependencies & Startup Order

### The Problem: Race Conditions

**Without dependency management**:
```
1. PostgreSQL starts (takes 5s to initialize)
2. FastAPI starts immediately
3. FastAPI tries to connect to DB
4.  Connection refused (DB not ready)
5. FastAPI crashes
```

### Our Solution: depends_on + healthchecks

```yaml
fastapi-app:
  depends_on:
    - postgresql
    - meilisearch
    - minio
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
    start_period: 40s
```

**What Happens**:
```
1. Docker Compose starts postgresql, meilisearch, minio in parallel
2. Waits for their containers to start (NOT ready, just started)
3. Then starts fastapi-app
4. FastAPI has 40s grace period (start_period)
5. If DB not ready yet, FastAPI retries connection
6. Health check succeeds once /health returns 200
```

**Interview Point**: "depends_on ensures startup ORDER, but health checks ensure services are READY. Both are needed for reliable initialization."

##  Health Check Patterns

### Application Health Check

```yaml
fastapi-app:
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 40s
```

**Breakdown**:

| Field | Value | Meaning |
|-------|-------|---------|
| **test** | `curl -f /health` | Command to run inside container |
| **interval** | 30s | Check every 30 seconds |
| **timeout** | 10s | If check takes >10s, it fails |
| **retries** | 3 | Must fail 3x before unhealthy |
| **start_period** | 40s | Grace period (failures don't count) |

**Health States**:
1. **starting** → Container running, within start_period
2. **healthy** → Check passed at least once
3. **unhealthy** → Failed `retries` consecutive times

### Database Health Check

```yaml
postgresql:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U pretamane -d pretamane_db"]
    interval: 10s
    timeout: 5s
    retries: 5
```

**Why pg_isready?**
-  Fast (~5ms)
-  Doesn't require table access
-  Returns 0 if DB accepting connections

**Alternative** (slower but thorough):
```yaml
test: ["CMD-SHELL", "psql -U pretamane -d pretamane_db -c 'SELECT 1'"]
```

### Services Without Health Checks

```yaml
node-exporter:
  # No healthcheck - uses scratch image without curl/wget
```

**Why?**
- node-exporter uses minimal scratch base image
- No shell, no curl, no health check tools
- Solution: Monitor via Prometheus `up{job="node-exporter"}`

**Interview Insight**: "Some minimal images can't run health checks. Instead, I monitor them via Prometheus scrape success metrics."

##  Restart Policies

```yaml
restart: unless-stopped
```

### Policy Comparison

| Policy | Behavior | Use Case |
|--------|----------|----------|
| `no` | Never restart | Dev/testing only |
| `on-failure` | Restart if exit code ≠ 0 | Batch jobs |
| `always` | Restart even after `docker stop` | Background services (risk: ignores manual stops) |
| `unless-stopped` | Restart unless manually stopped | **Our choice** - respects ops intent |

**Real Scenario**:
```bash
# Ops runs: docker stop fastapi-app (to deploy new version)

# With restart: always
→ Container immediately restarts (annoying!)

# With restart: unless-stopped  
→ Container stays stopped (as intended) 

# After host reboot:
→ Container auto-starts (resilient) 
```

**Interview Answer**: "I use `unless-stopped` for production services because it balances resilience (auto-restart on crashes/reboots) with operational control (respects manual stops for maintenance)."

##  Networking Architecture

### Bridge Network Configuration

```yaml
networks:
  app-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.25.0.0/16
```

**Why Custom Subnet?**
- Default Docker networks use 172.17.0.0/16
- If you run multiple stacks, they might conflict
- Custom subnet avoids collisions

### DNS Resolution

**Automatic DNS**:
```python
# Inside fastapi-app container
import psycopg2
conn = psycopg2.connect(
    host='postgresql',  # ← Docker DNS resolves to container IP
    port=5432
)
```

**What happens**:
1. FastAPI container queries Docker's embedded DNS (127.0.0.11)
2. Docker DNS returns IP of `postgresql` container (e.g., 172.25.0.5)
3. Connection established

**Interview Point**: "Docker Compose creates a DNS entry for each service name, allowing containers to discover each other without hardcoded IPs."

##  Volume Management

### Volume Types We Use

```yaml
volumes:
  # Named volumes (managed by Docker)
  postgres-data:     # Database persistence
  minio-data:        # Object storage
  prometheus-data:   # Metrics history
  
  # Bind mounts (host directories)
  ./config/caddy/Caddyfile:/etc/caddy/Caddyfile:z
  ../pretamane-website:/var/www/pretamane:z
```

**Named vs Bind Mounts**:

| Type | Lifecycle | Backup | Use Case |
|------|-----------|--------|----------|
| **Named volume** | Survives `docker-compose down` | `docker cp` or backup container | Database data, uploads |
| **Bind mount** | On host filesystem | Standard file backup | Config files, source code |

**The :z Flag** (SELinux):
```yaml
- ./config/caddy/Caddyfile:/etc/caddy/Caddyfile:z
```
- Relabels file for container access on SELinux systems
- Without :z on Fedora/RHEL: Permission denied

##  Initialization Patterns

### Database Schema Initialization

```yaml
postgresql:
  volumes:
    - ./init-scripts/postgres:/docker-entrypoint-initdb.d:z
```

**Execution Flow**:
```
1. PostgreSQL container starts
2. Checks if /var/lib/postgresql/data is empty
3. If empty:
   - Initialize database cluster
   - Execute scripts in /docker-entrypoint-initdb.d/ in alphabetical order:
     * 01-init-schema.sql (tables, indexes, functions)
     * 02-seed-data.sql (sample data)
4. If not empty:
   - Skip initialization (data exists)
```

**Interview Insight**: "Init scripts run ONLY on first boot when the data volume is empty. This is idempotent - repeated `docker-compose up` doesn't re-run migrations."

### MinIO Bucket Creation

```yaml
minio-setup:
  image: minio/mc:latest
  depends_on:
    - minio
  entrypoint: >
    /bin/sh -c "
    sleep 5;
    mc alias set myminio http://minio:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD;
    mc mb myminio/pretamane-data --ignore-existing;
    mc mb myminio/pretamane-backup --ignore-existing;
    mc anonymous set download myminio/pretamane-data;
    exit 0;
    "
```

**Pattern Breakdown**:

1. **One-time job**: Container runs, executes setup, exits
2. **depends_on minio**: Waits for MinIO container to start
3. **sleep 5**: Crude wait for MinIO to be ready (better: loop with health check)
4. **--ignore-existing**: Idempotent (doesn't fail if bucket exists)
5. **exit 0**: Always succeed (even if buckets already exist)

**Production Improvement**:
```bash
# Better: Retry loop with timeout
until mc admin info myminio > /dev/null 2>&1; do
  echo "Waiting for MinIO..."
  sleep 2
done
mc mb myminio/pretamane-data --ignore-existing
```

##  Environment Variable Strategy

### Three-Layer Configuration

```yaml
fastapi-app:
  environment:
    # 1. Hardcoded defaults (in docker-compose.yml)
    - APP_NAME=realistic-demo-pretamane
    - ENVIRONMENT=production
    
    # 2. From .env file (secrets)
    - DB_PASSWORD=${DB_PASSWORD}
    - MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}
    
    # 3. Computed/derived
    - DB_HOST=postgresql  # Service name (Docker DNS)
```

### Why NOT Connection Strings?

**Problematic**:
```yaml
- DATABASE_URL=postgresql://pretamane:#ThawZin2k77!@postgresql:5432/pretamane_db
                                    ↑ Special chars break parsing!
```

**Better**:
```yaml
- DB_HOST=postgresql
- DB_PORT=5432
- DB_USER=pretamane
- DB_PASSWORD=#ThawZin2k77!  # Special chars OK in individual env var
```

**Interview Story**: "I initially used a connection URL but special characters in passwords broke parsing. I switched to individual parameters which are properly escaped by Docker, avoiding URL encoding issues."

##  Troubleshooting Common Issues

### Issue 1: Container Starts But App Crashes

**Symptom**:
```bash
docker-compose ps
# fastapi-app    Up (health: starting)
# postgresql     Up (healthy)
```

**Debug**:
```bash
docker logs fastapi-app
# psycopg2.OperationalError: could not connect to server
```

**Cause**: App started before DB was ready

**Fix**: Increase `start_period` or add retry logic in app

---

### Issue 2: Permission Denied on Volumes

**Symptom**:
```
Error: cannot open /etc/caddy/Caddyfile: Permission denied
```

**Cause**: SELinux blocking access

**Fix**: Add `:z` flag to bind mount
```yaml
- ./config/caddy/Caddyfile:/etc/caddy/Caddyfile:z
```

---

### Issue 3: Port Already in Use

**Symptom**:
```
Error starting userland proxy: listen tcp 0.0.0.0:8080: bind: address already in use
```

**Debug**:
```bash
sudo lsof -i :8080
# Shows what's using port 8080
```

**Fix**: Stop conflicting service or change port:
```yaml
ports:
  - "8081:80"  # Host:Container
```

##  Production Scaling Path

### Current (Single Host)
```
Single Server
 Caddy (1 instance)
 FastAPI (1 instance)
 PostgreSQL (1 instance)
 All other services (1 each)
```

### Production (High Availability)
```
Load Balancer
 Server 1
    Caddy (instance 1)
    FastAPI (instance 1)
 Server 2
    Caddy (instance 2)
    FastAPI (instance 2)
 Server 3
     PostgreSQL (primary)
     PostgreSQL (replica - read-only)

Shared Services
 MinIO (distributed mode - 4+ nodes)
 Prometheus (separate monitoring host)
```

##  Interview Talking Points

1. **"Dependency orchestration"**: Used `depends_on` for startup order + health checks for readiness verification.

2. **"Initialization patterns"**: Database init scripts run once on first boot, MinIO setup uses idempotent commands.

3. **"Restart policies"**: Chose `unless-stopped` to balance auto-recovery with operational control.

4. **"Environment variable strategy"**: Individual params instead of connection URLs to avoid special character encoding issues.

5. **"Volume management"**: Named volumes for data persistence, bind mounts for config, :z flag for SELinux.

6. **"Production migration path"**: Current setup is single-host; can scale to multi-instance with load balancer and DB replication.
