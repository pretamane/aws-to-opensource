# Interview Cheat Sheet

##  Elevator Pitch (30 seconds)

"I migrated a document management platform from a $330/mo AWS EKS stack to a $30/mo EC2 + open-source stack, achieving 90% cost savings without sacrificing features. The system uses PostgreSQL with JSONB for flexible data, MinIO for S3-compatible storage, Meilisearch for sub-20ms searches, and a complete Prometheus/Grafana/Loki observability suite, all fronted by Caddy for security. Infrastructure is fully automated with Terraform and Docker Compose."

---

##  Cost Savings Breakdown

| Service | Before (AWS) | After (Open-Source) | Savings |
|---------|-------------|---------------------|---------|
| Orchestration | EKS $75 | Docker Compose $0 | $75 |
| Compute | Node Groups $80 | EC2 t3.medium $30 | $50 |
| Database | DynamoDB $15 | PostgreSQL $0 | $15 |
| Search | OpenSearch $60 | Meilisearch $0 | $60 |
| Storage | S3+EFS $40 | MinIO $0 | $40 |
| Load Balancer | ALB $20 | Caddy $0 | $20 |
| Monitoring | CloudWatch $10 | Prometheus+Grafana $0 | $10 |
| Networking | NAT Gateway $30 | Direct routing $0 | $30 |
| **TOTAL** | **$330/mo** | **$30/mo** | **$300/mo (90%)** |

---

##  Layer Flashcards

### Edge
- **Tech**: Caddy + Cloudflared
- **Purpose**: Single entry point, security headers, Basic Auth, path routing
- **Key Feature**: Auto-HTTPS, CSP, HSTS

### Application
- **Tech**: FastAPI (Python 3.11)
- **Purpose**: API endpoints, document processing, background tasks
- **Key Feature**: Prometheus metrics, Pydantic validation, async/await

### Database
- **Tech**: PostgreSQL 16
- **Purpose**: ACID transactions, complex queries, JSONB flexibility
- **Key Feature**: Connection pooling (7x latency reduction), GIN indexes

### Search
- **Tech**: Meilisearch
- **Purpose**: Full-text search with typo tolerance
- **Key Feature**: <20ms searches, Levenshtein distance, smart ranking

### Storage
- **Tech**: MinIO
- **Purpose**: S3-compatible object storage
- **Key Feature**: S3 API (boto3 compatible), no egress fees

### Observability
- **Tech**: Prometheus, Grafana, Loki, Promtail, Alertmanager
- **Purpose**: Metrics, dashboards, logs, alerts
- **Key Feature**: PromQL, LogQL, custom business metrics

### Automation
- **Tech**: Terraform, Docker Compose, shell scripts
- **Purpose**: Provision infrastructure, orchestrate services, automate ops
- **Key Feature**: IaC, one-command deployment, automated backups

---

##  STAR Stories (Problem-Solving Examples)

### Story 1: MinIO Console CSS Fix
- **Situation**: Console UI loaded but was completely unstyled (white page)
- **Task**: Restore admin usability before demo
- **Action**: 
  - Browser console: CSS requests returned 404
  - Network tab: Content-Type was text/html, not text/css
  - Root cause: `handle_path` stripped prefix too early
  - Fixed: Changed to `handle` + `uri strip_prefix` with correct order
  - Verified: Content-Type headers now correct
- **Result**: Console fully functional, documented fix in architecture docs

### Story 2: PostgreSQL Password Escaping
- **Situation**: API failing authentication despite correct credentials
- **Task**: Restore database connectivity
- **Action**:
  - Manual `psql` test: worked (password correct)
  - Checked env vars in container: `DB_PASSWORD=#ThawZin2k77!`
  - Root cause: Shell interpreted `#` as comment, value was empty
  - Fixed: Quoted password in `.env` file
- **Result**: Connection restored, added note to deployment docs

### Story 3: High Latency Investigation
- **Situation**: Prometheus alert fired: P95 latency >1s
- **Task**: Identify bottleneck and restore performance
- **Action**:
  - Grafana: Latency spike started 10:15am
  - Prometheus: `active_database_connections = 10/10` (pool exhausted)
  - Loki logs: "psycopg2.pool.PoolError: connection pool exhausted"
  - Root cause: Slow queries holding connections
  - Immediate fix: Restart fastapi-app (frees connections)
  - Permanent fix: Increase pool size 10→20, add connection timeout
- **Result**: Latency back to <100ms, pool sizing guidelines documented

---

##  Technology Trade-offs

### When to Use Current Stack
-  <1K req/sec
-  Single-region deployment
-  Budget-conscious ($30/mo sweet spot)
-  Team comfortable with ops

### When to Migrate to Managed Services
- ️ >10K req/sec sustained
- ️ Multi-region required
- ️ 24/7 SLA with on-call team
- ️ Compliance requirements (audit, encryption, MFA)

