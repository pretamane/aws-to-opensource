# EC2 Deployment Guide - Open-Source Stack
## Complete Step-by-Step Deployment Instructions

**Target:** AWS EC2 single instance deployment  
**Stack:** Docker Compose with open-source services  
**Cost:** ~$30-35/month (90% savings vs EKS)

---

## Prerequisites

### Required

1. **AWS Account**
   - Active AWS account
   - AWS CLI installed and configured
   - EC2 key pair created in target region

2. **Local Tools**
   - Terraform ≥ 1.5.0
   - Git
   - SSH client
   - curl or wget

3. **Knowledge Requirements**
   - Basic Linux command line
   - SSH connection
   - Basic Docker concepts

### Optional

- Custom domain name
- Route53 hosted zone
- SSL certificate

---

## Deployment Steps

### Step 1: Prepare AWS Account (5 minutes)

#### 1.1 Create EC2 Key Pair

```bash
# Via AWS CLI
aws ec2 create-key-pair \
  --key-name pretamane-opensource-key \
  --region ap-southeast-1 \
  --query 'KeyMaterial' \
  --output text > pretamane-opensource-key.pem

chmod 400 pretamane-opensource-key.pem

# Or via AWS Console:
# EC2 → Key Pairs → Create Key Pair → Download .pem file
```

#### 1.2 Verify SES Email (Optional)

```bash
# Verify sender email for SES
aws ses verify-email-identity \
  --email-address noreply@yourdomain.com \
  --region ap-southeast-1

# Check verification status
aws ses get-identity-verification-attributes \
  --identities noreply@yourdomain.com \
  --region ap-southeast-1
```

#### 1.3 Set Budget Alert

```bash
# Create budget to avoid surprises
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget '{
    "BudgetName": "pretamane-monthly-budget",
    "BudgetLimit": {
      "Amount": "50",
      "Unit": "USD"
    },
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST"
  }'
```

### Step 2: Clone and Configure Repository (5 minutes)

```bash
# Clone repository
git clone <your-repo-url> aws-to-opensource
cd aws-to-opensource

# Configure Terraform
cd terraform-ec2
cp terraform.tfvars.example terraform.tfvars

# Edit configuration
nano terraform.tfvars
```

**Edit `terraform.tfvars`:**
```hcl
project_name      = "pretamane-opensource"
environment       = "production"
region            = "ap-southeast-1"
instance_type     = "t3.medium"
root_volume_size  = 30
use_elastic_ip    = true
key_name          = "pretamane-opensource-key"  # Your key name

# IMPORTANT: Restrict SSH to your IP
ssh_allowed_cidrs = ["YOUR.IP.ADD.RESS/32"]  # Change this!

ses_from_email    = "noreply@yourdomain.com"
ses_to_email      = "admin@yourdomain.com"
```

### Step 3: Deploy Infrastructure with Terraform (5 minutes)

```bash
# Still in terraform-ec2/ directory

# Initialize Terraform
terraform init

# Review plan
terraform plan

# Deploy (requires confirmation)
terraform apply

# Or auto-approve for automation
terraform apply -auto-approve
```

**Expected Output:**
```
Apply complete! Resources: 9 added, 0 changed, 0 destroyed.

Outputs:

instance_id = "i-0abc123def456789"
instance_public_ip = "54.169.123.45"
instance_public_dns = "ec2-54-169-123-45.ap-southeast-1.compute.amazonaws.com"
ssh_command = "ssh -i pretamane-opensource-key.pem ubuntu@54.169.123.45"
application_url = "http://54.169.123.45"
api_docs_url = "http://54.169.123.45/docs"
grafana_url = "http://54.169.123.45/grafana"
```

**Save these outputs!** You'll need them to access your application.

### Step 4: Wait for Bootstrap (5-10 minutes)

The EC2 instance runs a user-data script that:
1. Updates system packages
2. Installs Docker and Docker Compose
3. Creates directory structure
4. Installs AWS CLI
5. Generates initial environment file

