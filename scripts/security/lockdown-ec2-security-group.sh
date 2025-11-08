#!/bin/bash
# Lockdown EC2 Security Group - Remove Public HTTP/HTTPS Access
# Only allow SSM + SSH (restricted to your IP)

set -e

INSTANCE_ID="${1:-i-0c151e9556e3d35e8}"
REGION="${2:-ap-southeast-1}"
YOUR_IP="${3:-}"  # Pass your home IP as third argument

echo "=========================================="
echo "  EC2 Security Group Lockdown"
echo "=========================================="
echo "Instance ID: $INSTANCE_ID"
echo "Region: $REGION"
echo ""

# Get security group ID
echo "[1/4] Getting security group ID..."
SG_ID=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
    --output text)

echo "Security Group ID: $SG_ID"
echo ""

# Remove public HTTP/HTTPS access (ports 80, 443)
echo "[2/4] Removing public HTTP/HTTPS access (ports 80, 443)..."

# Remove HTTP
aws ec2 revoke-security-group-ingress \
    --group-id "$SG_ID" \
    --region "$REGION" \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 2>/dev/null || echo "  HTTP rule already removed or doesn't exist"

# Remove HTTPS
aws ec2 revoke-security-group-ingress \
    --group-id "$SG_ID" \
    --region "$REGION" \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 2>/dev/null || echo "  HTTPS rule already removed or doesn't exist"

echo "  Public HTTP/HTTPS access removed"
echo ""

# Restrict SSH if IP provided
if [ -n "$YOUR_IP" ]; then
    echo "[3/4] Restricting SSH to your IP ($YOUR_IP)..."
    
    # Remove existing SSH rules
    aws ec2 revoke-security-group-ingress \
        --group-id "$SG_ID" \
        --region "$REGION" \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 2>/dev/null || echo "  No public SSH rule to remove"
    
    # Add restricted SSH rule
    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" \
        --region "$REGION" \
        --protocol tcp \
        --port 22 \
        --cidr "$YOUR_IP/32" 2>/dev/null || echo "  SSH rule for $YOUR_IP already exists"
    
    echo "  SSH now restricted to $YOUR_IP"
else
    echo "[3/4] Skipping SSH restriction (no IP provided)"
    echo "  To restrict SSH, run: $0 $INSTANCE_ID $REGION YOUR_IP"
fi
echo ""

# Verify final rules
echo "[4/4] Current security group rules:"
aws ec2 describe-security-groups \
    --group-ids "$SG_ID" \
    --region "$REGION" \
    --query 'SecurityGroups[0].IpPermissions[*].[IpProtocol,FromPort,ToPort,IpRanges[0].CidrIp]' \
    --output table

echo ""
echo "=========================================="
echo "  Lockdown Complete!"
echo "=========================================="
echo ""
echo "IMPORTANT NOTES:"
echo "- HTTP (80) and HTTPS (443) are now BLOCKED from public internet"
echo "- Your application is ONLY accessible via Cloudflare Tunnel"
echo "- SSM Session Manager still works for remote access"
if [ -n "$YOUR_IP" ]; then
    echo "- SSH restricted to: $YOUR_IP"
else
    echo "- SSH rules unchanged (consider restricting to your IP)"
fi
echo ""
echo "To access your application:"
echo "1. Start Cloudflare Tunnel: docker-compose up -d cloudflared"
echo "2. Check tunnel logs: docker logs cloudflared"
echo "3. Look for the public URL (*.trycloudflare.com)"
echo ""



