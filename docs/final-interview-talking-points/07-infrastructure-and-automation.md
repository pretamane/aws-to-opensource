# Infrastructure & Automation

## Overview
End-to-end automation from AWS provisioning to daily operations using Terraform, Docker Compose, and shell scripts.

## Terraform: Infrastructure as Code

### What We Provision
- VPC with single public subnet
- Internet Gateway + Route Table
- Security Groups (HTTP, HTTPS, SSH)
- EC2 instance (t3.medium)
- Elastic IP (optional, stable addressing)
- IAM Role + Instance Profile (SES, S3, SSM access)
- User-data bootstrap script

### Files
- `terraform-ec2/main.tf` - Resource definitions
- `terraform-ec2/variables.tf` - Configurable parameters
- `terraform-ec2/terraform.tfvars` - Actual values (gitignored)
- `terraform-ec2/user-data.sh` - Bootstrap script

### Key Resources

#### VPC & Networking
```hcl
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}
```

#### Security Groups
```hcl
resource "aws_security_group" "app_server" {
  name        = "${var.project_name}-app-server-sg"
  description = "Security group for application server"
  vpc_id      = aws_vpc.main.id

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH (restrict in production)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidrs  # ["YOUR_IP/32"]
  }

  # Outbound - allow all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

**Interview Point**: "Security groups are stateful firewalls. I restricted SSH to specific IPs and allowed HTTP/HTTPS from anywhere. Egress is open because services need to download packages, reach APIs, etc."

#### IAM Role (Least Privilege)
```hcl
resource "aws_iam_role" "ec2_app_role" {
  name = "${var.project_name}-ec2-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# SES sending permissions
resource "aws_iam_role_policy" "ses_send_policy" {
  name = "${var.project_name}-ses-send-policy"
  role = aws_iam_role.ec2_app_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ses:SendEmail",
        "ses:SendRawEmail"
      ]
      Resource = "*"
    }]
  })
}

