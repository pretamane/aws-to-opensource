# Interview Guide: Complete Architecture Overview

##  30-Second Elevator Pitch

"I built a production-grade cloud-native platform that migrated from AWS to open-source alternatives, reducing costs while maintaining enterprise features. The stack includes Caddy for edge security, FastAPI for the API layer, PostgreSQL for ACID-compliant data storage, MinIO for S3-compatible object storage, Meilisearch for full-text search, and a complete observability stack with Prometheus, Grafana, and Loki. All orchestrated via Docker Compose with proper health checks, security headers, and automated initialization."

##  Interview Document Index

1. **[INTERVIEW-01-Reverse-Proxy-Architecture.md](./INTERVIEW-01-Reverse-Proxy-Architecture.md)**
   - Single edge entry point with Caddy
   - Path-based routing and subpath applications
   - Security headers and Basic Auth

2. **[INTERVIEW-02-Database-Architecture.md](./INTERVIEW-02-Database-Architecture.md)**
   - PostgreSQL vs DynamoDB migration
   - JSONB + GIN indexes for flexible schema
   - Connection pooling and atomic counters

3. **[INTERVIEW-03-Observability-Stack.md](./INTERVIEW-03-Observability-Stack.md)**
   - Prometheus metrics and custom instrumentation
   - Loki log aggregation with Promtail
   - Blackbox synthetic monitoring and alerting

4. **[INTERVIEW-04-Security-Implementation.md](./INTERVIEW-04-Security-Implementation.md)**
   - Defense-in-depth with CSP, HSTS, XFO
   - Content Security Policy tuning
   - Basic Auth and OAuth2 migration path

5. **[INTERVIEW-05-Service-Orchestration.md](./INTERVIEW-05-Service-Orchestration.md)**
   - Docker Compose dependency management
   - Health checks and restart policies
   - Volume management and initialization

6. **[INTERVIEW-06-Object-Storage-MinIO.md](./INTERVIEW-06-Object-Storage-MinIO.md)**
   - S3-compatible storage with MinIO
   - Bucket policies and access control
   - Subpath routing for web console

##  Complete Data Flow

### User Uploads Document Scenario

```
1. User fills contact form with file attachment
   ↓
2. Browser: POST /api/contact (with multipart/form-data)
   ↓
3. Caddy: 
   - Checks CSP, HSTS headers
   - Routes /api/* → fastapi-app:8000
   ↓
4. FastAPI:
   - Validates form data (Pydantic models)
   - Generates contact_id (UUID)
   - Records metrics: contact_submissions_total.inc()
   ↓
5. PostgreSQL Service:
   - INSERT INTO contact_submissions (...)
   - Connection from pool (reused, not opened)
   - Returns contact_id
   ↓
6. MinIO Storage Service:
   - Uploads file to s3://pretamane-data/documents/{contact_id}/file.pdf
   - Sets metadata (uploaded-by, timestamp)
   ↓
7. Meilisearch Service:
   - Indexes document metadata for search
   - Stores: {id, filename, contact_id, tags}
   ↓
8. Background Task:
   - Processes document (extract text, entities)
   - Updates PostgreSQL: document_insights JSONB
   - Sets processing_status = 'completed'
   ↓
9. Email Service (AWS SES):
   - Sends notification to admin
   ↓
10. Observability:
    - Prometheus: Scrapes /metrics (upload count, latency)
    - Loki: Stores structured logs from FastAPI
    - Grafana: Displays dashboard update
```

### Monitoring & Alerting Flow

```
1. Application Emits Metrics
   FastAPI → Prometheus metrics endpoint (/metrics)
   ↓
2. Prometheus Scrapes
   Every 10s: GET http://fastapi-app:9091/metrics
   Stores: http_requests_total{status="200"} 1542
   ↓
3. Alert Evaluation
   Every 30s: Checks alert rules
   If: rate(http_requests_total{status="500"}[5m]) > 5
   Then: Fire alert "HighErrorRate"
   ↓
4. Alertmanager
   Receives alert from Prometheus
   Routes based on severity:
   - critical → PagerDuty (production)
   - warning → Slack (staging)
   ↓
5. Grafana Dashboard
   Queries Prometheus: http_requests_total
   Displays: Line graph of request rate
   ↓
6. Loki Logs (Parallel Path)
   Promtail reads: /var/log/caddy/access.log
   Ships to Loki: {job="caddy", status="500"}
   ↓
7. Troubleshooting
   Engineer sees alert → Opens Grafana
   Checks metrics: Latency spike at 10:15am
   Checks logs: {job="api"} |= "ERROR" |= "10:15"
   Finds: "Database connection pool exhausted"
```

##  Service Interconnections

### Dependency Map

