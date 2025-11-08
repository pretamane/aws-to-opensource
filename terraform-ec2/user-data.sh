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

echo "[7/10] Generating environment file..."
# Create environment file with secrets
cat > /home/ubuntu/app/docker-compose/.env << EOF
# Auto-generated on $(date)
POSTGRES_PASSWORD=$(openssl rand -base64 32)
MEILI_MASTER_KEY=$(openssl rand -base64 32)
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=$(openssl rand -base64 32)
GRAFANA_ADMIN_PASSWORD=admin123
AWS_REGION=${aws_region}
SES_FROM_EMAIL=${ses_from_email}
SES_TO_EMAIL=${ses_to_email}
ALLOWED_ORIGIN=*
MAX_FILE_SIZE=52428800
LOG_LEVEL=INFO
DOMAIN=localhost
EOF
chown ubuntu:ubuntu /home/ubuntu/app/docker-compose/.env
chmod 600 /home/ubuntu/app/docker-compose/.env

echo "[8/10] Setting up Docker Compose services..."
# Note: Docker Compose will be started manually or via systemd
# We don't auto-start here to allow for repository setup first

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