```bash
# Get instance IP from Terraform
EC2_IP=$(terraform output -raw instance_public_ip)

# Wait for instance to be running
aws ec2 wait instance-running --instance-ids $(terraform output -raw instance_id)

# Watch bootstrap progress (requires SSH access)
ssh -i pretamane-opensource-key.pem ubuntu@$EC2_IP "tail -f /var/log/cloud-init-output.log"

# Or check for completion marker
ssh -i pretamane-opensource-key.pem ubuntu@$EC2_IP "cat /home/ubuntu/BOOTSTRAP_COMPLETE.txt"
```

**Expected:** Bootstrap should complete in 5-10 minutes.

### Step 5: Upload Application Code (2 minutes)

```bash
# Go back to repository root
cd ..

# Create deployment package
tar -czf app-code.tar.gz \
    docker/api/ \
    docker-compose/ \
    --exclude='*.pyc' \
    --exclude='__pycache__'

# Upload to EC2
scp -i terraform-ec2/pretamane-opensource-key.pem \
    app-code.tar.gz \
    ubuntu@$EC2_IP:/home/ubuntu/

# Extract on EC2
ssh -i terraform-ec2/pretamane-opensource-key.pem ubuntu@$EC2_IP << 'EOF'
cd /home/ubuntu/app
tar -xzf /home/ubuntu/app-code.tar.gz
rm /home/ubuntu/app-code.tar.gz
echo "Application code ready!"
EOF

# Clean up local tarball
rm app-code.tar.gz
```

### Step 6: Configure Environment (3 minutes)

```bash
# SSH into instance
ssh -i terraform-ec2/pretamane-opensource-key.pem ubuntu@$EC2_IP

# Edit environment file
cd /home/ubuntu/app/docker-compose
nano .env
```

**Review and update:**
- Database password (auto-generated - keep it)
- Meilisearch key (auto-generated - keep it)
- MinIO credentials (auto-generated - keep it)
- AWS SES emails (update if needed)
- Check all values

**Exit SSH:** Type `exit`

### Step 7: Start Application Stack (5 minutes)

```bash
# SSH into instance
ssh -i terraform-ec2/pretamane-opensource-key.pem ubuntu@$EC2_IP

# Go to docker-compose directory
cd /home/ubuntu/app/docker-compose

# Pull Docker images
docker-compose pull

# Start services
docker-compose up -d

# Watch startup logs
docker-compose logs -f

# Press Ctrl+C when you see "Application startup complete!"
```

**Check service status:**
```bash
docker-compose ps

# Expected output:
NAME                COMMAND                  SERVICE             STATUS              PORTS
caddy               "caddy run --config …"   caddy               running             0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
fastapi-app         "uvicorn app:app --h…"   fastapi-app         running             0.0.0.0:8000->8000/tcp
grafana             "/run.sh"                grafana             running             0.0.0.0:3000->3000/tcp
loki                "/usr/bin/loki -conf…"   loki                running             0.0.0.0:3100->3100/tcp
meilisearch         "/bin/meilisearch"       meilisearch         running             0.0.0.0:7700->7700/tcp
minio               "/usr/bin/docker-ent…"   minio               running             0.0.0.0:9000-9001->9000-9001/tcp
postgresql          "docker-entrypoint.s…"   postgresql          running             5432/tcp
prometheus          "/bin/prometheus --c…"   prometheus          running             0.0.0.0:9090->9090/tcp
promtail            "/usr/bin/promtail -…"   promtail            running
```

**Exit SSH:** Type `exit`

### Step 8: Verify Deployment (2 minutes)

From your local machine:

```bash
# Set instance IP
EC2_IP=$(cd terraform-ec2 && terraform output -raw instance_public_ip)

# Test API
curl http://$EC2_IP/health | jq

# Expected:
# {
#   "status": "healthy",
#   "timestamp": "2025-10-18T...",
#   "version": "4.0.0",
#   "services": {
#     "postgresql": "connected",
#     "meilisearch": "connected",
#     "minio": "connected",
#     "ses": "connected"
#   }
# }

# Test API root
curl http://$EC2_IP/ | jq

# Test Swagger UI (open in browser)
open http://$EC2_IP/docs

# Test Grafana (open in browser)
open http://$EC2_IP/grafana
```

