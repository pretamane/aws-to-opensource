#!/bin/bash
# EC2 Setup Script - Run this on the EC2 instance after bootstrap

set -e

echo "========================================"
echo "Setting up application on EC2"
echo "========================================"

# ============================================================================
# Create directory structure
# ============================================================================

echo "[1/5] Creating directory structure..."
sudo mkdir -p /data/{postgresql,meilisearch,minio,uploads,processed,logs,prometheus,grafana,loki,backups}
sudo chown -R ubuntu:ubuntu /data
sudo chmod -R 755 /data

echo "Directories created:"
ls -la /data/

# ============================================================================
# Verify Docker installation
# ============================================================================

echo "[2/5] Verifying Docker installation..."
docker --version
docker-compose --version

if ! docker ps > /dev/null 2>&1; then
    echo "Adding user to docker group..."
    sudo usermod -aG docker ubuntu
    echo "Please log out and log back in for group changes to take effect"
    exit 1
fi

# ============================================================================
# Clone repository (if not already done)
# ============================================================================

echo "[3/5] Setting up application code..."
cd /home/ubuntu/app

if [ ! -f "docker-compose/docker-compose.yml" ]; then
    echo "WARNING: Application code not found!"
    echo "Please upload application code or clone repository:"
    echo "  git clone <your-repo-url> ."
    exit 1
fi

# ============================================================================
# Configure environment
# ============================================================================

echo "[4/5] Configuring environment..."
cd /home/ubuntu/app/docker-compose

if [ ! -f ".env" ]; then
    if [ -f "env.example" ]; then
        echo "Creating .env from template..."
        cp env.example .env
        
        # Generate secure random passwords
        POSTGRES_PW=$(openssl rand -base64 32)
        MEILI_KEY=$(openssl rand -base64 32)
        MINIO_PW=$(openssl rand -base64 32)
        
        # Update .env file
        sed -i "s/your_secure_database_password_here/$POSTGRES_PW/" .env
        sed -i "s/your_meilisearch_master_key_min_16_chars/$MEILI_KEY/" .env
        sed -i "s/your_secure_minio_password_min_8_chars/$MINIO_PW/" .env
        
        echo "Generated secure passwords in .env file"
        echo "Please review and update AWS credentials if needed:"
        echo "  nano .env"
    else
        echo "ERROR: env.example not found!"
        exit 1
    fi
else
    echo ".env file already exists"
fi

# ============================================================================
# Pull Docker images
# ============================================================================

echo "[5/5] Pulling Docker images (this may take a few minutes)..."
docker-compose pull

echo ""
echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Review environment file:"
echo "   nano /home/ubuntu/app/docker-compose/.env"
echo ""
echo "2. Start services:"
echo "   cd /home/ubuntu/app/docker-compose"
echo "   docker-compose up -d"
echo ""
echo "3. Check status:"
echo "   docker-compose ps"
echo "   docker-compose logs -f"
echo ""
echo "4. Access application:"
echo "   http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo ""
echo "========================================"


