# Cloud-Native Document Management Platform

> Tools and Scripts Location (VPN/Proxy)

The VPN/proxy helpers and GUIs were moved to user/system locations so they no longer depend on this repository:
- sing-box TUN control:
  - Start: ~/.local/bin/sing-on
  - Stop: ~/.local/bin/sing-off
  - Config: ~/.config/sing-box/config.json
- Tunnel URL helper: ~/.local/bin/get-tunnel-url
- Outline (GUI, Flatpak): flatpak run org.getoutline.OutlineClient
- Nekoray (GUI, sing-box core): ~/Applications/nekoray-4.0.1/run-nekoray.sh

Notes:
- AppImage “Cannot mount AppImage, check your FUSE setup” errors are avoided by using Outline (Flatpak) and Nekoray (ZIP) instead of AppImages.
## Open-Source Edition (EC2 + Docker Compose)

A **cost-optimized, production-ready** document processing system that achieves **90% cost savings** by replacing expensive AWS managed services with open-source alternatives while maintaining all functionality.

---

## What Changed from AWS EKS Version?

### Before (AWS EKS Stack)
- **Monthly Cost:** ~$330
- **Architecture:** EKS cluster, managed services
- **Services:** EKS, OpenSearch, DynamoDB, EFS, ALB, NAT Gateway
- **Complexity:** 74+ AWS resources, 7 Terraform modules

### After (Open-Source Stack)
- **Monthly Cost:** ~$30-35 (90% savings)
- **Architecture:** Single EC2 + Docker Compose
- **Services:** PostgreSQL, Meilisearch, MinIO, Caddy, Prometheus, Grafana
- **Simplicity:** 1 EC2 instance, minimal AWS footprint

---

## Technology Stack

```

                  AWS EC2 Instance                        
                 (t3.medium - $30/month)                 

                                                           
  Application:      FastAPI (Python 3.11)                
  Database:         PostgreSQL 16                         
  Search:           Meilisearch                           
  Storage:          MinIO (S3-compatible)                
  Reverse Proxy:    Caddy v2                             
  Monitoring:       Prometheus + Grafana                 
  Logging:          Loki + Promtail                      
  Email:            AWS SES (free tier)                  
                                                           

```

### Service Comparison

| Function | AWS Service | Open-Source Alternative | Savings |
|----------|-------------|------------------------|---------|
| **Orchestration** | EKS ($75/mo) | Docker Compose | $75/mo |
| **Database** | DynamoDB ($15/mo) | PostgreSQL | $15/mo |
| **Search** | OpenSearch ($60/mo) | Meilisearch | $60/mo |
| **Storage** | S3+EFS ($40/mo) | MinIO | $40/mo |
| **Load Balancer** | ALB ($20/mo) | Caddy | $20/mo |
| **Monitoring** | CloudWatch ($10/mo) | Prometheus+Grafana | $10/mo |
| **Networking** | NAT Gateway ($30/mo) | Direct routing | $30/mo |
| **Compute** | Node Groups ($80/mo) | t3.medium ($30/mo) | $50/mo |
| **TOTAL** | **~$330/mo** | **~$30/mo** | **~$300/mo** |

---

## Quick Start

### Prerequisites
1. AWS Account with:
   - AWS CLI configured
   - EC2 key pair created
   - SES verified email (optional)
2. Terraform installed (≥ 1.5.0)
3. Git

### Deploy in 5 Minutes

```bash
# 1. Clone repository
git clone <your-repo-url> aws-to-opensource
cd aws-to-opensource

# 2. Configure Terraform
cd terraform-ec2
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Edit with your settings

# 3. Deploy infrastructure
terraform init
terraform apply

# 4. Get instance IP
EC2_IP=$(terraform output -raw instance_public_ip)
SSH_KEY="your-key-name"  # From terraform.tfvars

# 5. Wait for bootstrap (check every 30 seconds)
ssh -i "$SSH_KEY.pem" ubuntu@$EC2_IP "tail -f /var/log/cloud-init-output.log"

# 6. Upload and start application
cd ../scripts
./deploy-opensource.sh

# 7. Access your application
echo "Application: http://$EC2_IP"
echo "API Docs:    http://$EC2_IP/docs"
echo "Grafana:     http://$EC2_IP/grafana"
```

