#!/bin/bash
# Script to update credentials on EC2 instance

set -e

INSTANCE_ID="i-0c151e9556e3d35e8"
REGION="ap-southeast-1"

echo "Updating credentials on EC2 instance..."
echo "WARNING: This will recreate all services and delete existing data!"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Step 1: Uploading .env file..."
# Base64 encode the .env file to avoid SSM command size limits
ENV_CONTENT=$(cat docker-compose/.env | base64 -w 0)

aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --document-name "AWS-RunShellScript" \
    --parameters commands="echo '$ENV_CONTENT' | base64 -d > /home/ubuntu/app/docker-compose/.env" \
    --output text

echo "Step 2: Updating PostgreSQL init script..."
INIT_SCRIPT_CONTENT=$(cat docker-compose/init-scripts/postgres/01-init-schema.sql | base64 -w 0)

aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --document-name "AWS-RunShellScript" \
    --parameters commands="echo '$INIT_SCRIPT_CONTENT' | base64 -d > /home/ubuntu/app/docker-compose/init-scripts/postgres/01-init-schema.sql" \
    --output text

echo "Step 3: Backing up existing data (if any)..."
aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --document-name "AWS-RunShellScript" \
    --parameters commands="cd /home/ubuntu/app && sudo ./scripts/backup-data.sh || true" \
    --output text

echo "Step 4: Recreating services with new credentials..."
aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --document-name "AWS-RunShellScript" \
    --parameters commands="cd /home/ubuntu/app/docker-compose && sudo docker-compose down -v && sudo docker-compose up -d" \
    --output text

echo ""
echo "Credentials update initiated!"
echo ""
echo "To monitor the deployment:"
echo "  aws ssm start-session --target $INSTANCE_ID --region $REGION"
echo "  cd /home/ubuntu/app/docker-compose"
echo "  sudo docker-compose logs -f"
echo ""
echo "New credentials:"
echo "  Username: pretamane"
echo "  Password: #ThawZin2k77!"
echo ""
echo "Access URLs:"
echo "  Homepage:  https://54-179-230-219.sslip.io"
echo "  Grafana:   https://54-179-230-219.sslip.io/grafana"
echo "  pgAdmin:   https://54-179-230-219.sslip.io/pgadmin"
echo "  MinIO:     http://54.179.230.219:9001"
