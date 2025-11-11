# Architecture Map

## High-Level Summary

- **Goal**: Deliver a production-grade document management platform that migrated from an AWS EKS stack (~$330/mo) to an EC2 + open-source stack (~$30/mo) without sacrificing features.
- **Strategy**: Run the entire platform on a single EC2 instance using Docker Compose, backed by Terraform-provisioned infrastructure and a defense-in-depth security posture at the edge (Caddy).

## Component Topology

```
                         Internet / Users
                                 │
                                 ▼
                        Caddy Reverse Proxy (:8080)
            ┌──────────────┬──────────────┬──────────────┬───────────────┐
            │              │              │               │               │
            ▼              ▼              ▼               ▼               ▼
      FastAPI (8000)   Grafana (3000) Prometheus (9090) MinIO Console  Meilisearch UI
            │                               │               │               │
            │                               ▼               ▼               ▼
            │                       Promtail → Loki   MinIO API (9000)  Meilisearch Core
            │                                │               │               │
            │                                ▼               │               │
            │                            Loki Storage        │               │
            │                                ▲               │               │
            │                                │               │               │
            ├───────────────┬───────────────┘               │               │
            ▼               ▼                               │               │
   PostgreSQL (5432)   MinIO API (9000)                      │               │
            │               │                               │               │
            ▼               ▼                               │               │
     Persistent Data   Object Storage                        │               │
                                                            │               │
                                          Prometheus Scrapes + Blackbox Probes
                                          │                                   
                                          ▼                                   
                                  Alertmanager (9093)                         
                                          │                                   
                                          ▼                                   
                                      Notifications                           
```

## Layered View

| Layer | Primary Components | Key Responsibilities |
|-------|--------------------|----------------------|
| Edge & Security | Caddy, Cloudflared | TLS termination, security headers, Basic Auth, Cloudflare tunnel |
| Application | FastAPI, Background tasks | API endpoints, document processing, business logic |
| Data | PostgreSQL | Relational data, JSONB metadata, functions, triggers |
| Search | Meilisearch | Full-text indexing and search with typo tolerance |
| Object Storage | MinIO | S3-compatible file storage and backups |
| Observability | Prometheus, Grafana, Loki, Promtail, Alertmanager, Blackbox Exporter, Node Exporter | Metrics, dashboards, alerting, log aggregation |
| Automation & Infrastructure | Terraform (`terraform-ec2`), Docker Compose (`docker-compose/docker-compose.yml`), Scripts (`scripts/`) | Provision EC2 + VPC, orchestrate containers, automate deployment/maintenance |

## AWS → Open-Source Replacements

| Original AWS Service | Replacement | Location |
|----------------------|-------------|----------|
| EKS + Node Groups | Docker Compose on EC2 | `docker-compose/docker-compose.yml` |
| DynamoDB | PostgreSQL 16 | `docker/api/shared/database_service_postgres.py` |
| OpenSearch | Meilisearch | `docker/api/shared/search_service_meilisearch.py` |
| S3 + EFS | MinIO + local volumes | `docker/api/shared/storage_service_minio.py`, Docker volumes |
| ALB | Caddy reverse proxy | `docker-compose/config/caddy/Caddyfile` |
| CloudWatch (metrics/logs) | Prometheus + Grafana + Loki | `docker-compose/config/prometheus/`, `docker-compose/config/loki/`, `docker-compose/config/grafana/` |
| NAT Gateway | Direct outbound internet access | Terraform networking (`terraform-ec2/main.tf`) |
| AWS WAF / Shield (planned) | Caddy security headers + Cloudflare tunnel | `docker-compose/config/caddy/Caddyfile` |

Use this map before diving into the detailed layer, service, and flow documents.