---

## Features

### Business Features
- Contact form processing with analytics
- Multi-format document upload (17 file types)
- Full-text search with typo tolerance
- Real-time visitor tracking
- Email notifications
- Document intelligence and enrichment

### Technical Features
- PostgreSQL with JSON support (DynamoDB-like flexibility)
- Meilisearch for blazing-fast search (< 50ms)
- MinIO S3-compatible storage
- Prometheus metrics collection
- Grafana dashboards
- Structured logging with Loki
- Automatic HTTPS with Caddy

### DevOps Features
- Infrastructure as Code (Terraform)
- Container orchestration (Docker Compose)
- One-command deployment
- Automated backups
- Health monitoring
- Cost optimization

---

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | API information |
| `/health` | GET | Health check |
| `/docs` | GET | Swagger UI |
| `/metrics` | GET | Prometheus metrics |
| `/contact` | POST | Submit contact form |
| `/documents/upload` | POST | Upload document |
| `/documents/search` | POST | Search documents |
| `/contacts/{id}/documents` | GET | Get contact documents |
| `/analytics/insights` | GET | System analytics |
| `/stats` | GET | Visitor statistics |

---

## Architecture Details

### Service Ports

| Service | Internal Port | External URL | Purpose |
|---------|--------------|--------------|---------|
| FastAPI | 8000 | http://ip/ | Main application |
| PostgreSQL | 5432 | N/A (internal) | Database |
| Meilisearch | 7700 | http://ip/meilisearch | Search engine |
| MinIO API | 9000 | N/A (internal) | Object storage |
| MinIO Console | 9001 | http://ip/minio | Storage management |
| Prometheus | 9090 | http://ip/prometheus | Metrics |
| Grafana | 3000 | http://ip/grafana | Dashboards |
| Loki | 3100 | N/A (internal) | Log aggregation |
| Caddy | 80, 443 | N/A (proxy) | Reverse proxy |

### Data Persistence

All data is stored in `/data/` on the EC2 instance:

```
/data/
 postgresql/      # Database data
 meilisearch/     # Search indices
 minio/           # Object storage
 uploads/         # Document uploads
 processed/       # Processed files
 prometheus/      # Metrics data
 grafana/         # Dashboard configs
 loki/            # Log data
```

**Backup Strategy:**
- Daily snapshots of `/data` directory
- Automated backup to S3 (optional)
- Point-in-time recovery support

---

## Cost Breakdown

### Monthly Costs (Detailed)

```
EC2 t3.medium (2 vCPU, 4GB RAM)
- On-Demand:  $0.0416/hour × 730 hours    = $30.37
- Reserved:   $0.0249/hour × 730 hours    = $18.18  (1-year term)
- Spot:       $0.0125/hour × 730 hours    = $ 9.13  (risky for 24/7)

EBS Storage (30GB GP3)
- Storage:    30GB × $0.08/GB             = $ 2.40
- IOPS:       3,000 baseline (included)   = $ 0.00

Data Transfer
- First 100GB (free)                      = $ 0.00
- Additional (if needed)                  = $ 1-2

AWS SES (Email)
- First 62,000 emails/month (free)        = $ 0.00

Elastic IP (attached)                     = $ 0.00


TOTAL (On-Demand):                        = $32.77/month
TOTAL (Reserved 1-year):                  = $20.58/month
TOTAL (Spot - risky):                     = $11.53/month

```

### Annual Savings

