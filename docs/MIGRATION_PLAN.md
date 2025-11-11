# AWS to Open-Source Migration Plan
## EC2-Only Architecture with Zero-Cost Alternatives

**Date:** October 18, 2025  
**Project:** realistic-demo-pretamane  
**Target:** EC2-based deployment with open-source alternatives  
**Goal:** Eliminate EKS and CloudSearch costs while maintaining functionality

---

## Executive Summary

This migration transforms the AWS EKS-based architecture into an **EC2-only deployment** using **open-source alternatives** for expensive managed services. The goal is to reduce monthly AWS costs from **~$330/month to ~$20-40/month** while maintaining all functionality and demonstrating deeper technical skills.

---

## Current Architecture (AWS-Heavy)

### Components Being Replaced

| AWS Service | Monthly Cost | Replacement | New Cost |
|------------|--------------|-------------|----------|
| **EKS Cluster** | ~$75 | Docker Compose on EC2 | $0 (included) |
| **EKS Node Groups** | ~$80 | Single t3.medium EC2 | ~$30 |
| **OpenSearch** | ~$60 | Meilisearch (self-hosted) | $0 |
| **EFS** | ~$30 | Local disk + MinIO (S3-compatible) | $0 |
| **Lambda** | ~$10 | Integrated into main app | $0 |
| **CloudWatch** | ~$10 | Prometheus + Loki | $0 |
| **ALB** | ~$20 | Caddy (reverse proxy) | $0 |
| **NAT Gateway** | ~$30 | Not needed (single EC2) | $0 |
| **Other** | ~$15 | Optimized | ~$5 |
| **TOTAL** | **~$330/month** | | **~$30-40/month** |

**Savings: ~$290-300/month (~90% cost reduction)**

---

## New Architecture (EC2 + Open-Source)

### Infrastructure Stack

```

                     AWS EC2 Instance                         
                    (t3.medium: 2 vCPU, 4GB RAM)             

                                                               
     
                Caddy (Reverse Proxy)                      
           HTTPS, Auto SSL, Load Balancing                
                Port 80/443 → Services                     
     
                                                             
   
       Docker Compose Network                             
                                                           
          
       FastAPI        PostgreSQL     Meilisearch  
       (Main App)     (Database)      (Search)    
       Port 8000      Port 5432       Port 7700   
          
                                                           
          
        MinIO         Prometheus        Loki      
     (S3-compat)      (Metrics)       (Logs)      
      Port 9000       Port 9090      Port 3100    
          
                                                           
          
       Grafana        Promtail       Amazon SES   
     (Dashboard)    (Log Shipper)    (Email)*     
      Port 3000       Port 9080       External    
          
   
                                                               
     
                Storage Layout                             
                                                            
    /data/                                                 
     postgresql/    (Database data)                     
     meilisearch/   (Search indices)                    
     minio/         (Object storage)                    
     uploads/       (Document uploads)                  
     processed/     (Processed files)                   
     prometheus/    (Metrics data)                      
     grafana/       (Dashboard data)                    
     loki/          (Log data)                          
     

         
          Internet via AWS Security Group
              - Port 80/443: Web traffic
              - Port 22: SSH (restricted to your IP)
              
* SES remains: Free tier covers up to 62,000 emails/month
  Alternative: Could use SMTP relay or self-hosted email
```

---

## Technology Comparison & Selection

### 1. Container Orchestration

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **Docker Compose** | Simple, lightweight, perfect for single-node | Limited scaling |  **SELECTED** |
| K3s | Lightweight K8s, familiar | Overkill for single EC2 |  |
| Docker Swarm | Native Docker, good scaling | Less ecosystem support |  |

**Pick: Docker Compose**
- Simplest for single EC2 instance
- Easy to understand and debug
- Perfect for portfolio demonstrations

### 2. Search Engine

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **Meilisearch** | Fast, typo-tolerant, beautiful UI | Newer, smaller community |  **SELECTED** |
| Typesense | Fast, well-documented | Similar to Meilisearch |  Alternative |
| OpenSearch | AWS-compatible, powerful | Heavy (2GB+ RAM) |  Too heavy |
| Elasticsearch | Industry standard | Heavy, complex licensing |  Too heavy |

**Pick: Meilisearch**
- Lightweight (~100MB RAM)
- RESTful API (easy migration from OpenSearch)
- Beautiful built-in search UI
- Perfect for document search