### Step 9: Post-Deployment Configuration (5 minutes)

#### 9.1 Configure Grafana

1. Open `http://<ec2-ip>/grafana`
2. Login: `admin` / `admin123`
3. Change password when prompted
4. Verify datasources:
   - Configuration → Data Sources → Should show Prometheus and Loki
5. Import dashboards:
   - Dashboards → Import
   - Upload dashboard JSONs from `config/grafana/dashboards/`

#### 9.2 Verify Meilisearch

1. Open `http://<ec2-ip>/meilisearch`
2. API Key: (from .env file)
3. Check indexes
4. Test search functionality

#### 9.3 Verify MinIO

1. Open `http://<ec2-ip>/minio`
2. Login with credentials from .env
3. Verify buckets exist:
   - `pretamane-data`
   - `pretamane-backup`
   - `pretamane-logs`

### Step 10: Test Application (5 minutes)

#### Test Contact Form Submission

```bash
curl -X POST http://$EC2_IP/contact \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "email": "test@example.com",
    "message": "Testing the open-source stack!",
    "company": "Test Corp",
    "service": "Testing",
    "budget": "$1,000 - $5,000"
  }' | jq
```

#### Test Document Upload

```bash
# Create test file
echo "This is a test document for the open-source stack" > test-doc.txt

# Upload document
curl -X POST http://$EC2_IP/documents/upload \
  -F "file=@test-doc.txt" \
  -F "contact_id=test_contact_123" \
  -F "document_type=test" \
  -F "description=Test document upload" \
  -F "tags=test,opensource"
```

#### Test Search

```bash
curl -X POST http://$EC2_IP/documents/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "test document",
    "limit": 10
  }' | jq
```

#### Test Analytics

```bash
curl http://$EC2_IP/analytics/insights | jq
```

---

## Post-Deployment Checklist

- [ ] All services running (`docker-compose ps`)
- [ ] API health check passing (`/health`)
- [ ] Swagger UI accessible (`/docs`)
- [ ] Grafana accessible (`/grafana`)
- [ ] Contact form submission works
- [ ] Document upload works
- [ ] Search functionality works
- [ ] Prometheus metrics available (`/metrics`)
- [ ] Grafana dashboards showing data
- [ ] MinIO console accessible
- [ ] Meilisearch console accessible
- [ ] Email notifications working (if SES configured)

---

## Maintenance Tasks

### Daily

```bash
# Check service health
curl http://$EC2_IP/health

# Check disk usage
ssh ubuntu@$EC2_IP "df -h"

# View recent logs
ssh ubuntu@$EC2_IP "cd app/docker-compose && docker-compose logs --tail=100 fastapi-app"
```

### Weekly

```bash
# Update Docker images
ssh ubuntu@$EC2_IP "cd app/docker-compose && docker-compose pull && docker-compose up -d"

# Clean up old Docker images
ssh ubuntu@$EC2_IP "docker system prune -af --volumes=false"

# Check backups
ssh ubuntu@$EC2_IP "ls -lh /data/backups/"
```

### Monthly

```bash
# Update system packages
ssh ubuntu@$EC2_IP "sudo apt-get update && sudo apt-get upgrade -y"

# Review AWS bill
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '1 month ago' +%Y-%m-01),End=$(date +%Y-%m-01) \
  --granularity MONTHLY \
  --metrics BlendedCost
```

---

## Backup and Recovery

### Create Backup

```bash
# SSH into instance
ssh ubuntu@$EC2_IP

# Create backup
cd /home/ubuntu/app
./scripts/backup-data.sh

# Backup will be created in /data/backups/
ls -lh /data/backups/
```

### Restore from Backup

```bash
# SSH into instance
ssh ubuntu@$EC2_IP

# Stop services
cd /home/ubuntu/app/docker-compose
docker-compose down

# Restore data
cd /home/ubuntu/app
./scripts/restore-data.sh /data/backups/backup-20251018.tar.gz

# Start services
cd docker-compose
docker-compose up -d
```

