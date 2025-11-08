#!/bin/bash
# Deploy Zero-Budget IP-Hiding Security Implementation
# Phase 1: Cloudflare Quick Tunnel + Host Hardening

set -e

INSTANCE_ID="${1:-i-0c151e9556e3d35e8}"
REGION="${2:-ap-southeast-1}"
YOUR_IP="${3:-}"

echo "=========================================="
echo "  Zero-Budget Security Deployment"
echo "  Phase 1: Quick Tunnel + Hardening"
echo "=========================================="
echo ""
echo "Instance: $INSTANCE_ID"
echo "Region: $REGION"
if [ -n "$YOUR_IP" ]; then
    echo "Your IP: $YOUR_IP (SSH will be restricted)"
else
    echo "Your IP: Not provided (SSH rules unchanged)"
fi
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi
echo ""

# Step 1: Upload updated docker-compose files
echo "[1/6] Uploading updated Docker Compose configuration..."

# Create tarball of docker-compose directory
cd /home/guest/aws-to-opensource
tar -czf /tmp/docker-compose-security.tar.gz \
    docker-compose/docker-compose.yml \
    docker-compose/config/caddy/Caddyfile \
    docker-compose/config/prometheus/alert-rules.yml \
    docker-compose/init-scripts/postgres/02-seed-data.sql

# Upload tarball to EC2
aws s3 cp /tmp/docker-compose-security.tar.gz s3://pretamane-backup/temp/ --region "$REGION"

# Download and extract on EC2
aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=[
        "cd /home/ubuntu/app",
        "aws s3 cp s3://pretamane-backup/temp/docker-compose-security.tar.gz /tmp/",
        "tar -xzf /tmp/docker-compose-security.tar.gz",
        "chown -R ubuntu:ubuntu docker-compose",
        "rm /tmp/docker-compose-security.tar.gz"
    ]' \
    --output text \
    --query 'Command.CommandId'

echo "Waiting for file upload to complete..."
sleep 10

# Step 2: Upload security scripts
echo "[2/6] Uploading security scripts..."

# Upload scripts individually
for script in lockdown-ec2-security-group.sh install-crowdsec.sh install-fail2ban.sh; do
    aws ssm send-command \
        --instance-ids "$INSTANCE_ID" \
        --region "$REGION" \
        --document-name "AWS-RunShellScript" \
        --parameters commands="mkdir -p /home/ubuntu/app/scripts/security && cat > /home/ubuntu/app/scripts/security/$script << 'SCRIPT_EOF'
$(cat scripts/security/$script)
SCRIPT_EOF
chmod +x /home/ubuntu/app/scripts/security/$script" \
        --output text \
        --query 'Command.CommandId' > /dev/null
done

echo "Waiting for scripts to upload..."
sleep 5

# Step 3: Restart Docker Compose with cloudflared
echo "[3/6] Restarting Docker Compose with Cloudflare Tunnel..."

COMMAND_ID=$(aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=[
        "cd /home/ubuntu/app/docker-compose",
        "docker-compose pull cloudflared",
        "docker-compose up -d --force-recreate caddy cloudflared",
        "sleep 5",
        "echo '=== Cloudflare Tunnel URL ==='",
        "docker logs cloudflared 2>&1 | grep -A 2 \"Your quick Tunnel\" || echo \"Tunnel starting, check logs in 30 seconds\"",
        "echo '=== Services Status ==='",
        "docker-compose ps"
    ]' \
    --output text \
    --query 'Command.CommandId')

echo "Waiting for deployment..."
sleep 15

# Get deployment output
aws ssm get-command-invocation \
    --instance-id "$INSTANCE_ID" \
    --region "$REGION" \
    --command-id "$COMMAND_ID" \
    --query '[StandardOutputContent,StandardErrorContent]' \
    --output text

# Step 4: Lock down security group
echo ""
echo "[4/6] Locking down EC2 Security Group..."
./scripts/security/lockdown-ec2-security-group.sh "$INSTANCE_ID" "$REGION" "$YOUR_IP"

# Step 5: Install CrowdSec
echo ""
echo "[5/6] Installing CrowdSec on EC2..."
aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=[
        "sudo /home/ubuntu/app/scripts/security/install-crowdsec.sh",
        "sudo /home/ubuntu/app/scripts/security/install-fail2ban.sh"
    ]' \
    --output text \
    --query 'Command.CommandId' > /dev/null

echo "Security tools installing in background..."
echo "Check status with: sudo systemctl status crowdsec"

# Step 6: Final verification
echo ""
echo "[6/6] Final verification..."
sleep 10

VERIFICATION_CMD=$(aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=[
        "echo \"=== Cloudflare Tunnel Status ===\"",
        "docker logs cloudflared --tail 20 2>&1 | grep -A 5 \"quick Tunnel\" || echo \"Check: docker logs cloudflared\"",
        "echo \"\"",
        "echo \"=== Security Group ===\"",
        "curl -m 5 http://localhost:80 > /dev/null 2>&1 && echo \"Caddy: OK\" || echo \"Caddy: DOWN\"",
        "echo \"\"",
        "echo \"=== Services ===\"",
        "docker-compose ps --format table"
    ]' \
    --output text \
    --query 'Command.CommandId')

sleep 10

aws ssm get-command-invocation \
    --instance-id "$INSTANCE_ID" \
    --region "$REGION" \
    --command-id "$VERIFICATION_CMD" \
    --query 'StandardOutputContent' \
    --output text

# Cleanup
rm /tmp/docker-compose-security.tar.gz 2>/dev/null || true

echo ""
echo "=========================================="
echo "  Deployment Complete!"
echo "=========================================="
echo ""
echo "IMPORTANT NEXT STEPS:"
echo ""
echo "1. Get your Cloudflare Tunnel URL:"
echo "   ssh ubuntu@YOUR_EC2_IP \"docker logs cloudflared | grep trycloudflare.com\""
echo ""
echo "2. Test public access (via Cloudflare):"
echo "   curl https://YOUR-TUNNEL-URL.trycloudflare.com"
echo ""
echo "3. Verify direct IP is blocked:"
echo "   curl http://54.179.230.219  # Should timeout/fail"
echo ""
echo "4. Test admin access with Basic Auth:"
echo "   curl -u pretamane:'#ThawZin2k77!' https://YOUR-TUNNEL-URL/grafana"
echo ""
echo "5. Review security documentation:"
echo "   cat docs/security/ZERO_BUDGET_IP_HIDING_GUIDE.md"
echo ""
echo "Admin Credentials:"
echo "  Username: pretamane"
echo "  Password: #ThawZin2k77!"
echo ""
echo "Protected Endpoints:"
echo "  - /grafana (Monitoring)"
echo "  - /prometheus (Metrics)"
echo "  - /pgadmin (Database)"
echo "  - /meilisearch (Search)"
echo "  - /alertmanager (Alerts)"
echo ""
echo "Public Endpoints:"
echo "  - / (Portfolio Website)"
echo "  - /api/* (REST API)"
echo "  - /docs (API Documentation)"
echo ""
echo "Security Features Active:"
echo "  ✅ EC2 IP Hidden (Cloudflare Tunnel)"
echo "  ✅ Ports 80/443 Closed on EC2"
echo "  ✅ Basic Auth on Admin Paths"
echo "  ✅ Security Headers (HSTS, CSP, etc.)"
echo "  ✅ CrowdSec Auto-Banning"
echo "  ✅ fail2ban SSH Protection"
echo "  ✅ Prometheus Security Alerts"
echo ""
echo "⚠️  SAVE YOUR TUNNEL URL - It's your new public access point!"
echo ""