### 3. Database

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **PostgreSQL** | Industry standard, JSON support | Requires schema |  **SELECTED** |
| MySQL | Popular, well-documented | Less feature-rich |  |
| MongoDB | NoSQL, DynamoDB-like | Heavier, licensing |  |
| SQLite | Ultra-lightweight | Single file limitations |  |

**Pick: PostgreSQL 16**
- JSON/JSONB support (DynamoDB compatibility)
- Rock-solid reliability
- Industry standard (better for portfolio)
- Excellent Python support (psycopg2)

### 4. Object Storage

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **MinIO** | S3-compatible API, lightweight | Single-node limitations |  **SELECTED** |
| SeaweedFS | Distributed, S3-compatible | More complex |  |
| Local filesystem | Simple, fast | No S3 API |  |

**Pick: MinIO**
- Drop-in S3 replacement
- S3-compatible API (minimal code changes)
- Lightweight (~50MB RAM)
- Built-in web console

### 5. Reverse Proxy / Load Balancer

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **Caddy** | Auto HTTPS, modern, simple config | Newer |  **SELECTED** |
| Nginx | Industry standard, mature | Complex config |  Alternative |
| Traefik | Auto-discovery, Docker integration | Heavier |  |
| HAProxy | High performance, TCP/HTTP | Complex for simple use |  |

**Pick: Caddy v2**
- Automatic HTTPS with Let's Encrypt
- Simple Caddyfile configuration
- Modern, actively developed
- Perfect for single-server setup

### 6. Monitoring

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **Prometheus + Grafana** | Industry standard, powerful | Memory usage |  **SELECTED** |
| VictoriaMetrics | More efficient than Prometheus | Less ecosystem |  |
| Netdata | Real-time, beautiful | Different paradigm |  |

**Pick: Prometheus + Grafana**
- Industry standard (portfolio value)
- Excellent ecosystem
- Pre-built dashboards available
- ~300MB RAM total

### 7. Logging

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **Loki + Promtail** | Prometheus-like, efficient | Newer |  **SELECTED** |
| ELK Stack | Powerful, feature-rich | Heavy (4GB+ RAM) |  Too heavy |
| Fluentd + file output | Simple, lightweight | Limited querying |  |

**Pick: Loki + Promtail**
- Lightweight (~200MB RAM)
- Grafana integration
- Log aggregation without heavy indexing
- Perfect for single-node

### 8. Email

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **AWS SES** | Reliable, free tier (62k/month) | AWS dependency |  **KEEP** |
| SendGrid | Easy, free tier | External dependency |  Alternative |
| Postfix | Self-hosted, full control | Complex, deliverability issues |  |
| Mailgun | Developer-friendly | Costs add up |  |

**Pick: Keep AWS SES**
- Free tier is generous (62,000 emails/month)
- Already configured
- Reliable delivery
- Minimal cost impact

---

## Final Technology Stack

### Core Application Stack
```yaml
Services:
  - fastapi-app:        FastAPI (Python 3.11)
  - postgresql:         PostgreSQL 16
  - meilisearch:        Meilisearch latest
  - minio:              MinIO (S3-compatible)
  - caddy:              Caddy v2 (reverse proxy)
  
Monitoring Stack:
  - prometheus:         Prometheus (metrics)
  - grafana:            Grafana (dashboards)
  - loki:               Loki (log aggregation)
  - promtail:           Promtail (log shipper)

External Services:
  - ses:                AWS SES (email) - kept for cost efficiency
```

### Resource Allocation (4GB EC2 Instance)

```
FastAPI App:       512MB RAM, 1 CPU
PostgreSQL:        1GB RAM, 1 CPU
Meilisearch:       512MB RAM, 0.5 CPU
MinIO:             256MB RAM, 0.5 CPU
Prometheus:        256MB RAM, 0.5 CPU
Grafana:           256MB RAM, 0.5 CPU
Loki:              256MB RAM, 0.25 CPU
Promtail:          128MB RAM, 0.25 CPU
Caddy:             128MB RAM, 0.25 CPU
System overhead:   512MB RAM, 0.5 CPU

Total:             ~3.8GB RAM, ~5.25 vCPU
```

**EC2 Instance Choice: t3.medium**
- 2 vCPU, 4GB RAM
- $0.0416/hour = ~$30/month
- Sufficient for demo/portfolio use
- Can burst to handle traffic spikes

---

## Migration Steps