```
Caddy (edge)
→ FastAPI (application)
   → PostgreSQL (data)
   → Meilisearch (search)
   → MinIO (storage)
   → AWS SES (email)

→ Grafana (monitoring UI)
   → Prometheus (query metrics)
   → Loki (query logs)

→ Prometheus (metrics)
   → Scrapes: FastAPI, MinIO, Grafana, Loki
   → Evaluates: Alert Rules

→ MinIO Console (storage UI)
→ pgAdmin (database UI)
→ Meilisearch UI (search admin)

Promtail (log shipper)
→ Reads: /var/log/caddy/, /mnt/logs/
→ Ships to: Loki

Blackbox Exporter (synthetic monitoring)
→ Probes: HTTP endpoints
→ Reports to: Prometheus
```

### Network Communication

| Source | Target | Port | Protocol | Purpose |
|--------|--------|------|----------|---------|
| User Browser | Caddy | 8080 | HTTP | All traffic |
| Caddy | FastAPI | 8000 | HTTP | API requests |
| Caddy | Grafana | 3000 | HTTP | Dashboard |
| Caddy | MinIO Console | 9001 | HTTP | Storage UI |
| FastAPI | PostgreSQL | 5432 | PostgreSQL | Database queries |
| FastAPI | Meilisearch | 7700 | HTTP | Search indexing |
| FastAPI | MinIO API | 9000 | HTTP (S3) | File uploads |
| Prometheus | FastAPI | 9091 | HTTP | Scrape /metrics |
| Prometheus | MinIO | 9000 | HTTP | Scrape /minio/v2/metrics |
| Promtail | Loki | 3100 | HTTP | Ship logs |
| Grafana | Prometheus | 9090 | HTTP | Query metrics |
| Grafana | Loki | 3100 | HTTP | Query logs |

##  Startup Sequence

```
1. Docker Compose Starts
   ↓
2. Network Creation
   app-network (bridge, 172.25.0.0/16)
   ↓
3. Volume Creation
   postgres-data, minio-data, prometheus-data, etc.
   ↓
4. Base Layer (No Dependencies)
   → PostgreSQL (initializes schema from /docker-entrypoint-initdb.d/)
   → Meilisearch
   → MinIO
   → Loki
   ↓
5. Wait for Health Checks
   PostgreSQL: pg_isready → healthy
   Meilisearch: /health → 200
   MinIO: /minio/health/live → 200
   ↓
6. Init Jobs
   → minio-setup (creates buckets, exits)
   ↓
7. Application Layer (depends_on: base layer)
   → FastAPI
       - Connects to PostgreSQL (from pool)
       - Connects to Meilisearch
       - Connects to MinIO
       - Exposes /metrics
       - Health check: /health → 200
   ↓
8. Monitoring Layer
   → Prometheus (scrapes FastAPI, MinIO, etc.)
   → Grafana (connects to Prometheus, Loki)
   → Promtail (ships logs to Loki)
   → Blackbox Exporter (probes endpoints)
   → Alertmanager
   ↓
9. Edge Layer (depends_on: everything)
   → Caddy
       - Loads Caddyfile
       - Sets up reverse proxy routes
       - Applies security headers
       - Ready to accept traffic
   ↓
10. Stack Ready
    Access: http://localhost:8080
```

##  Key Design Decisions & Rationale

### 1. Why Caddy Over Nginx?