### EC2 Snapshot (Recommended)

```bash
# Create AMI snapshot
aws ec2 create-image \
  --instance-id $(cd terraform-ec2 && terraform output -raw instance_id) \
  --name "pretamane-snapshot-$(date +%Y%m%d)" \
  --description "Snapshot of Pretamane application" \
  --no-reboot
```

---

## Scaling

### Vertical Scaling (Increase Instance Size)

```bash
# 1. Stop Docker Compose
ssh ubuntu@$EC2_IP "cd app/docker-compose && docker-compose down"

# 2. Stop instance
INSTANCE_ID=$(cd terraform-ec2 && terraform output -raw instance_id)
aws ec2 stop-instances --instance-ids $INSTANCE_ID
aws ec2 wait instance-stopped --instance-ids $INSTANCE_ID

# 3. Change instance type
aws ec2 modify-instance-attribute \
  --instance-id $INSTANCE_ID \
  --instance-type t3.large

# 4. Start instance
aws ec2 start-instances --instance-ids $INSTANCE_ID
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

# 5. Start services
ssh ubuntu@$EC2_IP "cd app/docker-compose && docker-compose up -d"
```

### Horizontal Scaling (Multiple Instances)

For true horizontal scaling:
1. Deploy multiple EC2 instances
2. Add AWS Application Load Balancer
3. Configure shared PostgreSQL (RDS)
4. Use ElastiCache for sessions
5. Configure Meilisearch cluster

**Note:** This increases costs but provides high availability.

---

## Monitoring

### Access Grafana

1. Open: `http://<ec2-ip>/grafana`
2. Login: `admin` / `admin123` (change on first login)
3. Navigate to Dashboards
4. View:
   - Application Performance
   - Business Metrics
   - System Health

### View Prometheus Metrics

```bash
# Direct access
open http://$EC2_IP/prometheus

# Query examples:
# - http_requests_total
# - http_request_duration_seconds
# - contact_submissions_total
# - document_uploads_total
```

### View Logs in Grafana

1. Open Grafana → Explore
2. Select "Loki" datasource
3. Query: `{job="docker"}`
4. Filter by service: `{container_name="fastapi-app"}`

---

## Troubleshooting

### Services Won't Start

**Problem:** `docker-compose up -d` fails

**Solution:**
```bash
# Check logs
docker-compose logs

# Check disk space
df -h

# Check memory
free -m

# Restart Docker
sudo systemctl restart docker
docker-compose up -d
```

### Database Connection Error

**Problem:** "could not connect to server"

**Solution:**
```bash
# Check PostgreSQL status
docker-compose ps postgresql
docker-compose logs postgresql

# Verify environment variables
cat .env | grep POSTGRES

# Restart PostgreSQL
docker-compose restart postgresql

# Wait and retry
sleep 10
docker-compose restart fastapi-app
```

### Search Not Working

**Problem:** Meilisearch queries fail

**Solution:**
```bash
# Check Meilisearch status
curl http://localhost:7700/health

# View Meilisearch logs
docker-compose logs meilisearch

# Verify API key
cat .env | grep MEILI

# Recreate index
docker-compose restart meilisearch
```

### Out of Disk Space

**Problem:** Disk usage at 100%

**Solution:**
```bash
# Check disk usage
df -h
du -sh /data/*

# Clean Docker
docker system prune -a --volumes
docker-compose down
docker system df

# Clean old logs
find /data/logs -name "*.log" -mtime +30 -delete

# Expand EBS volume (via AWS Console or CLI)
```

### High Memory Usage

**Problem:** Instance running out of memory

**Solution:**
```bash
# Check memory usage
free -m
docker stats --no-stream

# Identify heavy services
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}"

# Restart services
docker-compose restart

# Or scale instance up (see Vertical Scaling section)
```

---

## Security Hardening

### 1. Restrict SSH Access

```bash
# Edit terraform.tfvars
ssh_allowed_cidrs = ["YOUR.IP.ADD.RESS/32"]

# Apply changes
terraform apply
```

### 2. Change Default Passwords

