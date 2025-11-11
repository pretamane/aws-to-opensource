# AWS-to-OpenSource Migration - Complete Index

**Quick Navigation Guide for the aws-to-opensource Repository**

---

## Start Here

### For First-Time Deployment
1. Read: [QUICK_START.md](QUICK_START.md) - 15-minute deployment guide
2. Follow: Steps in quick start
3. Access: Your application at http://your-ec2-ip

### For Understanding the Migration
1. Read: [MIGRATION_PLAN.md](MIGRATION_PLAN.md) - Complete strategy
2. Review: [MIGRATION_SUMMARY.md](MIGRATION_SUMMARY.md) - Implementation details
3. Check: [IMPLEMENTATION_COMPLETE.md](IMPLEMENTATION_COMPLETE.md) - Final status

### For Detailed Deployment
1. Read: [docs/EC2_DEPLOYMENT_GUIDE.md](docs/EC2_DEPLOYMENT_GUIDE.md)
2. Follow: Step-by-step instructions
3. Troubleshoot: Using troubleshooting section

---

## Documentation Index

### Primary Docs (Start Here)
| Document | Purpose | Lines | Read Time |
|----------|---------|-------|-----------|
| [README.md](README.md) | Project overview | 600 | 5 min |
| [QUICK_START.md](QUICK_START.md) | Fast deployment | 400 | 3 min |
| [MIGRATION_PLAN.md](MIGRATION_PLAN.md) | Complete strategy | 2,500 | 20 min |

### Implementation Docs
| Document | Purpose | Lines | Read Time |
|----------|---------|-------|-----------|
| [MIGRATION_SUMMARY.md](MIGRATION_SUMMARY.md) | Implementation overview | 600 | 5 min |
| [IMPLEMENTATION_COMPLETE.md](IMPLEMENTATION_COMPLETE.md) | Final status | 400 | 3 min |
| [MIGRATION_COMPLETE_SUMMARY.txt](MIGRATION_COMPLETE_SUMMARY.txt) | Visual summary | 300 | 2 min |

### Deployment Guides
| Document | Purpose | Lines | Read Time |
|----------|---------|-------|-----------|
| [docs/EC2_DEPLOYMENT_GUIDE.md](docs/EC2_DEPLOYMENT_GUIDE.md) | Detailed deployment | 800 | 10 min |

---

## Code Index

### Infrastructure (Terraform)
```
terraform-ec2/
 main.tf                      # EC2 instance, VPC, security groups
 variables.tf                 # Configuration parameters
 user-data.sh                 # Bootstrap script
 terraform.tfvars.example     # Configuration template
```

**Key Resources:**
- VPC and subnet
- EC2 t3.medium instance
- Security group (HTTP, HTTPS, SSH)
- IAM role with SES permissions
- Elastic IP (optional)

### Application Stack (Docker Compose)
```
docker-compose/
 docker-compose.yml           # 9-service orchestration
 env.example                  # Environment configuration
 config/
    caddy/Caddyfile         # Reverse proxy rules
    prometheus/prometheus.yml # Metrics collection
    loki/loki-config.yml    # Log aggregation
    promtail/promtail-config.yml # Log shipping
    grafana/provisioning/   # Dashboard auto-config
 init-scripts/
     postgres/01-init-schema.sql # Database schema
```

**Services:**
1. fastapi-app - Main application
2. postgresql - Database
3. meilisearch - Search engine
4. minio - Object storage
5. caddy - Reverse proxy
6. prometheus - Metrics
7. grafana - Dashboards
8. loki - Log aggregation
9. promtail - Log shipping

### Application Code
```
docker/api/
 app_opensource.py            # Main application (4.0.0)
 Dockerfile.opensource        # Container image
 requirements.opensource.txt  # Python dependencies
 shared/
     database_service_postgres.py   # PostgreSQL service
     search_service_meilisearch.py  # Meilisearch service
     storage_service_minio.py       # MinIO service
```

### Automation Scripts
```
scripts/
 deploy-opensource.sh         # Complete deployment automation
 setup-ec2.sh                 # EC2 instance setup
 backup-data.sh               # Automated backups
 health-check.sh              # Health verification
```

---

## Service Configuration Index