# SSM Session Manager (SSH-less access)
resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ec2_app_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```

**Interview Point**: "IAM role grants only SES and SSM permissions—least privilege principle. No hardcoded credentials. SSM Session Manager enables SSH-less access for better security and audit trail."

#### EC2 Instance
```hcl
resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type  # t3.medium
  subnet_id     = aws_subnet.public.id

  vpc_security_group_ids = [aws_security_group.app_server.id]
  iam_instance_profile   = aws_iam_instance_profile.app_server.name
  key_name               = var.key_name

  root_block_device {
    volume_size           = var.root_volume_size  # 30GB
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  user_data = templatefile("${path.module}/user-data.sh", {
    project_name   = var.project_name
    aws_region     = var.region
    ses_from_email = var.ses_from_email
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2
    http_put_response_hop_limit = 1
  }

  monitoring = true  # Detailed CloudWatch monitoring

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}
```

**Key Security Features**:
- Encrypted EBS volumes
- IMDSv2 required (prevents SSRF attacks)
- Detailed monitoring enabled

### User-Data Bootstrap Script
```bash
#!/bin/bash
set -e

# Update system
apt-get update
apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create directories
mkdir -p /data/{postgres,minio,prometheus,grafana,loki}
chown -R ubuntu:ubuntu /data

# Clone repository (in production, use private repo with deploy key)
cd /home/ubuntu
git clone https://github.com/your-repo/aws-to-opensource.git app
chown -R ubuntu:ubuntu app

# Set up environment
cd app/docker-compose
cp env.example .env
# In production: inject secrets from AWS Secrets Manager/Parameter Store

# Start services
docker-compose up -d

echo "Bootstrap complete. Application starting..."
```

**Interview Point**: "User-data runs once on first boot. It installs Docker, clones the repo, and starts services. For production, I'd inject secrets from AWS Secrets Manager instead of hardcoding in .env."

### Terraform Workflow
```bash
# Initialize
cd terraform-ec2
terraform init

# Plan (preview changes)
terraform plan -out=tfplan

# Apply
terraform apply tfplan

# Get outputs
EC2_IP=$(terraform output -raw instance_public_ip)
echo "Application: http://$EC2_IP"

# Destroy (cleanup)
terraform destroy
```

## Docker Compose: Service Orchestration

### Orchestration Features

#### Dependency Management
```yaml
fastapi-app:
  depends_on:
    - postgresql
    - meilisearch
    - minio
```

**Problem**: `depends_on` only waits for container start, not readiness.

**Solution**: Health checks
```yaml
postgresql:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U pretamane"]
    interval: 10s
    timeout: 5s
    retries: 5

fastapi-app:
  depends_on:
    postgresql:
      condition: service_healthy
```

#### Restart Policies
```yaml
services:
  fastapi-app:
    restart: unless-stopped  # Restart on crash, not on manual stop
  
  minio-setup:
    restart: "no"  # Init job, run once
```

**Interview Point**: "`unless-stopped` provides automatic recovery from crashes while respecting manual stops. This balances resilience with operational control."

#### Named Volumes
```yaml
volumes:
  postgres-data:     # Docker-managed, durable
  minio-data:
  prometheus-data:
  
# Not:
#   - ./data/postgres:/var/lib/postgresql/data  # Host bind mount, path issues
```

**Interview Point**: "Named volumes are Docker-managed and portable across hosts. Bind mounts are tied to host paths and cause permission issues in production."

## Deployment Scripts

### Main Deployment Script
```bash
#!/bin/bash
# scripts/deploy-opensource.sh

set -e

EC2_IP="$1"
SSH_KEY="${SSH_KEY:-~/.ssh/aws-key.pem}"

echo "Deploying to $EC2_IP..."

# 1. Build application (if needed)
docker build -t pretamane-app:latest -f docker/api/Dockerfile.opensource docker/api

# 2. Save image
docker save pretamane-app:latest | gzip > /tmp/app-image.tar.gz

# 3. Upload to EC2
scp -i "$SSH_KEY" /tmp/app-image.tar.gz ubuntu@$EC2_IP:/tmp/

# 4. Load and restart
ssh -i "$SSH_KEY" ubuntu@$EC2_IP << 'EOF'
  cd ~/app/docker-compose
  
  # Load new image
  docker load < /tmp/app-image.tar.gz
  
  # Pull latest code
  cd ~/app
  git pull origin main
  
  # Restart services
  cd docker-compose
  docker-compose pull  # Update base images
  docker-compose up -d --build
  
  # Health check
  sleep 10
  curl -f http://localhost:8080/health || exit 1
  
  echo "Deployment successful"
EOF

echo "Deployment complete!"
```

### Backup Script
```bash
#!/bin/bash
# scripts/backup-data.sh

BACKUP_DIR="/tmp/backups"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="backup-$DATE.tar.gz"

mkdir -p "$BACKUP_DIR"

# Backup PostgreSQL
docker exec postgresql pg_dump -U pretamane pretamane_db > "$BACKUP_DIR/postgres-$DATE.sql"

# Backup MinIO
docker exec minio mc mirror myminio/pretamane-data "$BACKUP_DIR/minio-data/"

# Backup Prometheus
docker exec prometheus tar -czf - /prometheus > "$BACKUP_DIR/prometheus-$DATE.tar.gz"

# Create archive
tar -czf "$BACKUP_DIR/$BACKUP_FILE" "$BACKUP_DIR"/*-$DATE*

# Upload to S3 (optional)
# aws s3 cp "$BACKUP_DIR/$BACKUP_FILE" s3://backups/

# Cleanup old backups (keep 7 days)
find "$BACKUP_DIR" -name "backup-*.tar.gz" -mtime +7 -delete

echo "Backup complete: $BACKUP_FILE"
```

### Health Check Script
```bash
#!/bin/bash
# scripts/health-check.sh

HOST="${1:-localhost:8080}"

# Check main API
if ! curl -f -s "http://$HOST/health" > /dev/null; then
  echo "ERROR: API health check failed"
  exit 1
fi

# Check metrics
if ! curl -f -s "http://$HOST/metrics" > /dev/null; then
  echo "ERROR: Metrics endpoint failed"
  exit 1
fi

# Check Grafana
if ! curl -f -s "http://$HOST/grafana/api/health" > /dev/null; then
  echo "WARNING: Grafana health check failed"
fi

# Check Docker containers
UNHEALTHY=$(docker ps -a --filter "health=unhealthy" --format "{{.Names}}")
if [ -n "$UNHEALTHY" ]; then
  echo "ERROR: Unhealthy containers: $UNHEALTHY"
  exit 1
fi

echo "All health checks passed"
```

## Configuration Management

### Environment Variables
```bash
# docker-compose/.env
APP_NAME=pretamane
ENVIRONMENT=production

# Database
DB_NAME=pretamane_db
DB_USER=pretamane
DB_PASSWORD='secure-password-here'

# MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD='another-secure-password'

# Meilisearch
MEILI_MASTER_KEY='yet-another-secure-key'

# AWS
AWS_REGION=ap-southeast-1
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
SES_FROM_EMAIL=noreply@example.com
SES_TO_EMAIL=alerts@example.com
```

**Production Improvement**: Use AWS Secrets Manager or HashiCorp Vault instead of .env files.

### Configuration Files
```
docker-compose/config/
├─ caddy/
│  └─ Caddyfile                    # Reverse proxy routes
├─ prometheus/
│  ├─ prometheus.yml               # Scrape targets
│  └─ alert-rules.yml              # Alert definitions
├─ grafana/
│  ├─ provisioning/
│  │  ├─ datasources/              # Auto-configure Prometheus/Loki
│  │  └─ dashboards/               # Auto-import dashboards
│  └─ dashboards/
│     └─ application-dashboard.json
├─ loki/
│  └─ loki-config.yml              # Log storage config
└─ promtail/
   └─ promtail-config.yml          # Log shipping config
```

## Monitoring Deployment Health

### Post-Deployment Checks
```bash
# 1. Container status
docker-compose ps

# 2. Health checks
docker-compose ps | grep "healthy"

# 3. Logs
docker-compose logs -f --tail=50 fastapi-app

# 4. Resource usage
docker stats --no-stream

# 5. Endpoint tests
curl http://localhost:8080/health
curl http://localhost:8080/metrics | grep http_requests_total
```

### Rollback Strategy
```bash
# 1. Keep previous image tagged
docker tag pretamane-app:latest pretamane-app:previous

# 2. If deployment fails, rollback
docker tag pretamane-app:previous pretamane-app:latest
docker-compose up -d --no-build

# 3. Verify
curl http://localhost:8080/health
```

## CI/CD Pipeline (Future)

### GitHub Actions Example
```yaml
name: Deploy to EC2

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Build Docker image
        run: docker build -t pretamane-app:latest .
      
      - name: Run tests
        run: docker run pretamane-app:latest pytest
      
      - name: Deploy to EC2
        env:
          SSH_KEY: ${{ secrets.EC2_SSH_KEY }}
          EC2_IP: ${{ secrets.EC2_IP }}
        run: |
          ./scripts/deploy-opensource.sh "$EC2_IP"
      
      - name: Health check
        run: |
          sleep 30
          curl -f "http://$EC2_IP/health"
```

## Interview Talking Points

**"Explain your infrastructure automation"**
> "I use Terraform to provision AWS resources (VPC, EC2, IAM, security groups) and Docker Compose to orchestrate services. User-data bootstraps the instance with Docker and starts the stack automatically. Deployment scripts handle updates with health checks and rollback capability. Everything is version-controlled and repeatable."

**"How do you handle secrets?"**
> "Currently .env files (gitignored), but for production I'd use AWS Secrets Manager or Parameter Store, injected at runtime via user-data or ECS task definitions. Secrets rotate regularly, never committed to git. IAM roles provide AWS access without hardcoded credentials."

**"What's your deployment strategy?"**
> "Blue-green for zero downtime: run new version on separate instance, verify health, switch traffic via load balancer, keep old version for quick rollback. For this single-instance demo, I use rolling update with health checks and keep previous Docker image for rollback."

**"How would you scale this infrastructure?"**
> "Add Auto Scaling Group with ALB for horizontal scaling, move PostgreSQL to RDS with read replicas, use ElastiCache for session storage, and migrate to ECS/EKS for container orchestration. Or keep it simple: bigger EC2 instance for vertical scaling. Depends on growth patterns."

**"What's your disaster recovery plan?"**
> "Daily automated backups to S3 (PostgreSQL dumps, MinIO data, Prometheus/Grafana configs). Terraform state enables infrastructure recreation in 10 minutes. Docker Compose brings up services in 5 minutes. RTO: 15 minutes. RPO: 24 hours (daily backups). For stricter RPO, enable continuous replication."

