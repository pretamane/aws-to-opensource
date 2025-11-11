# Interview Cheat Sheet

Use this page right before your interview. It compresses the architecture into punchy sound bites, STAR stories, and comparison points.

## Elevator Pitch (30s)
"I migrated a document management platform from a $330/mo AWS EKS stack to a $30/mo EC2 + open-source stack without losing enterprise features. Everything runs on Docker Compose with PostgreSQL, Meilisearch, MinIO, and a full Prometheus/Grafana/Loki observability suite, fronted by Caddy for security. Terraform and scripts automate provisioning, deployment, and backups." 

## Cost Optimization Highlights
- **90% savings** by replacing managed services with open-source equivalents.
- Reused AWS SES (free tier) where it still makes sense; everything else self-hosted.
- Terraform keeps infrastructure minimal: one VPC, one EC2, least-privilege IAM.

## Layer Flashcards
- **Edge**: Caddy + Cloudflared, Basic Auth, CSP, static site.
- **Application**: FastAPI, background tasks, Prometheus metrics.
- **Data**: PostgreSQL with JSONB, connection pooling, PL/pgSQL counters.
- **Search**: Meilisearch with typo tolerance, filterable/sortable attributes.
- **Storage**: MinIO S3 API, buckets for data/backup/logs.
- **Observability**: Prometheus, Grafana, Loki, Promtail, Alertmanager, Blackbox.
- **Automation**: Terraform, Docker Compose, deployment + backup scripts.
- **Security**: Security groups, Caddy headers, IAM role, encrypted volumes.

## STAR Story Starters
1. **MinIO Console Fix**
   - *Situation*: UI rendered without CSS.
   - *Task*: Restore admin usability before demo.
   - *Action*: Inspected CSP errors, adjusted Caddy directives (`handle` + `uri strip_prefix`), verified content types.
   - *Result*: Console fully functional; documented fix for future.
2. **Postgres Password Escaping**
   - *Situation*: API failing auth despite correct credentials.
   - *Task*: Restore database connectivity.
   - *Action*: Tested with `psql`, inspected env vars; discovered `#` comment issue, quoted password in `.env`.
   - *Result*: Connection restored, added note to docs.
3. **Latency Spike Investigation**
   - *Situation*: Alert on high request latency.
   - *Task*: Identify bottleneck.
   - *Action*: Checked Grafana, correlated Prometheus metrics, found DB connection pool exhaustion, increased pool size.
   - *Result*: Latency back to <100 ms, pool sizing guidelines documented.

## Comparison Talking Points
- **EKS vs EC2 Edition**: Enterprise auto-scaling vs cost-efficient simplicity; both skill sets demonstrated.
- **PostgreSQL vs DynamoDB**: Strong consistency, complex queries, predictable cost vs. unlimited scale.
- **MinIO vs S3**: Same S3 API for portability, no egress charges, can migrate back to S3 if scale demands.

## Production Roadmap (show maturity)
- Add OAuth2/OIDC (Keycloak) for admin apps.
- Enable Let's Encrypt TLS directly in Caddy.
- Move secrets to Vault/Docker secrets, add rate limiting and nonce-based CSP.
- Scale horizontally with load balancer + multiple FastAPI replicas.

## Quick Command Reminders
- `terraform apply` — provision infrastructure.
- `docker-compose up -d` — run full stack locally.
- `curl http://localhost:8080/health` — verify API health.
- `docker-compose logs -f fastapi-app` — tail application logs.
- `scripts/backup-data.sh` — run point-in-time backup.

Keep this page open on your second monitor or print a copy for rapid recall.