### Caddy (Reverse Proxy)
- **Config:** `docker-compose/config/caddy/Caddyfile`
- **Purpose:** Route traffic to services, HTTPS termination
- **Ports:** 80 (HTTP), 443 (HTTPS)
- **Routes:**
  - `/` → FastAPI app
  - `/grafana` → Grafana dashboard
  - `/prometheus` → Prometheus metrics
  - `/meilisearch` → Search console
  - `/minio` → Storage console

### PostgreSQL (Database)
- **Schema:** `docker-compose/init-scripts/postgres/01-init-schema.sql`
- **Service:** `docker/api/shared/database_service_postgres.py`
- **Tables:**
  - `contact_submissions` - Contact form data
  - `documents` - Document metadata
  - `website_visitors` - Visitor counter
  - `analytics_events` - Analytics data

### Meilisearch (Search)
- **Service:** `docker/api/shared/search_service_meilisearch.py`
- **Index:** `documents`
- **Features:** Full-text search, typo tolerance, filtering, sorting

### MinIO (Storage)
- **Service:** `docker/api/shared/storage_service_minio.py`
- **API:** S3-compatible
- **Buckets:**
  - `pretamane-data` - Main data
  - `pretamane-backup` - Backups
  - `pretamane-logs` - Log archives

### Prometheus (Metrics)
- **Config:** `docker-compose/config/prometheus/prometheus.yml`
- **Scrape Targets:**
  - fastapi-app:9091 - Application metrics
  - postgresql:5432 - Database metrics
  - meilisearch:7700 - Search metrics
  - minio:9000 - Storage metrics
  - grafana:3000 - Dashboard metrics

### Grafana (Dashboards)
- **Provisioning:** `docker-compose/config/grafana/provisioning/`
- **Datasources:** Prometheus, Loki
- **Default Login:** admin / admin123
- **Dashboards:** Application, Business, System metrics

### Loki (Logging)
- **Config:** `docker-compose/config/loki/loki-config.yml`
- **Storage:** Local filesystem
- **Retention:** 30 days
- **Sources:** Container logs, application logs

---

## Deployment Workflow Index

### Local Testing
```
1. Configure:  cp docker-compose/env.example docker-compose/.env
2. Edit:       nano docker-compose/.env
3. Start:      cd docker-compose && docker-compose up -d
4. Test:       curl http://localhost:8000/health
5. Access:     open http://localhost:8000/docs
6. Stop:       docker-compose down
```

### EC2 Deployment
```
1. Configure:  cd terraform-ec2 && cp terraform.tfvars.example terraform.tfvars
2. Edit:       nano terraform.tfvars
3. Deploy:     terraform init && terraform apply
4. Wait:       For bootstrap to complete (~5 minutes)
5. Upload:     Use scripts/deploy-opensource.sh
6. Access:     http://<ec2-ip>
```

### Automated Deployment
```
1. Run:        ./scripts/deploy-opensource.sh
2. Wait:       20-30 minutes
3. Access:     URLs displayed at end
```

---

## Cost Analysis Index

### Monthly Cost Breakdown
| Component | Cost |
|-----------|------|
| EC2 t3.medium | $30.37 |
| EBS 30GB GP3 | $2.40 |
| Elastic IP | $0.00 |
| SES (< 62k emails) | $0.00 |
| Data Transfer | $0.00 |
| **TOTAL** | **$32.77** |

### Savings Calculation
| Period | EKS | EC2 | Savings |
|--------|-----|-----|---------|
| Day | $11 | $1.10 | $9.90 (90%) |
| Week | $77 | $7.70 | $69.30 (90%) |
| Month | $330 | $33 | $297 (90%) |
| Year | $3,960 | $396 | $3,564 (90%) |

---

## API Endpoint Index

### Core Endpoints
- `GET /` - API information
- `GET /health` - Health check with service status
- `GET /docs` - Swagger UI documentation
- `GET /redoc` - ReDoc documentation
- `GET /metrics` - Prometheus metrics

### Contact Endpoints
- `POST /contact` - Submit contact form
- `GET /stats` - Visitor statistics

### Document Endpoints
- `POST /documents/upload` - Upload document
- `POST /documents/search` - Search documents
- `GET /contacts/{id}/documents` - Get contact's documents

### Analytics Endpoints
- `GET /analytics/insights` - System analytics
- `GET /admin/system-info` - System information

---

## Monitoring Index