| Deployment Model | Monthly | Annual | Savings vs EKS |
|-----------------|---------|--------|----------------|
| **EKS Original** | $330 | $3,960 | - |
| **EC2 On-Demand** | $33 | $396 | $3,564 (90%) |
| **EC2 Reserved** | $21 | $252 | $3,708 (93.6%) |

---

## Portfolio Value

### What This Demonstrates

1. **Cost Optimization**
   - Reduced infrastructure costs by 90%
   - Pragmatic technology selection
   - Budget-conscious engineering

2. **Technology Breadth**
   - PostgreSQL (relational database)
   - Meilisearch (modern search)
   - MinIO (distributed storage)
   - Prometheus/Grafana (observability)
   - Docker Compose (orchestration)
   - Terraform (IaC)

3. **Migration Experience**
   - Platform migration planning
   - Service replacement strategies
   - Database migration (NoSQL → SQL)
   - API compatibility layers
   - Zero-downtime transitions

4. **Real-World Skills**
   - Working with constraints (budget)
   - Making architectural trade-offs
   - Balancing features vs. cost
   - Production-ready implementations

### Interview Talking Points

**"This looks simpler than your EKS version - is it less impressive?"**

> "Not at all - it's arguably MORE impressive. I demonstrated both approaches:
> 
> 1. **EKS Version:** Shows I can build enterprise-grade AWS infrastructure with managed services when budget allows
> 2. **EC2 Version:** Shows I can achieve the same functionality at 10% of the cost using open-source tools
> 
> The EKS version proves I understand enterprise patterns. The EC2 version proves I can think like a startup engineer and optimize costs. Real companies need both skills - knowing when to use managed services vs. when to optimize for cost."

---

## Monitoring & Operations

### Health Checks

```bash
# Quick health check
curl http://<ec2-ip>/health | jq

# Detailed service status
ssh ubuntu@<ec2-ip> "cd app/docker-compose && docker-compose ps"

# View application logs
ssh ubuntu@<ec2-ip> "cd app/docker-compose && docker-compose logs -f fastapi-app"

# Check resource usage
ssh ubuntu@<ec2-ip> "docker stats --no-stream"
```

### Grafana Dashboards

Access Grafana at `http://<ec2-ip>/grafana` (admin/admin123)

**Available Dashboards:**
1. Application Metrics
   - Request rate and latency
   - Error rates
   - Contact submissions
   - Document uploads

2. System Metrics
   - CPU and memory usage
   - Disk I/O
   - Network traffic
   - Container stats

3. Business Metrics
   - Visitor trends
   - Service requests
   - Document types
   - Processing status

### Backup and Recovery

```bash
# Manual backup
ssh ubuntu@<ec2-ip> "cd app && ./scripts/backup-data.sh"

# Restore from backup
ssh ubuntu@<ec2-ip> "cd app && ./scripts/restore-data.sh backup-20251018.tar.gz"

# Create EC2 snapshot
aws ec2 create-snapshot \
  --volume-id <volume-id> \
  --description "Pretamane app backup $(date +%Y%m%d)"
```

---

## Scaling Options

### Vertical Scaling (Easier)
```bash
# Stop services
ssh ubuntu@<ec2-ip> "cd app/docker-compose && docker-compose down"

# Resize instance via AWS Console or CLI
aws ec2 stop-instances --instance-ids <instance-id>
aws ec2 modify-instance-attribute --instance-id <instance-id> --instance-type t3.large

# Start and verify
aws ec2 start-instances --instance-ids <instance-id>
ssh ubuntu@<ec2-ip> "cd app/docker-compose && docker-compose up -d"
```

### Horizontal Scaling (More Complex)
1. Deploy multiple EC2 instances
2. Add AWS ALB for load balancing
3. Use RDS for shared PostgreSQL
4. Use ElastiCache for session storage
5. Configure Meilisearch replication

---

## Migration from Original Repository

If you're migrating from the EKS version:

1. **Export Data:**
```bash
# From original repo
cd realistic-demo-pretamane
./scripts/export-dynamodb-data.sh
```

