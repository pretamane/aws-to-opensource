# Tooling & Automation

This stack demonstrates end-to-end automation, from infrastructure provisioning to daily operations. Use these notes to highlight DevOps maturity and operational readiness.

## Infrastructure as Code (Terraform)
- **Location**: `terraform-ec2/`
- **Purpose**: Replace seven Terraform modules from the EKS-era with a focused EC2-only deployment.
- **Key Resources**:
  - VPC, subnet, route table, internet gateway, security groups
  - EC2 instance (t3.medium by default) with encrypted root volume
  - Elastic IP (optional), IAM role for SES/S3/SSM access
  - User-data bootstrap script to self-configure the instance
- **Talking Point**: Shows ability to right-size infrastructure and automate provisioning.

## Container Orchestration (Docker Compose)
- **Location**: `docker-compose/docker-compose.yml`
- **Highlights**:
  - Defines 15+ services with health checks, restart policies, and dependency chains
  - Uses named volumes for data durability (`postgres-data`, `minio-data`, etc.)
  - Encapsulates security-critical routing and logging configuration for Caddy
- **Talking Point**: Demonstrates production-ready Compose usage (health checks, metrics labels, environment variables).

## Configuration Bundles
- **Caddy**: `docker-compose/config/caddy/Caddyfile` — security headers, Basic Auth, path routing
- **Prometheus**: `docker-compose/config/prometheus/{prometheus.yml,alert-rules.yml}` — scrape jobs, alert logic
- **Grafana**: `docker-compose/config/grafana/` — dashboard provisioning and data sources
- **Loki & Promtail**: `docker-compose/config/loki/loki-config.yml`, `docker-compose/config/promtail/promtail-config.yml`
- **Blackbox Exporter**: `docker-compose/config/blackbox/blackbox.yml` — synthetic probe definitions

## Scripts & Automation
- **Deployment**:
  - `scripts/deploy-opensource.sh` — build + deploy the full stack
  - `scripts/setup-ec2.sh` — configure a fresh EC2 instance (packages, Docker, repo)
- **Operations**:
  - `scripts/backup-data.sh` — archive PostgreSQL, MinIO, Prometheus data
  - `scripts/monitor-deployment.sh` — health check loop with curl/docker stats
  - `scripts/health-check.sh` — quick verification of `/health` endpoint
- **Security & Maintenance**:
  - `scripts/security-cleanup.sh`, `scripts/secure-deploy.sh` — hardening steps
  - `scripts/update-credentials-ec2.sh` — rotate secrets safely

## Documentation & Runbooks
- **Guides**: `docs/guides/QUICK_START.md`, `docs/deployment/IMPLEMENTATION_SUMMARY.md`
- **Status Reports**: `docs/status-reports/` capture deployment outcomes and incident retrospectives.
- **Interview Prep**: Existing `docs/interview-prep/` plus this folder provide layer-by-layer explanations.

## Testing & Validation
- **Load Testing**: Scripts referencing `k6` for performance validation (`README.md` instructions)
- **Health Monitoring**: `curl` endpoints (`/health`, `/metrics`) and Grafana dashboards
- **Repeatability**: Everything runs locally with `docker-compose up -d` for quick demos.

Highlighting these tools underscores operational excellence: you can provision, deploy, monitor, and recover the system with repeatable automation.