### Metrics (Prometheus)
- **URL:** http://your-ec2-ip/prometheus
- **Metrics:**
  - `http_requests_total` - Request counter
  - `http_request_duration_seconds` - Response time
  - `contact_submissions_total` - Contact form submissions
  - `document_uploads_total` - Document uploads
  - `document_search_queries_total` - Search queries
  - `website_visitor_count` - Visitor counter

### Dashboards (Grafana)
- **URL:** http://your-ec2-ip/grafana
- **Login:** admin / admin123
- **Dashboards:**
  - Application Performance
  - Business Metrics
  - System Health
  - Container Stats

### Logs (Loki)
- **URL:** Via Grafana → Explore → Loki
- **Labels:**
  - `{job="docker"}` - All container logs
  - `{container_name="fastapi-app"}` - App logs
  - `{container_name="postgresql"}` - DB logs

---

## Troubleshooting Index

### Common Issues

**Services Won't Start**
- Check: `docker-compose logs`
- Fix: `docker-compose restart`
- Guide: [docs/EC2_DEPLOYMENT_GUIDE.md](docs/EC2_DEPLOYMENT_GUIDE.md#troubleshooting)

**Database Connection Error**
- Check: `docker-compose logs postgresql`
- Fix: Verify DATABASE_URL in .env
- Restart: `docker-compose restart postgresql fastapi-app`

**Search Not Working**
- Check: `curl http://localhost:7700/health`
- Fix: Verify MEILI_MASTER_KEY in .env
- Restart: `docker-compose restart meilisearch fastapi-app`

**Out of Disk Space**
- Check: `df -h`
- Clean: `docker system prune -af`
- Expand: AWS Console → EBS volume → Modify

**High Memory Usage**
- Check: `docker stats`
- Fix: Scale up to t3.large
- Guide: [docs/EC2_DEPLOYMENT_GUIDE.md](docs/EC2_DEPLOYMENT_GUIDE.md#scaling)

---

## File Organization

### By Purpose

**Documentation (Read These First)**
- QUICK_START.md
- README.md
- MIGRATION_PLAN.md
- docs/EC2_DEPLOYMENT_GUIDE.md

**Infrastructure (Deploy This)**
- terraform-ec2/main.tf
- terraform-ec2/variables.tf
- terraform-ec2/user-data.sh

**Application (Configure This)**
- docker-compose/docker-compose.yml
- docker-compose/env.example
- docker-compose/config/

**Code (Modify This)**
- docker/api/app_opensource.py
- docker/api/shared/*.py
- docker-compose/init-scripts/

**Scripts (Run These)**
- scripts/deploy-opensource.sh
- scripts/setup-ec2.sh
- scripts/health-check.sh
- scripts/backup-data.sh

### By Technology

**Terraform**
- terraform-ec2/main.tf
- terraform-ec2/variables.tf
- terraform-ec2/user-data.sh
- terraform-ec2/terraform.tfvars.example

**Docker**
- docker-compose/docker-compose.yml
- docker/api/Dockerfile.opensource

**PostgreSQL**
- docker-compose/init-scripts/postgres/01-init-schema.sql
- docker/api/shared/database_service_postgres.py

**Meilisearch**
- docker/api/shared/search_service_meilisearch.py

**MinIO**
- docker/api/shared/storage_service_minio.py

**Monitoring**
- docker-compose/config/prometheus/prometheus.yml
- docker-compose/config/grafana/provisioning/
- docker-compose/config/loki/loki-config.yml
- docker-compose/config/promtail/promtail-config.yml

**Reverse Proxy**
- docker-compose/config/caddy/Caddyfile

---

## Quick Links

### Deployment
- [15-Minute Quick Start](QUICK_START.md)
- [Full Deployment Guide](docs/EC2_DEPLOYMENT_GUIDE.md)
- [Automated Deployment Script](scripts/deploy-opensource.sh)

### Configuration
- [Terraform Variables Example](terraform-ec2/terraform.tfvars.example)
- [Environment Variables Example](docker-compose/env.example)
- [Docker Compose Configuration](docker-compose/docker-compose.yml)

### Monitoring
- Grafana: http://your-ec2-ip/grafana
- Prometheus: http://your-ec2-ip/prometheus
- [Monitoring Setup Guide](docs/EC2_DEPLOYMENT_GUIDE.md#monitoring)

### Maintenance
- [Backup Script](scripts/backup-data.sh)
- [Health Check Script](scripts/health-check.sh)
- [Troubleshooting Guide](docs/EC2_DEPLOYMENT_GUIDE.md#troubleshooting)

---

## Key Commands

### Deployment
```bash
# Local test
cd docker-compose && docker-compose up -d

# EC2 deploy
cd terraform-ec2 && terraform apply

# Automated
./scripts/deploy-opensource.sh
```

### Monitoring
```bash
# Health check
./scripts/health-check.sh

# View logs
docker-compose logs -f

# Resource usage
docker stats
```

### Maintenance
```bash
# Backup
./scripts/backup-data.sh

# Update
docker-compose pull && docker-compose up -d

# Restart
docker-compose restart
```

---

## Cost Summary

| Metric | Value |
|--------|-------|
| **Monthly Cost** | ~$30-35 |
| **vs. EKS Stack** | $330 |
| **Savings** | 90% ($300/month) |
| **Annual Savings** | $3,600 |
| **Break-even** | 1 week |

---

## Technology Stack

| Layer | Technology | Replaces |
|-------|------------|----------|
| **Compute** | EC2 t3.medium | EKS cluster + nodes |
| **Database** | PostgreSQL 16 | DynamoDB |
| **Search** | Meilisearch | OpenSearch |
| **Storage** | MinIO | S3 + EFS |
| **Proxy** | Caddy v2 | ALB |
| **Metrics** | Prometheus | CloudWatch |
| **Dashboards** | Grafana | CloudWatch |
| **Logs** | Loki | CloudWatch Logs |
| **Email** | SES | SES (kept) |

---

## Status Summary

| Category | Status |
|----------|--------|
| **Implementation** |  Complete |
| **Documentation** |  Complete |
| **Testing** | ⏳ Pending |
| **Deployment** |  Ready |
| **Cost Goal** |  Achieved (90% reduction) |

---

## What to Show in Portfolio

### Dual Architecture Approach
1. **EKS Version** (realistic-demo-pretamane/)
   - Shows: Enterprise AWS expertise
   - Cost: $330/month
   - Complexity: High (74+ resources)

2. **EC2 Version** (aws-to-opensource/)
   - Shows: Cost optimization skills
   - Cost: $30/month
   - Complexity: Low (1 EC2 instance)

### Migration Experience
- Service replacement planning
- Technology evaluation
- Cost-benefit analysis
- Implementation execution
- Documentation creation

---

## Access After Deployment

Replace `<ec2-ip>` with your instance IP from:
```bash
cd terraform-ec2 && terraform output -raw instance_public_ip
```

**URLs:**
- Application: http://your-ec2-ip/
- API Docs: http://your-ec2-ip/docs
- Grafana: http://your-ec2-ip/grafana
- Prometheus: http://your-ec2-ip/prometheus
- Meilisearch: http://your-ec2-ip/meilisearch
- MinIO: http://your-ec2-ip/minio

**SSH:**
```bash
ssh -i pretamane-key.pem ubuntu@<ec2-ip>
```

**SSM (no key needed):**
```bash
aws ssm start-session --target <instance-id>
```

---

## Repository Statistics

### Code Metrics
- **New Files:** 25+
- **Lines of Code:** ~8,000
- **Documentation:** ~5,000 lines
- **Configuration:** ~1,000 lines
- **Application Code:** ~900 lines
- **Infrastructure:** ~600 lines
- **Scripts:** ~500 lines

### Service Count
- **Docker Containers:** 9
- **Terraform Resources:** ~10
- **AWS Services Used:** 3 (EC2, EBS, SES)
- **Open-Source Services:** 7

---

## Next Actions

### Today
1.  Implementation complete
2. ⏳ Test locally (5 min)
3. ⏳ Deploy to EC2 (15 min)
4. ⏳ Verify functionality (10 min)

### This Week
1. ⏳ Configure HTTPS
2. ⏳ Set up backups
3. ⏳ Load testing
4. ⏳ Security review

### This Month
1. ⏳ Create demo video
2. ⏳ Write blog post
3. ⏳ Update portfolio
4. ⏳ Interview prep

---

**Last Updated:** October 18, 2025  
**Version:** 4.0.0  
**Status:** Implementation Complete - Ready for Deployment  
**Cost:** ~$30/month (90% savings vs EKS)

---

**Ready to deploy your cost-optimized cloud application!**