2. **Import to PostgreSQL:**
```bash
# In new repo
cd aws-to-opensource
./scripts/import-postgres-data.sh dynamodb-export.json
```

3. **Verify:**
```bash
# Check data migration
curl http://<ec2-ip>/analytics/insights
```

---

## Troubleshooting

### Services Won't Start

```bash
# Check Docker Compose logs
ssh ubuntu@<ec2-ip> "cd app/docker-compose && docker-compose logs"

# Check individual service
ssh ubuntu@<ec2-ip> "cd app/docker-compose && docker-compose logs fastapi-app"

# Restart specific service
ssh ubuntu@<ec2-ip> "cd app/docker-compose && docker-compose restart fastapi-app"
```

### Database Connection Issues

```bash
# Check PostgreSQL logs
ssh ubuntu@<ec2-ip> "cd app/docker-compose && docker-compose logs postgresql"

# Connect to database directly
ssh ubuntu@<ec2-ip> "cd app/docker-compose && docker-compose exec postgresql psql -U app_user -d pretamane_db"
```

### Search Not Working

```bash
# Check Meilisearch status
curl http://<ec2-ip>/meilisearch/health

# View Meilisearch logs
ssh ubuntu@<ec2-ip> "cd app/docker-compose && docker-compose logs meilisearch"

# Rebuild search index
curl -X POST http://<ec2-ip>/admin/rebuild-search-index
```

---

## Development Workflow

### Local Testing

```bash
# Run stack locally
cd docker-compose
docker-compose up -d

# Access locally
curl http://localhost:8000/health
open http://localhost:8000/docs

# Stop when done
docker-compose down
```

### Making Changes

```bash
# 1. Edit code
vim docker/api/app_opensource.py

# 2. Rebuild image
cd docker-compose
docker-compose build fastapi-app

# 3. Restart service
docker-compose up -d fastapi-app

# 4. View logs
docker-compose logs -f fastapi-app
```

### Deploying Updates

```bash
# From your local machine
./scripts/deploy-updates.sh

# Or manually
scp -i key.pem -r docker/api ubuntu@<ec2-ip>:/home/ubuntu/app/docker/
ssh ubuntu@<ec2-ip> "cd app/docker-compose && docker-compose up -d --build"
```

---

## Security

### Implemented Security Measures

1. **Network Security**
   - Security groups restrict access
   - Only ports 80, 443, 22 exposed
   - SSH restricted to specific IPs (configurable)

2. **Application Security**
   - Non-root container user
   - Environment variable secrets
   - Input validation
   - SQL injection prevention

3. **Data Security**
   - Encrypted EBS volumes
   - PostgreSQL password authentication
   - Meilisearch API key required
   - MinIO access keys

4. **Access Control**
   - IAM role for EC2 (no hardcoded credentials)
   - SSM Session Manager (no SSH keys needed)
   - Grafana admin password

### Security Hardening Checklist

