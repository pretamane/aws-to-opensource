# Architecture Deep Dive

## Purpose
A cost-optimized, production-ready platform migrating from AWS EKS (~$330/mo) to EC2 + open-source (~$30/mo) with full feature parity, defense-in-depth security, and complete observability.

## Layered Architecture
- Edge & Security: Caddy (+ Cloudflared) as single entry, security headers, Basic Auth, static site
- Application: FastAPI with background tasks, Prometheus instrumentation, health endpoints
- Data: PostgreSQL with JSONB + GIN, PL/pgSQL functions, connection pooling
- Storage: MinIO for S3-compatible objects (data, backups, logs)
- Search: Meilisearch for full-text, filters, relevance, typo tolerance
- Observability: Prometheus, Grafana, Loki, Promtail, Alertmanager, Blackbox, Node Exporter
- Automation: Terraform (VPC, EC2, SG, IAM, EIP, user-data), Docker Compose, scripts

## Topology (high-level)
```
Internet → Caddy (:8080) → FastAPI (8000)
                               ├─ PostgreSQL (5432)
                               ├─ MinIO API (9000)
                               └─ Meilisearch (7700)

Prometheus → scrapes FastAPI/MinIO/Blackbox/Node Exporter
Promtail → pushes logs → Loki → Grafana dashboards
Alertmanager → notifications (routes)
```

## Networking & Routing
- One exposed edge (Caddy), all other containers inside `app-network` bridge
- Path-based routing with subpath fixes (e.g., `uri strip_prefix /minio`)
- Healthchecks ensure dependency readiness before app starts

## Data & Persistence
- Volumes: postgres-data, meilisearch-data, minio-data, uploads-data, processed-data, logs-data, grafana-data, prometheus-data, loki-data, pgadmin-data
- Backups: daily archives + optional S3 sync

## Security Posture
- Caddy security headers (HSTS, CSP, XFO, nosniff), Basic Auth on admin UIs
- AWS IAM role: SES + optional S3 access; SSM Session Manager enabled
- Encrypted EBS, restricted security groups (80/443/22), IMDSv2 required

## Observability Strategy
- Custom business metrics: contact submissions, document uploads, search queries
- HTTP metrics: request rate, latency histogram, error ratio
- Logs: structured JSON from FastAPI, Caddy access logs → Loki via Promtail
- Blackbox synthetic probes on key endpoints

## Migration Principles
- Replace AWS managed services with open-source while preserving semantics (e.g., atomic counters in Postgres, S3 API in MinIO)
- Keep portability (same container images move to Kubernetes if needed)
- Optimize for cost without sacrificing production hygiene
