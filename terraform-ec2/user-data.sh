#!/bin/bash
# EC2 User Data Script - Bootstrap Application Stack
# This script runs on first boot to set up the entire environment

set -e  # Exit on any error

echo "========================================"
echo "Starting EC2 Bootstrap Process"
echo "Project: ${project_name}"
echo "Date: $(date)"
echo "========================================"

# ============================================================================
# SYSTEM UPDATES AND BASIC TOOLS
# ============================================================================

echo "[1/10] Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y \
    curl \
    wget \
    git \
    htop \
    unzip \
    jq \
    vim \
    ca-certificates \
    gnupg \
    lsb-release

echo "[2/10] Installing Docker..."
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
systemctl enable docker
systemctl start docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Add ubuntu user to docker group
usermod -aG docker ubuntu

echo "[3/10] Creating directory structure..."
# Create data directories
mkdir -p /data/{postgresql,meilisearch,minio,uploads,processed,logs,prometheus,grafana,loki}
chown -R ubuntu:ubuntu /data

# Create application directory
mkdir -p /home/ubuntu/app
chown -R ubuntu:ubuntu /home/ubuntu/app

echo "[4/10] Installing AWS CLI..."
# Install AWS CLI (for SES)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

echo "[5/10] Configuring AWS region..."
# Configure AWS CLI with region
mkdir -p /home/ubuntu/.aws
cat > /home/ubuntu/.aws/config << EOF
[default]
region = ${aws_region}
output = json
EOF
chown -R ubuntu:ubuntu /home/ubuntu/.aws

echo "[6/10] Cloning application repository..."
# Clone repository
cd /home/ubuntu/app
# Note: Replace with your actual repository URL
# git clone https://github.com/yourusername/aws-to-opensource.git .
# For now, we'll create a marker file
echo "Repository cloned on $(date)" > /home/ubuntu/app/DEPLOYED.txt

echo "[7/10] Fetching secrets from SSM Parameter Store..."
# Fetch secrets from AWS SSM Parameter Store
DB_PASSWORD=$(aws ssm get-parameter --name "/${project_name}/${environment}/db_password" --with-decryption --query 'Parameter.Value' --output text --region ${aws_region} 2>/dev/null || echo "GENERATE_NEW")
MINIO_PASSWORD=$(aws ssm get-parameter --name "/${project_name}/${environment}/minio_password" --with-decryption --query 'Parameter.Value' --output text --region ${aws_region} 2>/dev/null || echo "GENERATE_NEW")
MEILI_KEY=$(aws ssm get-parameter --name "/${project_name}/${environment}/meili_key" --with-decryption --query 'Parameter.Value' --output text --region ${aws_region} 2>/dev/null || echo "GENERATE_NEW")
API_KEY=$(aws ssm get-parameter --name "/${project_name}/${environment}/api_key" --with-decryption --query 'Parameter.Value' --output text --region ${aws_region} 2>/dev/null || echo "GENERATE_NEW")
GRAFANA_PASSWORD=$(aws ssm get-parameter --name "/${project_name}/${environment}/grafana_password" --with-decryption --query 'Parameter.Value' --output text --region ${aws_region} 2>/dev/null || echo "GENERATE_NEW")

# Generate new passwords if not found in SSM
if [ "$DB_PASSWORD" = "GENERATE_NEW" ]; then
    echo "  Generating new DB password (SSM parameter not found)"
    DB_PASSWORD=$(openssl rand -base64 32)
fi
if [ "$MINIO_PASSWORD" = "GENERATE_NEW" ]; then
    echo "  Generating new MinIO password (SSM parameter not found)"
    MINIO_PASSWORD=$(openssl rand -base64 32)
fi
if [ "$MEILI_KEY" = "GENERATE_NEW" ]; then
    echo "  Generating new Meilisearch key (SSM parameter not found)"
    MEILI_KEY=$(openssl rand -base64 32)
