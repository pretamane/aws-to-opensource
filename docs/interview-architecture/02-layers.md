# Technology Layers Explained

Each layer uses open-source tooling to replace an AWS managed service while keeping enterprise-grade capabilities. Use this file to articulate how the stack is organized and why each tool was chosen.

## 1. Edge & Security Layer
- **Components**: Caddy reverse proxy, Cloudflared tunnel (optional)
- **Responsibilities**:
  - Single entry point on ports 80/443 externally, 8080 locally
  - Path-based routing to every internal service
  - Security headers (HSTS, CSP, X-Frame-Options, X-Content-Type-Options)
  - Basic Auth for admin consoles (Grafana, Prometheus, MinIO, pgAdmin, Loki)
  - Static asset hosting for the marketing site (`pretamane-website`)
- **Key Config**: `docker-compose/config/caddy/Caddyfile`
- **Interview Angle**: Highlights defense-in-depth, trade-offs (Basic Auth today, OAuth2/SSO roadmap).

## 2. Application Layer
- **Components**: FastAPI application container (`fastapi-app`), background tasks
- **Responsibilities**:
  - REST API endpoints for contact forms, uploads, search, analytics
  - Document ingestion pipeline and enrichment
  - Prometheus metrics exposure on `/metrics`
  - Health checks on `/health`
- **Key Files**:
  - `docker/api/app_opensource.py`
  - `docker/api/components/` (background tasks, processing)
  - `docker/api/models/` (Pydantic schemas)
- **Interview Angle**: Demonstrates application refactor for open-source services and instrumentation.

## 3. Data Layer (Relational)
- **Components**: PostgreSQL 16 container with initialization scripts
- **Responsibilities**:
  - Stores contacts, documents, analytics, visitor counters
  - JSONB columns + GIN indexes for flexible metadata
  - PL/pgSQL functions for atomic counters and triggers for timestamps
- **Key Files**:
  - `docker-compose/init-scripts/postgres/01-init-schema.sql`
  - `docker/api/shared/database_service_postgres.py`
- **Interview Angle**: Migration story from DynamoDB to PostgreSQL, hybrid schema approach.

## 4. Object Storage Layer
- **Components**: MinIO server (`minio`) + setup job (`minio-setup`)
- **Responsibilities**:
  - Stores raw uploads, processed documents, backups using S3 API
  - Provides web console on `/minio`
  - Generates presigned URLs for controlled access
- **Key Files**:
  - `docker/api/shared/storage_service_minio.py`
  - `docker-compose/docker-compose.yml` volumes (`minio-data`, `uploads-data`, `processed-data`)
- **Interview Angle**: Cost savings vs S3, portability through S3 compatibility.

## 5. Search Layer
- **Components**: Meilisearch (`meilisearch` container)
- **Responsibilities**:
  - Full-text search with typo tolerance
  - Indexing document metadata for rapid filtering
  - Replaces AWS OpenSearch functionality
- **Key Files**:
  - `docker/api/shared/search_service_meilisearch.py`
  - `docker-compose/docker-compose.yml` Meilisearch service block
- **Interview Angle**: Discuss search relevance configuration, indexing strategies, performance.

## 6. Observability Layer
- **Components**:
  - **Metrics**: Prometheus, Node Exporter, Blackbox Exporter
  - **Dashboards**: Grafana (pre-provisioned)
  - **Logs**: Loki + Promtail
  - **Alerts**: Alertmanager
- **Responsibilities**:
  - Collect infrastructure + business metrics
  - Centralize logs for Caddy and FastAPI
  - Synthetic monitoring via HTTP probes
  - Alert routing based on severity
- **Key Files**:
  - `docker-compose/config/prometheus/prometheus.yml`
  - `docker-compose/config/grafana/`
  - `docker-compose/config/loki/loki-config.yml`
  - `docker-compose/config/promtail/promtail-config.yml`
- **Interview Angle**: Three pillars of observability, custom metrics, alerting strategy.

## 7. Automation & Infrastructure Layer
- **Components**: Terraform (`terraform-ec2`), Docker Compose, shell scripts (`scripts/`)
- **Responsibilities**:
  - Provision VPC, subnet, EC2 instance, security groups, IAM roles, Elastic IP
  - Bootstrap EC2 with Docker and repo via user-data script
  - One-command deployment & maintenance routines
- **Key Files**:
  - `terraform-ec2/main.tf`
  - `terraform-ec2/user-data.sh`
  - `docker-compose/docker-compose.yml`
  - `scripts/deploy-opensource.sh`, `scripts/backup-data.sh`
- **Interview Angle**: Infrastructure as Code, automation, cost control, Day-2 operations.

## 8. Security Layer (Cross-Cutting)
- **Controls**:
  - Security groups restricting ingress to HTTP/HTTPS/SSH (`terraform-ec2/main.tf`)
  - Caddy security headers and Basic Auth (`docker-compose/config/caddy/Caddyfile`)
  - IAM role with least privilege for SES + S3 (`terraform-ec2/main.tf`)
  - Encrypted EBS volumes and SSM Session Manager support (`terraform-ec2/main.tf`)
  - Environment variable secrets and MinIO access keys (`docker-compose/env.example`)
- **Roadmap**:
  - Upgrade to OAuth2/OIDC, nonce-based CSP, rate limiting, Vault integration
- **Interview Angle**: Defense-in-depth story and clear production hardening path.

Use this layered view to answer "where does this component live?" and "what problem does it solve?" questions.