### Migration Paths
- **Vertical**: t3.medium → t3.large → t3.xlarge
- **Horizontal**: ALB + Auto Scaling Group + 2+ EC2 instances
- **Managed**: RDS, ElastiCache, ECS, EKS (as needs justify costs)

---

## ️ Security Quick Hits

- **HSTS**: Force HTTPS, prevent SSL stripping
- **CSP**: Block XSS, whitelist trusted CDNs
- **X-Frame-Options**: SAMEORIGIN, prevent clickjacking
- **X-Content-Type-Options**: nosniff, prevent MIME sniffing
- **Basic Auth**: bcrypt hashed, temporary MVP solution
- **Future**: OAuth2/OIDC (Keycloak), nonce-based CSP, rate limiting

---

##  Performance Benchmarks

- **API Latency**: P50=50ms, P95=150ms
- **Search Speed**: <20ms typical
- **DB Query**: ~10ms (from connection pool)
- **File Upload**: 2MB in 50-100ms
- **Throughput**: ~500 req/sec (current capacity)

---

##  Key Failure Modes

| Issue | Detection | Fix |
|-------|-----------|-----|
| **DB down** | `up{job="postgresql"} == 0` | Check logs, fix volume permissions, restart |
| **Pool exhausted** | `active_database_connections == 10/10` | Restart app, increase pool size |
| **Disk full** | `node_filesystem_avail < 10%` | Clean logs, prune Docker, increase volume |
| **High latency** | `http_request_duration > 1s` | Check DB pool, optimize queries, scale |
| **Search empty** | Search returns 0 results | Re-index documents, verify Meilisearch config |

---

##  Essential Commands

```bash
# Infrastructure
terraform apply                    # Deploy AWS resources
terraform destroy                  # Cleanup

# Services
docker-compose up -d               # Start all services
docker-compose ps                  # Check status
docker-compose logs -f fastapi-app # View logs
docker-compose restart <service>   # Restart single service

# Health Checks
curl http://localhost:8080/health  # API health
curl http://localhost:8080/metrics # Prometheus metrics

# Database
docker exec postgresql psql -U pretamane -d pretamane_db
docker exec postgresql pg_dump -U pretamane pretamane_db > backup.sql

# Debugging
docker stats --no-stream           # Resource usage
docker logs <container> --tail=50  # Recent logs
docker exec -it <container> /bin/sh # Shell access
```

---

##  Interview Question Stems

### Architecture
- "Walk me through your system architecture"
- "How do components communicate?"
- "What's the data flow for [X scenario]?"

### Trade-offs
- "Why did you choose [X] over [Y]?"
- "What are the limitations of your current setup?"
- "When would you migrate back to AWS managed services?"

### Problem-Solving
- "Tell me about a challenging technical problem you solved"
- "How do you debug production incidents?"
- "Walk me through your troubleshooting process"

### Scaling
- "How would you scale this system?"
- "What are the bottlenecks?"
- "At what point would you revisit technology choices?"

### Operations
- "How do you handle failures?"
- "What's your backup and disaster recovery strategy?"
- "How do you monitor system health?"

---

##  Production Readiness Roadmap

**Security**:
- [ ] Enable Let's Encrypt TLS
- [ ] Migrate Basic Auth → OAuth2/OIDC
- [ ] Implement nonce-based CSP
- [ ] Add rate limiting
- [ ] Move secrets to Vault

**Reliability**:
- [ ] Add second EC2 + ALB for HA
- [ ] PostgreSQL streaming replication
- [ ] MinIO distributed mode (4+ nodes)
- [ ] Automated backups to S3

**Observability**:
- [ ] Distributed tracing (Jaeger)
- [ ] Error tracking (Sentry)
- [ ] External uptime monitoring
- [ ] PagerDuty integration

**Operations**:
- [ ] CI/CD pipeline (GitHub Actions)
- [ ] Blue-green deployments
- [ ] Automated testing
- [ ] Runbook for every alert

---

##  Key Messages to Emphasize

1. **Cost-Conscious Engineering**: "I reduced costs by 90% while maintaining features—shows pragmatic decision-making."

2. **Technical Breadth**: "Comfortable with cloud-managed (EKS) and self-hosted (EC2) solutions—both have trade-offs."

3. **Production Awareness**: "I document trade-offs and have clear roadmap for production hardening (OAuth2, TLS, HA)."

4. **Problem-Solving**: "Systematic debugging: Grafana → Prometheus → Loki → Runbook → Fix → Document."

5. **Portability**: "S3 API, Prometheus metrics, standard protocols—no vendor lock-in."

6. **Real Experience**: "I can show live demos, explain every decision, and walk through actual incidents I debugged."

---

##  Final Pre-Interview Checklist

- [ ] Memorized elevator pitch
- [ ] Rehearsed 3 STAR stories
- [ ] Can draw architecture diagram from memory
- [ ] Reviewed key trade-offs
- [ ] Know cost breakdown
- [ ] Can explain each service's role
- [ ] Ready to live demo (if needed)
- [ ] Prepared questions for interviewer

---

**Print this page and keep it visible during your interview!**