```bash
# SSH into instance
ssh ubuntu@$EC2_IP

# Edit .env file
cd app/docker-compose
nano .env

# Change:
# - POSTGRES_PASSWORD
# - GRAFANA_ADMIN_PASSWORD
# - MEILI_MASTER_KEY
# - MINIO_ROOT_PASSWORD

# Restart services
docker-compose down
docker-compose up -d
```

### 3. Enable HTTPS

**Option 1: Let's Encrypt (Free, Automatic)**

Edit `docker-compose/config/caddy/Caddyfile`:
```caddyfile
yourdomain.com {
    reverse_proxy fastapi-app:8000
    
    tls {
        protocols tls1.2 tls1.3
    }
}
```

Restart Caddy:
```bash
docker-compose restart caddy
```

**Option 2: AWS ACM Certificate + CloudFront**
- More complex but integrates with AWS
- Adds cost (~$5-10/month)

### 4. Configure Firewall

```bash
# UFW is already configured by user-data script
# Verify:
ssh ubuntu@$EC2_IP "sudo ufw status"

# Should show:
# 22/tcp    ALLOW   Anywhere
# 80/tcp    ALLOW   Anywhere
# 443/tcp   ALLOW   Anywhere
```

### 5. Set Up Fail2Ban (SSH Protection)

```bash
ssh ubuntu@$EC2_IP << 'EOF'
sudo apt-get install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Configure
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo nano /etc/fail2ban/jail.local
# Set bantime = 3600, maxretry = 3

sudo systemctl restart fail2ban
EOF
```

---

## Performance Optimization

### Database Performance

```bash
# Tune PostgreSQL for 4GB RAM
ssh ubuntu@$EC2_IP << 'EOF'
# Edit postgresql.conf via Docker Compose override
cat >> ~/app/docker-compose/docker-compose.override.yml << 'OVERRIDE'
version: '3.8'
services:
  postgresql:
    command:
      - "postgres"
      - "-c"
      - "shared_buffers=1GB"
      - "-c"
      - "effective_cache_size=3GB"
      - "-c"
      - "work_mem=32MB"
      - "-c"
      - "maintenance_work_mem=256MB"
OVERRIDE

docker-compose up -d postgresql
EOF
```

### Application Performance

```bash
# Increase FastAPI workers
# Edit docker-compose.yml, change:
# CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]

# Restart app
docker-compose up -d --build fastapi-app
```

### Caching (Optional)

Add Redis for caching:
```yaml
# Add to docker-compose.yml
redis:
  image: redis:7-alpine
  restart: unless-stopped
  volumes:
    - redis-data:/data
  networks:
    - app-network
```

---

## Cost Optimization

### 1. Use Reserved Instance (Best ROI)

```bash
# Purchase 1-year reserved instance
aws ec2 purchase-reserved-instances-offering \
  --reserved-instances-offering-id <offering-id> \
  --instance-count 1

# Savings: ~40% ($30 → $21/month)
```

### 2. Use Spot Instance (Risky but Cheap)

```bash
# Modify terraform-ec2/main.tf
# Add to aws_instance resource:
instance_market_options {
  market_type = "spot"
  spot_options {
    max_price = "0.02"  # ~50% of on-demand price
  }
}

# Savings: ~70% ($30 → $9/month)
# Risk: Can be terminated anytime
```

### 3. Stop During Off-Hours

```bash
# Stop instance (stop charges, keep data)
aws ec2 stop-instances --instance-ids <instance-id>

# Start when needed
aws ec2 start-instances --instance-ids <instance-id>

# Automate with Lambda schedule:
# - Stop: 10 PM daily
# - Start: 8 AM daily
# Savings: ~33% ($30 → $20/month)
```

---

## Uninstall/Destroy

### Destroy Everything

```bash
# 1. Back up data first!
ssh ubuntu@$EC2_IP "cd app && ./scripts/backup-data.sh"

# 2. Download backup
scp -i key.pem ubuntu@$EC2_IP:/data/backups/*.tar.gz ./

# 3. Destroy infrastructure
cd terraform-ec2
terraform destroy

# Confirm: yes
```

