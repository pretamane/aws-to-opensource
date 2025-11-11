# Operational Flows

These end-to-end stories help you describe how the system behaves in real life. Practice walking through each flow verbally.

## 1. Contact Submission + Document Upload

1. **User submits form** on the portfolio site (`pretamane-website`) with optional file attachments.
2. **Caddy** receives `POST /contact` and forwards it to `fastapi-app:8000` while applying CSP, HSTS, and logging the request.
3. **FastAPI** validates payload with Pydantic models, records Prometheus metrics (`contact_submissions_total`, `http_requests_total`).
4. **PostgreSQLService** writes a new record into `contact_submissions` (JSONB column stores flexible metadata).
5. **MinIOStorageService** uploads documents to the `pretamane-data` bucket (S3-compatible) and stores metadata (size, content type).
6. **Background tasks** trigger document processing (text extraction, tagging) and re-index search content.
7. **MeilisearchService** indexes document metadata and extracted text for future searches.
8. **EmailService** (AWS SES) notifies stakeholders of the new submission.
9. **Prometheus** scrapes `/metrics` for updated counters; **Grafana** dashboards refresh automatically.
10. **Loki** ingests structured logs (via Promtail) for traceability.

## 2. Document Search Experience

1. User issues a search via the UI or API (`POST /documents/search`).
2. Request flows through **Caddy** to **FastAPI**.
3. **FastAPI** records request latency using the Prometheus histogram middleware.
4. **MeilisearchService** executes typo-tolerant search, applies filters (e.g., document type, contact ID).
5. Results include metadata from PostgreSQL + MinIO (document size, processing status).
6. Response returned to client; metrics updated for query count and latency.
7. **Grafana dashboards** visualize search volume trends; logs captured for auditing.

## 3. Monitoring & Alerting Loop

1. **Prometheus** scrapes metrics from all instrumented services every 10 seconds (FastAPI, MinIO, Node Exporter, Blackbox Exporter).
2. **Alert rules** (e.g., high 4xx rate, request latency spikes) evaluate continuously.
3. When thresholds are exceeded, **Alertmanager** fires notifications (email/Slack/PagerDuty as configured).
4. Engineers investigate in **Grafana** (correlate metrics, examine dashboards) and **Loki** (view structured logs).
5. **Blackbox Exporter** provides synthetic HTTP checks to detect end-user issues even when API metrics look healthy.

## 4. Deployment & Backup Pipeline

1. **Terraform (`terraform-ec2`)** provisions networking (VPC, subnet), security groups, IAM roles, and an EC2 instance with user-data bootstrap.
2. User runs `scripts/setup-ec2.sh` or `terraform apply` to bring up infrastructure.
3. **User-data script** installs Docker, clones repository, and launches the Compose stack automatically.
4. For updates, run `scripts/deploy-opensource.sh` which:
   - Builds/pushes new application images (if needed)
   - Syncs code to the EC2 instance via SSH/rsync
   - Restarts impacted services using Docker Compose
5. **Backups**: `scripts/backup-data.sh` archives PostgreSQL dumps, MinIO objects, and metrics data for disaster recovery.
6. **Monitoring**: `scripts/monitor-deployment.sh` or Grafana dashboards confirm post-deploy health.

## 5. Incident Troubleshooting Playbook

1. Receive alert (e.g., high HTTP latency).
2. Check **Grafana** to identify which endpoint or service is impacted.
3. Drill into **Prometheus** queries for historical trends and correlated metrics.
4. Inspect **Loki** logs filtered by timeframe and service to find stack traces or errors.
5. If storage-related, use **MinIO Console** (`/minio`) to confirm object availability; if database-related, access **pgAdmin** (`/pgadmin`).
6. Apply fix (restart service, adjust configuration) via `docker-compose` commands.
7. Document findings in `docs/status-reports/` for future reference.

Knowing these flows helps transform static architecture facts into compelling narratives.