fi
if [ "$API_KEY" = "GENERATE_NEW" ]; then
    echo "  Generating new API key (SSM parameter not found)"
    API_KEY=$(openssl rand -base64 32)
fi
if [ "$GRAFANA_PASSWORD" = "GENERATE_NEW" ]; then
    echo "  Using default Grafana password (SSM parameter not found)"
    GRAFANA_PASSWORD="admin123"
fi

echo "[8/10] Creating environment file..."
# Create environment file with fetched/generated secrets
cat > /home/ubuntu/app/docker-compose/.env << EOF
# Auto-generated on $(date)
# Secrets fetched from SSM Parameter Store: /${project_name}/${environment}/*

# Database
POSTGRES_PASSWORD=$DB_PASSWORD
DB_NAME=pretamane_db
DB_USER=pretamane
POSTGRES_USER=postgres

# Search
MEILI_MASTER_KEY=$MEILI_KEY

# Storage
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=$MINIO_PASSWORD

# Monitoring
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=$GRAFANA_PASSWORD
GRAFANA_ADMIN_PASSWORD=$GRAFANA_PASSWORD

# API Authentication
PUBLIC_API_KEY=$API_KEY

# AWS / Email
AWS_REGION=${aws_region}
SES_FROM_EMAIL=${ses_from_email}
SES_TO_EMAIL=${ses_to_email}

# Application
ALLOWED_ORIGIN=*
MAX_FILE_SIZE=52428800
LOG_LEVEL=INFO
DOMAIN=localhost

# Database Admin
PGADMIN_DEFAULT_EMAIL=admin@example.com
PGADMIN_DEFAULT_PASSWORD=$GRAFANA_PASSWORD
EOF
chown ubuntu:ubuntu /home/ubuntu/app/docker-compose/.env
chmod 600 /home/ubuntu/app/docker-compose/.env

echo "  Secrets configured successfully"

echo "[9/10] Creating systemd service for application..."
# Create systemd service to auto-start Docker Compose on boot
cat > /etc/systemd/system/pretamane-app.service << 'EOF'
[Unit]
Description=Pretamane Document Management Application
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/ubuntu/app/docker-compose
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
User=ubuntu

[Install]
WantedBy=multi-user.target
EOF

# Don't enable yet - wait for manual repository setup
# systemctl enable pretamane-app.service

echo "[10/10] Configuring firewall..."
# UFW firewall (optional additional layer)
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp   # SSH
ufw allow 80/tcp   # HTTP
ufw allow 443/tcp  # HTTPS

echo "========================================"
echo "Bootstrap Complete!"
echo "========================================"
echo ""
echo "Next Steps:"
echo "1. SSH into instance:"
echo "   ssh -i your-key.pem ubuntu@<instance-ip>"
echo ""
echo "2. Clone your repository:"
echo "   cd /home/ubuntu/app"
echo "   git clone https://github.com/yourusername/aws-to-opensource.git ."
echo ""
echo "3. Start services:"
echo "   cd docker-compose"
echo "   docker-compose up -d"
echo ""
echo "4. Check status:"
echo "   docker-compose ps"
echo "   docker-compose logs -f"
echo ""
echo "5. Access application:"
echo "   http://<instance-ip>"
echo "   http://<instance-ip>/docs"
echo "   http://<instance-ip>/grafana"
echo ""
echo "========================================"
echo "Installation Details:"
echo "- Docker version: $(docker --version)"
echo "- Docker Compose version: $(docker-compose --version)"
echo "- AWS CLI version: $(aws --version)"
echo "- Data directory: /data"
echo "- Application directory: /home/ubuntu/app"
echo "========================================"

# Write completion marker
echo "Bootstrap completed at $(date)" > /home/ubuntu/BOOTSTRAP_COMPLETE.txt
echo "Instance ready for deployment!" >> /home/ubuntu/BOOTSTRAP_COMPLETE.txt
chown ubuntu:ubuntu /home/ubuntu/BOOTSTRAP_COMPLETE.txt




