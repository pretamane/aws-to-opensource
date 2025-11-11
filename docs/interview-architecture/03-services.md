# Service-by-Service Breakdown

Use this reference to explain what each container/service does, how it starts, and how it interacts with the rest of the stack.

| Service | Role | Key Dependencies | Defined In |
|---------|------|------------------|------------|
| **Caddy** | Edge proxy, TLS offload, security headers, static site hosting | FastAPI, Grafana, Prometheus, MinIO, Meilisearch, pgAdmin, Loki, file system (`pretamane-website`) | `docker-compose/docker-compose.yml`, `docker-compose/config/caddy/Caddyfile` |
| **Cloudflared** | Optional Cloudflare tunnel for remote access without exposing IP | Caddy | `docker-compose/docker-compose.yml` |
| **FastAPI (fastapi-app)** | Main application API, document processing, metrics emitter | PostgreSQL, Meilisearch, MinIO, Prometheus | `docker-compose/docker-compose.yml`, `docker/api/app_opensource.py` |
| **PostgreSQL** | Relational database replacing DynamoDB, stores core records and analytics | Persistent volume `postgres-data`, init scripts | `docker-compose/docker-compose.yml`, `docker-compose/init-scripts/postgres/` |
| **Meilisearch** | Full-text search replacing OpenSearch | Persistent volume `meilisearch-data` | `docker-compose/docker-compose.yml`, `docker/api/shared/search_service_meilisearch.py` |
| **MinIO** | S3-compatible object storage replacing S3/EFS | Persistent volume `minio-data`, MinIO setup job | `docker-compose/docker-compose.yml`, `docker/api/shared/storage_service_minio.py` |
| **MinIO Setup (minio-setup)** | One-time bucket creation and ACL configuration | MinIO service | `docker-compose/docker-compose.yml` |
| **Prometheus** | Metrics collection, alert rule evaluation | FastAPI `/metrics`, MinIO, Node Exporter, Blackbox Exporter | `docker-compose/docker-compose.yml`, `docker-compose/config/prometheus/` |
| **Grafana** | Dashboards and visualization, provisioned with datasources | Prometheus, Loki | `docker-compose/docker-compose.yml`, `docker-compose/config/grafana/` |
| **Loki** | Centralized log store (structured JSON, FastAPI logs) | Promtail | `docker-compose/docker-compose.yml`, `docker-compose/config/loki/loki-config.yml` |
| **Promtail** | Log shipper that tails application + Caddy logs and pushes to Loki | FastAPI logs (`logs-data`), Caddy logs (`caddy-logs`) | `docker-compose/docker-compose.yml`, `docker-compose/config/promtail/promtail-config.yml` |
| **Alertmanager** | Alert routing and notification fan-out | Prometheus | `docker-compose/docker-compose.yml`, `docker-compose/config/alertmanager/` |
| **Blackbox Exporter** | Synthetic monitoring for HTTP probes | Prometheus | `docker-compose/docker-compose.yml`, `docker-compose/config/blackbox/blackbox.yml` |
| **Node Exporter** | Host-level metrics (CPU, memory, disk) | Host file mounts | `docker-compose/docker-compose.yml` |
| **pgAdmin** | Database administration UI (routed under `/pgadmin`) | PostgreSQL | `docker-compose/docker-compose.yml` |
| **Alerting & Backup Scripts** | Operational automation (backup, deploy, monitoring) | SSH, Docker CLI | `scripts/` directory |

## Dependency Highlights

- **FastAPI → PostgreSQL**: Connection pool defined in `PostgreSQLService` for CRUD operations and analytics.
- **FastAPI → Meilisearch**: Indexing and querying documents via `MeilisearchService` for search endpoints.
- **FastAPI → MinIO**: Upload/download files using the S3-compatible API in `MinIOStorageService`.
- **Promtail → Loki → Grafana**: Structured logs are tailed from application volumes, stored in Loki, and visualized in Grafana panels.
- **Prometheus → Alertmanager**: Metrics are scraped every 10s; alert rules trigger notifications through Alertmanager.
- **Caddy → All Services**: Acts as choke point; applies authentication and security before traffic reaches backend services.

Learning these pairings lets you answer "how do components talk to each other?" without hesitation.