### Destroy Costs $0

Once destroyed:
-  No EC2 instance charges
-  No EBS storage charges  
-  No data transfer charges
-  Elastic IP released (no charge)

---

## Advanced Topics

### Custom Domain Setup

1. **Register domain** (Route53 or external)
2. **Create A record** pointing to Elastic IP
3. **Update Caddyfile** with domain name
4. **Restart Caddy** for Let's Encrypt SSL

```caddyfile
demo.yourdomain.com {
    reverse_proxy fastapi-app:8000
    tls {
        email admin@yourdomain.com
    }
}
```

### CI/CD Integration

Add GitHub Actions for automated deployment:

```yaml
# .github/workflows/deploy.yml
name: Deploy to EC2
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy to EC2
        run: ./scripts/deploy-updates.sh
        env:
          SSH_KEY: ${{ secrets.EC2_SSH_KEY }}
          EC2_IP: ${{ secrets.EC2_IP }}
```

### Database Migrations

Use Alembic for schema migrations:

```bash
# Install Alembic
pip install alembic

# Initialize
alembic init migrations

# Create migration
alembic revision -m "add_new_table"

# Apply migration
alembic upgrade head
```

---

## FAQ

**Q: Can I run this locally for development?**
A: Yes! Just run `docker-compose up -d` from the `docker-compose/` directory.

**Q: What if I need more than 4GB RAM?**
A: Change `instance_type` in terraform.tfvars to `t3.large` (8GB, ~$60/month) or `t3.xlarge` (16GB, ~$120/month).

**Q: Can I use multiple EC2 instances?**
A: Yes, but you'll need to add a load balancer (ALB) and shared database (RDS), which increases costs.

**Q: Is this production-ready?**
A: For small-scale production (< 10,000 requests/day), yes. For high-traffic, consider multi-instance setup.

**Q: How do I migrate data from DynamoDB?**
A: Use the `scripts/migrate-dynamodb-to-postgres.py` script (coming soon).

**Q: Can I use RDS instead of Docker PostgreSQL?**
A: Yes, update `DATABASE_URL` in .env to point to RDS endpoint. Adds ~$15-30/month.

**Q: What about high availability?**
A: Single EC2 = single point of failure. For HA, deploy multi-AZ with ALB + RDS + replicated storage.

---

## Support & Resources

### Documentation
- Migration Plan: [MIGRATION_PLAN.md](../MIGRATION_PLAN.md)
- API Documentation: http://your-ec2-ip/docs
- Architecture Diagram: [docs/architecture/](docs/architecture/)

### Monitoring
- Grafana: http://your-ec2-ip/grafana
- Prometheus: http://your-ec2-ip/prometheus
- Loki Logs: Via Grafana Explore

### Useful Commands

```bash
# SSH into instance
ssh -i key.pem ubuntu@<ec2-ip>

# View all logs
cd app/docker-compose && docker-compose logs -f

# Restart all services
docker-compose restart

# Update single service
docker-compose up -d --no-deps --build fastapi-app

# Check resource usage
docker stats

# Clean up space
docker system prune -af
```

---

## Success Metrics

After deployment, you should see:

- **API Response Time:** < 100ms (typically ~50ms)
- **Search Query Time:** < 100ms (typically ~20ms)
- **CPU Usage:** < 20% at idle
- **Memory Usage:** ~60-70% (3GB of 4GB)
- **Disk Usage:** < 50% (< 15GB of 30GB)
- **Uptime:** 99.9%+
- **Monthly Cost:** ~$30-35

---

**Status:** Ready for deployment  
**Estimated Setup Time:** 30-45 minutes  
**Monthly Cost:** ~$30-35 (vs $330 for EKS)  
**Savings:** 90%  
**Complexity:** Medium (Docker Compose + Terraform)

---

**Built by:** Portfolio demonstration  
**Purpose:** Cost-optimized cloud architecture  
**Stack:** EC2 + PostgreSQL + Meilisearch + MinIO + Caddy + Prometheus + Grafana  
**Last Updated:** October 18, 2025