### Phase 1: Infrastructure Setup (Terraform)
1. **VPC & Networking**
   - Minimal VPC (single public subnet)
   - Security group (ports 80, 443, 22)
   - Elastic IP for stable addressing
   
2. **EC2 Instance**
   - t3.medium with Ubuntu 24.04 LTS
   - 30GB EBS volume (GP3)
   - IAM role for SES access only
   - User data script for initial setup

3. **DNS** (Optional)
   - Route53 hosted zone (if custom domain needed)
   - Or use EC2 public IP directly

### Phase 2: Application Stack (Docker Compose)
1. **Database Migration**
   - PostgreSQL with JSON support
   - Migration scripts: DynamoDB → PostgreSQL
   - Schema design for contacts, documents, visitors

2. **Search Migration**
   - Meilisearch setup
   - Index configuration
   - API adapter for OpenSearch → Meilisearch

3. **Storage Migration**
   - MinIO S3-compatible storage
   - File organization structure
   - Boto3 endpoint configuration

4. **Application Updates**
   - Update `aws_clients.py` for new services
   - PostgreSQL database service
   - Meilisearch search service
   - MinIO storage configuration

### Phase 3: Monitoring & Observability
1. **Metrics Collection**
   - Prometheus for metrics
   - Application instrumentation
   - Container metrics

2. **Visualization**
   - Grafana dashboards
   - Pre-built monitoring views
   - Alert rules

3. **Logging**
   - Loki for log aggregation
   - Promtail for log collection
   - Grafana integration

### Phase 4: Deployment Automation
1. **Terraform Module**
   - EC2 instance provisioning
   - Security group rules
   - User data bootstrap script

2. **Docker Compose**
   - Complete service definitions
   - Volume management
   - Network configuration

3. **Deployment Scripts**
   - One-command deployment
   - Backup/restore scripts
   - Health check automation

---

## Code Changes Required

### 1. Database Layer Changes

**Old (DynamoDB):**
```python
# docker/api/shared/database_service.py
dynamodb = boto3.resource('dynamodb', region_name=region)
table = dynamodb.Table('realistic-demo-pretamane-contact-submissions')
table.put_item(Item=contact_data)
```

**New (PostgreSQL):**
```python
# docker/api/shared/database_service.py
import psycopg2
from psycopg2.extras import Json

conn = psycopg2.connect(os.environ['DATABASE_URL'])
cur = conn.cursor()
cur.execute(
    "INSERT INTO contact_submissions (id, data) VALUES (%s, %s)",
    (contact_id, Json(contact_data))
)
conn.commit()
```

### 2. Search Layer Changes

**Old (OpenSearch):**
```python
# docker/api/shared/opensearch_client.py
from opensearchpy import OpenSearch
client = OpenSearch(hosts=[os.environ['OPENSEARCH_ENDPOINT']])
client.index(index='documents', body=document)
```

**New (Meilisearch):**
```python
# docker/api/shared/search_service.py
import meilisearch

client = meilisearch.Client('http://meilisearch:7700', os.environ['MEILI_MASTER_KEY'])
index = client.index('documents')
index.add_documents([document])
```

### 3. Storage Layer Changes

**Old (S3):**
```python
# docker/api/shared/aws_clients.py
s3_client = boto3.client('s3', region_name=region)
s3_client.put_object(Bucket=bucket, Key=key, Body=content)
```

**New (MinIO with S3 API):**
```python
# docker/api/shared/storage_service.py
s3_client = boto3.client(
    's3',
    endpoint_url='http://minio:9000',
    aws_access_key_id=os.environ['MINIO_ACCESS_KEY'],
    aws_secret_access_key=os.environ['MINIO_SECRET_KEY']
)
s3_client.put_object(Bucket=bucket, Key=key, Body=content)
```

### 4. Email Layer Changes

**Keep AWS SES (No Changes)**
- Free tier sufficient
- Already implemented
- Reliable delivery

---

## File Structure Changes

### New Directories