- [ ] Restrict SSH to your IP only
- [ ] Change all default passwords
- [ ] Enable AWS GuardDuty
- [ ] Set up AWS CloudTrail
- [ ] Configure automated backups
- [ ] Enable AWS Systems Manager Session Manager
- [ ] Review security group rules
- [ ] Implement rate limiting in Caddy
- [ ] Set up SSL certificates (Let's Encrypt)
- [ ] Configure fail2ban for SSH protection

---

## Monitoring

### Pre-configured Dashboards

**Grafana Dashboards** (http://ip/grafana):
1. Application Performance
   - Request rates
   - Response times
   - Error rates
   - Success rates

2. Business Metrics
   - Contact submissions
   - Document uploads
   - Search queries
   - Visitor counts

3. System Health
   - CPU usage
   - Memory usage
   - Disk usage
   - Network I/O

4. Container Metrics
   - Per-service resource usage
   - Container health
   - Restart counts

### Alerts (Optional)

Configure Prometheus alerts for:
- High error rate (> 5%)
- High response time (> 1s)
- Low disk space (< 10%)
- High memory usage (> 90%)
- Service down

---

## Cost Management

### Monthly Cost Tracking

```bash
# Get current month cost
aws ce get-cost-and-usage \
  --time-period Start=2025-10-01,End=2025-10-31 \
  --granularity MONTHLY \
  --metrics BlendedCost

# Set up budget alert
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget file://budget-config.json
```

### Cost Optimization Tips

1. **Use Reserved Instance** (1-year commitment)
   - Saves ~40% vs on-demand
   - Monthly: $30 → $21
   - Annual: $360 → $252

2. **Use Spot Instance** (for non-critical demos)
   - Saves ~70% vs on-demand  
   - Monthly: $30 → $9
   - Risk: Can be terminated

3. **Stop Instance When Not Needed**
   - Demo only: Run 8 hours/day
   - Monthly: $30 → $10
   - Annual: $360 → $120

4. **Downsize to t3.small** (if 2GB RAM sufficient)
   - Monthly: $30 → $15
   - Annual: $360 → $180

---

## Performance

### Expected Performance

| Metric | Target | Typical |
|--------|--------|---------|
| API Response Time | < 100ms | ~50ms |
| Search Query Time | < 100ms | ~20ms |
| Document Upload | < 500ms | ~300ms |
| Database Query | < 50ms | ~10ms |
| Page Load Time | < 2s | ~1s |

### Load Testing

```bash
# Install k6 load testing tool
curl -L https://github.com/grafana/k6/releases/latest/download/k6-linux-amd64.tar.gz | tar xvz
sudo mv k6 /usr/local/bin/

# Run load test
k6 run scripts/load-test.js
```

---

## Maintenance

### Daily Tasks
- [ ] Check Grafana dashboards
- [ ] Review error logs
- [ ] Monitor disk usage

### Weekly Tasks
- [ ] Review and clean old documents
- [ ] Check backup status
- [ ] Update Docker images
- [ ] Review security logs

### Monthly Tasks
- [ ] Review AWS bill
- [ ] Update system packages
- [ ] Rotate credentials
- [ ] Test disaster recovery

### Automated Tasks
- Daily backups (3 AM UTC)
- Log rotation (30-day retention)
- Docker image cleanup
- Metrics retention (30 days)

---

## Support

### Getting Help

1. **Check Logs:**
   ```bash
   docker-compose logs -f [service-name]
   ```

2. **Health Checks:**
   ```bash
   curl http://<ec2-ip>/health | jq
   ```

3. **Service Status:**
   ```bash
   docker-compose ps
   docker stats
   ```

4. **System Resources:**
   ```bash
   htop
   df -h
   free -m
   ```

---

## Comparison: EKS vs EC2 Edition

| Aspect | EKS Edition | EC2 Edition | Winner |
|--------|-------------|-------------|--------|
| **Cost** | $330/mo | $30/mo | EC2 (90% savings) |
| **Complexity** | High (74+ resources) | Low (1 EC2) | EC2 (simpler) |
| **Scalability** | Excellent (auto-scale) | Limited (manual) | EKS |
| **Deployment Time** | 30-45 min | 5-10 min | EC2 (faster) |
| **Skills Shown** | AWS, K8s, Helm | Docker, Open-source | Both valuable |
| **Maintenance** | Complex | Simple | EC2 (easier) |
| **High Availability** | Multi-AZ | Single instance | EKS |
| **Demo Viability** | Expensive for 24/7 | Affordable 24/7 | EC2 (sustainable) |
| **Learning Value** | Enterprise patterns | Cost optimization | Both |

### When to Use Each

**Use EKS Edition When:**
- Enterprise client requirements
- Need horizontal scaling
- Multi-region deployment
- High availability required
- Budget allows $300+/month

**Use EC2 Edition When:**
- Portfolio/demo project
- Budget-conscious ($30/month)
- Single-region sufficient
- Learning open-source tools
- Sustainable 24/7 demo

---

##  Documentation

### **Interview Preparation**
Comprehensive technical guides for system/cloud engineer interviews:
- **[Interview Prep Index](./docs/interview-prep/README.md)** - Start here for complete guide
- [Architecture Overview](./docs/interview-prep/INTERVIEW-00-Complete-Architecture-Overview.md)
- [Reverse Proxy & Routing](./docs/interview-prep/INTERVIEW-01-Reverse-Proxy-Architecture.md)
- [Database Design](./docs/interview-prep/INTERVIEW-02-Database-Architecture.md)
- [Observability Stack](./docs/interview-prep/INTERVIEW-03-Observability-Stack.md)
- [Security Implementation](./docs/interview-prep/INTERVIEW-04-Security-Implementation.md)
- [Service Orchestration](./docs/interview-prep/INTERVIEW-05-Service-Orchestration.md)
- [Object Storage](./docs/interview-prep/INTERVIEW-06-Object-Storage-MinIO.md)

### **Deployment & Operations**
- [Quick Start Guide](./docs/guides/QUICK_START.md) - Get started in 5 minutes
- [Deployment Success Report](./docs/deployment/DEPLOYMENT_SUCCESS.md)
- [Edge Enforcement Guide](./docs/deployment/EDGE_ENFORCEMENT_DEPLOYMENT.md)
- [Implementation Summary](./docs/deployment/IMPLEMENTATION_SUMMARY.md)

### **Reference Guides**
- [Service Login Credentials](./docs/reference/SERVICE_LOGIN_GUIDE.md)
- [EC2 Deployment Guide](./docs/EC2_DEPLOYMENT_GUIDE.md)

### **Architecture & Security**
- [Architecture Docs](./docs/architecture/) - System design decisions
- [Security Guides](./docs/security/) - Security implementations

---

## Future Enhancements

### Phase 1: High Availability
- [ ] Add second EC2 in different AZ
- [ ] Add AWS ALB for load balancing
- [ ] Configure PostgreSQL streaming replication
- [ ] Set up MinIO distributed mode

### Phase 2: Advanced Features
- [ ] Add Redis for caching
- [ ] Implement message queue (RabbitMQ)
- [ ] Add Nginx for static file serving
- [ ] Implement CDN (CloudFront)

### Phase 3: Security Hardening
- [ ] WAF rules (AWS WAF or ModSecurity)
- [ ] DDoS protection (AWS Shield)
- [ ] Intrusion detection (OSSEC)
- [ ] Vulnerability scanning (Trivy)

### Phase 4: Observability
- [ ] Distributed tracing (Jaeger)
- [ ] APM (Elastic APM)
- [ ] Error tracking (Sentry)
- [ ] Uptime monitoring (UptimeRobot)

---

## License

Portfolio demonstration project. All rights reserved.

---

## Links

- **EKS Version:** [realistic-demo-pretamane](../realistic-demo-pretamane/)
- **Migration Plan:** [MIGRATION_PLAN.md](MIGRATION_PLAN.md)
- **Deployment Guide:** [docs/EC2_DEPLOYMENT_GUIDE.md](docs/EC2_DEPLOYMENT_GUIDE.md)
- **API Documentation:** http://your-ec2-ip/docs

---

**Built with:** AWS EC2, Docker Compose, PostgreSQL, Meilisearch, MinIO, Caddy, Prometheus, Grafana  
**Demonstrates:** Cost optimization, Migration planning, Open-source tooling, Infrastructure simplification  
**Savings:** 90% cost reduction ($330/mo → $30/mo)  
**Status:** Production-ready, Cost-optimized, Always-on demo

---

**Last Updated:** October 18, 2025  
**Version:** 4.0.0 (Open-Source Edition)
