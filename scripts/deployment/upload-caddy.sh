#!/bin/bash
# Quick Caddyfile upload via SSM

INSTANCE_ID="i-04cdcd73a13f24678"
REGION="ap-southeast-1"

echo "Uploading Caddyfile..."

# Create base64-encoded Caddyfile
CADDYFILE_B64=$(base64 -w 0 /home/guest/aws-to-opensource/docker-compose/config/caddy/Caddyfile)

# Upload via SSM
CMD_ID=$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name AWS-RunShellScript \
  --parameters "commands=[\"echo '$CADDYFILE_B64' | base64 -d > /home/ubuntu/app/docker-compose/config/caddy/Caddyfile\",\"cd /home/ubuntu/app/docker-compose && docker-compose restart caddy\",\"sleep 5\",\"curl -I http://localhost:80\"]" \
  --region "$REGION" \
  --query 'Command.CommandId' \
  --output text)

echo "Command ID: $CMD_ID"
echo "Waiting for upload..."
sleep 5

aws ssm get-command-invocation \
  --command-id "$CMD_ID" \
  --instance-id "$INSTANCE_ID" \
  --region "$REGION" \
  --query 'StandardOutputContent' \
  --output text