```
aws-to-opensource/
 docker-compose/
    docker-compose.yml           # Main orchestration
    docker-compose.monitoring.yml # Monitoring stack
    .env.example                  # Environment template
    README.md                     # Docker Compose guide

 terraform-ec2/                    # Simplified Terraform
    main.tf                       # EC2 + networking
    outputs.tf                    # Instance details
    variables.tf                  # Configuration
    user-data.sh                  # Bootstrap script

 docker/
    api/
        Dockerfile                # Application image
        requirements.txt          # Python dependencies
        (existing app code)       # Updated for new services

 config/
    caddy/
       Caddyfile                 # Reverse proxy config
    prometheus/
       prometheus.yml            # Metrics config
    grafana/
       dashboards/               # Pre-built dashboards
    loki/
        loki-config.yml           # Logging config

 scripts/
    deploy-ec2.sh                 # Full deployment
    backup-data.sh                # Backup script
    restore-data.sh               # Restore script
    health-check.sh               # Monitoring script

 docs/
     EC2_DEPLOYMENT_GUIDE.md       # Deployment docs
     MIGRATION_GUIDE.md            # Migration steps
     COST_COMPARISON.md            # Before/after costs
```

---

## Deployment Process

### Step 1: Provision EC2 Infrastructure
```bash
cd terraform-ec2/
terraform init
terraform apply

# Outputs:
# - ec2_public_ip
# - ssh_command
```

### Step 2: Initial Server Setup
```bash
# SSH into instance
ssh -i your-key.pem ubuntu@<ec2-ip>

# Clone repository
git clone https://github.com/yourusername/aws-to-opensource.git
cd aws-to-opensource

# Run setup script
./scripts/setup-ec2.sh
```

### Step 3: Configure Environment
```bash
# Copy and edit environment file
cp docker-compose/.env.example docker-compose/.env
nano docker-compose/.env

# Set values:
# - MINIO_ACCESS_KEY
# - MINIO_SECRET_KEY
# - POSTGRES_PASSWORD
# - MEILI_MASTER_KEY
# - AWS_SES credentials
```

### Step 4: Deploy Stack
```bash
# Start all services
cd docker-compose/
docker-compose up -d

# Verify services
docker-compose ps
./scripts/health-check.sh
```

### Step 5: Access Application
```bash
# Application endpoints:
http://<ec2-ip>/                 # API
http://<ec2-ip>/docs             # Swagger UI
http://<ec2-ip>/grafana          # Grafana dashboard
http://<ec2-ip>/meilisearch      # Search console
http://<ec2-ip>/minio            # MinIO console
```

---

## Cost Breakdown (New Architecture)

### Monthly Costs

**EC2 Instance (t3.medium):**
- Compute: $0.0416/hour × 730 hours = **$30.37/month**
- EBS Storage: 30GB × $0.08/GB = **$2.40/month**
- Elastic IP: $0/month (when attached)
- Data Transfer: ~$1-2/month (first 100GB free)

**AWS SES (Email):**
- First 62,000 emails/month: **$0/month**
- Beyond that: $0.10/1000 emails

**Total: ~$33-35/month**

### Cost Comparison

| Scenario | AWS EKS Stack | EC2 Open-Source | Savings |
|----------|---------------|-----------------|---------|
| **Demo (1 day)** | ~$11 | ~$1.10 | ~$10 (90%) |
| **Week** | ~$76 | ~$7.70 | ~$68 (90%) |
| **Month** | ~$330 | ~$33 | ~$297 (90%) |
| **Year** | ~$3,960 | ~$396 | ~$3,564 (90%) |

---

## Portfolio Impact

### What You Gain

1. **Cost Optimization Skills**
   - Demonstrates ability to reduce cloud costs by 90%
   - Shows pragmatic engineering decisions
   - Cost-conscious architecture design

2. **Broader Technology Stack**
   - PostgreSQL (industry standard database)
   - Meilisearch (modern search engine)
   - Docker Compose (container orchestration)
   - Caddy (modern reverse proxy)
   - Prometheus/Grafana (monitoring)
   - Loki (logging)

3. **Real-World Experience**
   - Migration planning and execution
   - Service replacement strategies
   - Multi-container application design
   - Infrastructure optimization

4. **More Sustainable Demo**
   - Can afford to keep it running 24/7
   - Always-available portfolio demo
   - No fear of unexpected AWS bills

### What You Keep from Original

1. **All Application Features**
   - Contact form processing
   - Document upload (17 file types)
   - Real-time search
   - Analytics dashboard
   - Email notifications

2. **All Technical Concepts**
   - Infrastructure as Code (Terraform)
   - Containerization (Docker)
   - API design (FastAPI)
   - Monitoring & logging
   - Security best practices

3. **Portable Skills**
   - Everything learned applies to any cloud
   - Open-source skills transfer everywhere
   - Not locked into AWS ecosystem

---

## Migration Timeline

### Immediate (Today)
-  Clone repository
- ⏳ Create migration plan
- ⏳ Create Docker Compose configuration
- ⏳ Update application code