**Choice**: Caddy  
**Reasoning**: 
- Auto-HTTPS (would use Let's Encrypt in production)
- Simpler config syntax (easier to maintain)
- Security by default (good headers out of box)

**Trade-off Accepted**: Smaller community than Nginx, but adequate for our scale.

### 2. Why PostgreSQL Over DynamoDB?

**Choice**: PostgreSQL  
**Reasoning**:
- Needed complex queries (joins, aggregations)
- Wanted strong consistency (ACID)
- Cost predictability (fixed vs per-request)

**Trade-off Accepted**: Manual scaling vs DynamoDB auto-scale, but our load doesn't need it.

### 3. Why JSONB Columns?

**Choice**: Hybrid (structured columns + JSONB metadata)  
**Reasoning**:
- Core fields (name, email) as columns → type safety, indexes
- Variable metadata (document_insights) as JSONB → schema flexibility

**Trade-off Accepted**: Slightly harder to query JSONB, but GIN indexes mitigate this.

### 4. Why Basic Auth Now, OAuth2 Later?

**Choice**: Basic Auth for MVP, migrate to OAuth2  
**Reasoning**:
- Basic Auth: Simple, works immediately, better than nothing
- OAuth2: Better UX, SSO, MFA, audit trail

**Trade-off Accepted**: Temporary weaker security, but documented migration path.

### 5. Why Docker Compose, Not Kubernetes?

**Choice**: Docker Compose  
**Reasoning**:
- Single-host deployment (cost-effective)
- Simpler ops (no K8s complexity)
- Adequate for current scale (<1K req/sec)

**Migration Path**: When scale demands, move to Kubernetes with same container images.

##  System Capacity & Performance

### Current Capacity Estimates

| Resource | Limit | Current Usage | Headroom |
|----------|-------|---------------|----------|
| **HTTP Requests** | ~500/sec (Caddy) | <10/sec | 50x |
| **Database Connections** | 200 max, 10 pool | 2-5 active | 40x |
| **Storage** | 500GB volume | ~5GB | 100x |
| **Memory** | 16GB host | ~8GB used | 2x |

### Scaling Triggers

**When to scale horizontally**:
- CPU consistently >80% for 1 hour
- Request rate >100/sec for sustained period
- Database connections pool exhausted (10/10 in use)

**How to scale**:
1. Add load balancer (HAProxy/Nginx)
2. Run 2+ FastAPI instances
3. Configure PostgreSQL read replicas
4. MinIO distributed mode (4+ nodes)

##  Common Issues & Solutions

### Issue: Service Won't Start

**Symptoms**:
```bash
docker-compose ps
# postgresql    Exit 1
```

**Debug Steps**:
1. Check logs: `docker logs postgresql`
2. Check volumes: `docker volume ls`
3. Check ports: `sudo lsof -i :5432`

**Common Causes**:
- Port conflict (another PostgreSQL running)
- Volume permission issues (SELinux)
- Corrupted data volume (run `docker-compose down -v`)

### Issue: Health Check Failing

**Symptoms**:
```bash
docker-compose ps
# fastapi-app    Up (health: starting)
```

**Debug Steps**:
1. Check health command: `docker inspect fastapi-app | grep -A 5 Healthcheck`
2. Run health check manually: `docker exec fastapi-app curl http://localhost:8000/health`
3. Check logs: `docker logs fastapi-app`

**Common Causes**:
- App listening on 0.0.0.0 but health check uses localhost
- Increase `start_period` (app needs more time to initialize)

### Issue: CSS/JS Not Loading (404s)

**Symptoms**: Browser shows unstyled page, console shows 404 errors

**Debug Steps**:
1. Check browser network tab (requested URL)
2. Curl the resource: `curl -I http://localhost:8080/path/to/asset`
3. Check Caddy logs: `docker logs caddy | grep "asset"`
4. Verify file exists: `docker exec caddy ls /var/www/pretamane/path/to/asset`

**Common Causes**:
- Wrong path in HTML (relative vs absolute)
- Subpath app missing base href
- Caddy routing misconfigured

##  Interview Q&A Preparation

### Q: "Describe your architecture"
**A**: "I built a microservices platform with a single edge proxy (Caddy) routing to specialized services: FastAPI for business logic, PostgreSQL for transactional data, MinIO for object storage, and Meilisearch for full-text search. All monitored via Prometheus/Grafana/Loki with synthetic checks via Blackbox Exporter."

### Q: "How do you handle failures?"
**A**: "Multi-layer approach: Health checks detect failures, restart policies recover services, connection pooling handles transient DB issues, and alerts notify ops via Prometheus. For example, if PostgreSQL crashes, Docker restarts it, FastAPI's pool retries connections, and an alert fires if down >2 minutes."

### Q: "What's your security strategy?"
**A**: "Defense in depth: HSTS prevents SSL stripping, CSP blocks XSS, Basic Auth protects admin UIs, and CORS restricts API access. All applied at the edge (Caddy) so every service benefits. Migration path to OAuth2 for SSO and MFA in production."

### Q: "How would you scale this?"
**A**: "Current setup handles ~500 req/sec on single host. To scale: Add load balancer, run 2+ FastAPI instances, configure PostgreSQL read replicas for queries, and MinIO distributed mode for storage. Docker Compose images work unchanged in Kubernetes."

### Q: "Explain a tough problem you solved"
**A**: "MinIO Console was loading but completely unstyled. I debugged by checking browser console (wrong paths), response headers (text/html instead of text/css), and Caddy logs (routing to wrong backend). Root cause was using `handle_path` instead of `handle` + `uri strip_prefix` - path stripped too early. Fixed directive order, verified Content-Type headers, Console worked perfectly."

##  Production Readiness Checklist

- [ ] **TLS**: Enable HTTPS with Let's Encrypt via Caddy
- [ ] **Auth**: Migrate Basic Auth → OAuth2/OIDC (Keycloak)
- [ ] **Secrets**: Move .env credentials → Docker Secrets/Vault
- [ ] **Backups**: Automate PostgreSQL dumps, MinIO replication
- [ ] **Monitoring**: Create Grafana dashboards, tune alert thresholds
- [ ] **Rate Limiting**: Add Caddy rate limiter (10 req/sec/IP)
- [ ] **CSP**: Migrate to nonce-based CSP (no 'unsafe-inline')
- [ ] **Logging**: Ship logs to external aggregator (Elasticsearch/S3)
- [ ] **HA**: Run 2+ instances of each service
- [ ] **DR**: Document restore procedures, test quarterly

##  Next Steps for Deep Learning

1. Read each numbered interview guide document in order
2. Practice explaining each section out loud
3. Draw the architecture diagram on whiteboard from memory
4. Prepare 2-3 STAR stories per document
5. Run `docker-compose up` and demonstrate live to yourself

**Good luck with your interview!** 