### This Week
- ⏳ Create Terraform EC2 module
- ⏳ Test locally with Docker Compose
- ⏳ Deploy to EC2
- ⏳ Verify all features working

### Next Week
- ⏳ Add monitoring dashboards
- ⏳ Create comprehensive documentation
- ⏳ Performance testing
- ⏳ Security hardening

---

## Risk Assessment

### Low Risk
- **Docker Compose**: Battle-tested, stable
- **PostgreSQL**: Industry standard, reliable
- **Caddy**: Production-ready, simple
- **MinIO**: Widely used, S3-compatible

### Medium Risk
- **Meilisearch**: Newer but stable, active community
- **Loki**: Relatively new but backed by Grafana Labs
- **Single EC2**: No high availability (acceptable for portfolio)

### Mitigation Strategies
- **Backups**: Automated daily backups to S3
- **Monitoring**: Comprehensive health checks
- **Documentation**: Detailed runbooks
- **Snapshots**: Regular EC2 snapshots

---

## Success Metrics

### Technical Success
- [ ] All API endpoints functional
- [ ] Search performance < 100ms
- [ ] Database queries < 50ms
- [ ] 99%+ uptime over 30 days
- [ ] < 2% CPU usage at idle
- [ ] < 60% memory usage at idle

### Cost Success
- [ ] Monthly AWS bill < $40
- [ ] 90%+ cost reduction achieved
- [ ] No unexpected charges
- [ ] Sustainable for 6+ months

### Portfolio Success
- [ ] Live demo accessible 24/7
- [ ] Beautiful monitoring dashboards
- [ ] Comprehensive documentation
- [ ] Easy to explain in interviews
- [ ] Demonstrates cost optimization

---

## Interview Talking Points

**"Why did you migrate from EKS to EC2?"**
> "I demonstrated the full AWS EKS stack to show enterprise-grade cloud architecture. However, for a portfolio project, the $330/month cost wasn't sustainable. I re-architected the system using open-source alternatives on a single EC2 instance, reducing costs by 90% while maintaining all functionality. This demonstrates both AWS expertise AND cost optimization skills - showing I can build enterprise solutions when needed but also make pragmatic decisions based on requirements."

**"Doesn't this make it less impressive?"**
> "Actually, it makes it more impressive. Many candidates can deploy to managed services by following tutorials. I've now demonstrated: (1) Building on AWS managed services, (2) Understanding cost implications, (3) Architecting alternative solutions, (4) Migrating between platforms, (5) Working with diverse technology stacks. Plus, I can afford to keep this running 24/7 as a live demo, which most candidates can't."

**"What did you learn from this migration?"**
> "I learned that expensive doesn't always mean better. Meilisearch often outperforms OpenSearch for document search. PostgreSQL with JSONB handles 'NoSQL' patterns beautifully. Docker Compose can replace Kubernetes for many use cases. The key is matching technology to requirements, not just using the most expensive or 'enterprisey' solution. This is exactly the kind of cost optimization real companies need."

---

## Next Steps

1. **Create Docker Compose Configuration** 
2. **Update Application Code** ⏳
3. **Create Terraform EC2 Module** ⏳
4. **Test Locally** ⏳
5. **Deploy to EC2** ⏳
6. **Document Everything** ⏳

---

**Status:** Migration plan complete, ready for implementation  
**Estimated Time:** 2-3 days for full migration  
**Complexity:** Medium (straightforward service replacements)  
**Risk Level:** Low (proven technologies, well-documented)

---

## Appendix: Service Endpoints

### Production URLs (After Deployment)
```
Main Application:     https://ec2-ip.compute.amazonaws.com/
API Documentation:    https://ec2-ip.compute.amazonaws.com/docs
Grafana Dashboard:    https://ec2-ip.compute.amazonaws.com/grafana
Meilisearch Console:  https://ec2-ip.compute.amazonaws.com/meilisearch
MinIO Console:        https://ec2-ip.compute.amazonaws.com/minio
Prometheus:           https://ec2-ip.compute.amazonaws.com/prometheus
```

### Service Ports (Internal)
```
FastAPI:      8000
PostgreSQL:   5432
Meilisearch:  7700
MinIO:        9000 (API), 9001 (Console)
Prometheus:   9090
Grafana:      3000
Loki:         3100
Promtail:     9080
Caddy:        80, 443
```

---

**Ready to proceed with implementation!**


