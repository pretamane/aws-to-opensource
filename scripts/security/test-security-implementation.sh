#!/bin/bash
# Test Zero-Budget IP-Hiding Security Implementation
# Verifies all security features are working correctly

set -e

INSTANCE_ID="${1:-i-0c151e9556e3d35e8}"
REGION="${2:-ap-southeast-1}"
TUNNEL_URL="${3:-}"

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║          ZERO-BUDGET SECURITY - COMPREHENSIVE TEST SUITE                     ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
}

fail() {
    echo -e "${RED}❌ FAIL${NC}: $1"
}

warn() {
    echo -e "${YELLOW}⚠️  WARN${NC}: $1"
}

info() {
    echo "ℹ️  INFO: $1"
}

# Get EC2 public IP
echo "[0/10] Getting EC2 instance details..."
EC2_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

info "EC2 Instance: $INSTANCE_ID"
info "EC2 Public IP: $EC2_IP"
echo ""

# Test 1: Get Cloudflare Tunnel URL (if not provided)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[1/10] TEST: Cloudflare Tunnel Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -z "$TUNNEL_URL" ]; then
    info "Retrieving Cloudflare Tunnel URL from EC2..."
    
    TUNNEL_URL=$(ssh -o StrictHostKeyChecking=no ubuntu@$EC2_IP \
        "docker logs cloudflared 2>&1 | grep -oP 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1" 2>/dev/null || echo "")
    
    if [ -z "$TUNNEL_URL" ]; then
        warn "Could not retrieve tunnel URL automatically"
        echo "Please run: ssh ubuntu@$EC2_IP \"docker logs cloudflared | grep trycloudflare.com\""
        echo "Then re-run this script with: $0 $INSTANCE_ID $REGION YOUR_TUNNEL_URL"
        exit 1
    fi
fi

info "Tunnel URL: $TUNNEL_URL"

# Check if cloudflared is running
TUNNEL_RUNNING=$(ssh -o StrictHostKeyChecking=no ubuntu@$EC2_IP \
    "docker ps | grep cloudflared" 2>/dev/null || echo "")

if [ -n "$TUNNEL_RUNNING" ]; then
    pass "Cloudflare Tunnel container is running"
else
    fail "Cloudflare Tunnel container is NOT running"
fi
echo ""

# Test 2: Direct IP Access (Should FAIL)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[2/10] TEST: Direct IP Access (Should be BLOCKED)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

info "Testing HTTP access to $EC2_IP (port 80)..."
HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://$EC2_IP 2>/dev/null || echo "000")

if [ "$HTTP_RESPONSE" = "000" ] || [ "$HTTP_RESPONSE" = "timeout" ]; then
    pass "Direct HTTP access is BLOCKED (EC2 IP hidden) ✅"
else
    fail "Direct HTTP access still works (got HTTP $HTTP_RESPONSE) - IP NOT HIDDEN!"
fi

info "Testing HTTPS access to $EC2_IP (port 443)..."
HTTPS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 https://$EC2_IP 2>/dev/null || echo "000")

if [ "$HTTPS_RESPONSE" = "000" ] || [ "$HTTPS_RESPONSE" = "timeout" ]; then
    pass "Direct HTTPS access is BLOCKED (EC2 IP hidden) ✅"
else
    fail "Direct HTTPS access still works (got HTTP $HTTPS_RESPONSE) - IP NOT HIDDEN!"
fi
echo ""

# Test 3: Cloudflare Tunnel Access (Should WORK)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[3/10] TEST: Cloudflare Tunnel Access (Should WORK)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

info "Testing public access via Cloudflare Tunnel..."
TUNNEL_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 $TUNNEL_URL 2>/dev/null || echo "000")

if [ "$TUNNEL_RESPONSE" = "200" ]; then
    pass "Cloudflare Tunnel is working (HTTP 200) ✅"
elif [ "$TUNNEL_RESPONSE" = "000" ]; then
    fail "Cloudflare Tunnel is NOT responding (timeout/connection error)"
else
    warn "Cloudflare Tunnel returned HTTP $TUNNEL_RESPONSE (expected 200)"
fi

# Test API health endpoint
info "Testing API health endpoint..."
HEALTH_RESPONSE=$(curl -s $TUNNEL_URL/health | grep -o '"status":"healthy"' || echo "")

if [ -n "$HEALTH_RESPONSE" ]; then
    pass "API health endpoint is accessible and healthy"
else
    warn "API health endpoint not returning expected response"
fi
echo ""

# Test 4: Basic Auth on Admin Paths (Should REQUIRE AUTH)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[4/10] TEST: Basic Auth Protection (Admin Paths)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test Grafana without auth (should fail with 401)
info "Testing Grafana without credentials (should get 401)..."
GRAFANA_NOAUTH=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 $TUNNEL_URL/grafana 2>/dev/null || echo "000")

if [ "$GRAFANA_NOAUTH" = "401" ]; then
    pass "Grafana requires authentication (HTTP 401) ✅"
elif [ "$GRAFANA_NOAUTH" = "200" ]; then
    fail "Grafana is NOT protected - accessible without auth!"
else
    warn "Grafana returned HTTP $GRAFANA_NOAUTH (expected 401)"
fi

# Test Grafana WITH auth (should work with 200)
info "Testing Grafana WITH credentials (should get 200)..."
GRAFANA_AUTH=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    -u "pretamane:#ThawZin2k77!" $TUNNEL_URL/grafana 2>/dev/null || echo "000")

if [ "$GRAFANA_AUTH" = "200" ] || [ "$GRAFANA_AUTH" = "302" ]; then
    pass "Grafana accessible with correct credentials ✅"
else
    fail "Grafana NOT accessible with credentials (got HTTP $GRAFANA_AUTH)"
fi

# Test Prometheus
info "Testing Prometheus without credentials (should get 401)..."
PROM_NOAUTH=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 $TUNNEL_URL/prometheus 2>/dev/null || echo "000")

if [ "$PROM_NOAUTH" = "401" ]; then
    pass "Prometheus requires authentication (HTTP 401) ✅"
else
    warn "Prometheus protection: HTTP $PROM_NOAUTH (expected 401)"
fi
echo ""

# Test 5: Security Headers
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[5/10] TEST: Security Headers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

info "Checking security headers in HTTP response..."
HEADERS=$(curl -s -I $TUNNEL_URL 2>/dev/null)

# Check HSTS
if echo "$HEADERS" | grep -i "Strict-Transport-Security" > /dev/null; then
    pass "HSTS header present"
else
    warn "HSTS header missing"
fi

# Check X-Content-Type-Options
if echo "$HEADERS" | grep -i "X-Content-Type-Options.*nosniff" > /dev/null; then
    pass "X-Content-Type-Options: nosniff header present"
else
    warn "X-Content-Type-Options header missing"
fi

# Check X-Frame-Options
if echo "$HEADERS" | grep -i "X-Frame-Options" > /dev/null; then
    pass "X-Frame-Options header present"
else
    warn "X-Frame-Options header missing"
fi

# Check CSP
if echo "$HEADERS" | grep -i "Content-Security-Policy" > /dev/null; then
    pass "Content-Security-Policy header present"
else
    warn "Content-Security-Policy header missing"
fi
echo ""

# Test 6: EC2 Security Group Rules
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[6/10] TEST: EC2 Security Group Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SG_ID=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
    --output text)

info "Security Group: $SG_ID"

# Check if port 80 is open to 0.0.0.0/0
PORT_80_OPEN=$(aws ec2 describe-security-groups \
    --group-ids "$SG_ID" \
    --region "$REGION" \
    --query 'SecurityGroups[0].IpPermissions[?FromPort==`80` && ToPort==`80`].IpRanges[?CidrIp==`0.0.0.0/0`]' \
    --output text)

if [ -z "$PORT_80_OPEN" ]; then
    pass "Port 80 is NOT open to public (0.0.0.0/0) ✅"
else
    fail "Port 80 is still OPEN to public - security group not locked down!"
fi

# Check if port 443 is open to 0.0.0.0/0
PORT_443_OPEN=$(aws ec2 describe-security-groups \
    --group-ids "$SG_ID" \
    --region "$REGION" \
    --query 'SecurityGroups[0].IpPermissions[?FromPort==`443` && ToPort==`443`].IpRanges[?CidrIp==`0.0.0.0/0`]' \
    --output text)

if [ -z "$PORT_443_OPEN" ]; then
    pass "Port 443 is NOT open to public (0.0.0.0/0) ✅"
else
    fail "Port 443 is still OPEN to public - security group not locked down!"
fi
echo ""

# Test 7: CrowdSec Status
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[7/10] TEST: CrowdSec Installation & Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

CROWDSEC_INSTALLED=$(ssh -o StrictHostKeyChecking=no ubuntu@$EC2_IP \
    "command -v cscli" 2>/dev/null || echo "")

if [ -n "$CROWDSEC_INSTALLED" ]; then
    pass "CrowdSec is installed"
    
    # Check if CrowdSec is running
    CROWDSEC_RUNNING=$(ssh -o StrictHostKeyChecking=no ubuntu@$EC2_IP \
        "sudo systemctl is-active crowdsec" 2>/dev/null || echo "")
    
    if [ "$CROWDSEC_RUNNING" = "active" ]; then
        pass "CrowdSec service is running"
        
        # Get metrics
        info "CrowdSec metrics:"
        ssh -o StrictHostKeyChecking=no ubuntu@$EC2_IP \
            "sudo cscli metrics 2>/dev/null | head -15" || echo "  (metrics unavailable)"
    else
        warn "CrowdSec is installed but not running"
    fi
else
    warn "CrowdSec is not installed (run install-crowdsec.sh)"
fi
echo ""

# Test 8: fail2ban Status
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[8/10] TEST: fail2ban Installation & Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

FAIL2BAN_INSTALLED=$(ssh -o StrictHostKeyChecking=no ubuntu@$EC2_IP \
    "command -v fail2ban-client" 2>/dev/null || echo "")

if [ -n "$FAIL2BAN_INSTALLED" ]; then
    pass "fail2ban is installed"
    
    # Check if fail2ban is running
    FAIL2BAN_RUNNING=$(ssh -o StrictHostKeyChecking=no ubuntu@$EC2_IP \
        "sudo systemctl is-active fail2ban" 2>/dev/null || echo "")
    
    if [ "$FAIL2BAN_RUNNING" = "active" ]; then
        pass "fail2ban service is running"
        
        # Get SSH jail status
        info "fail2ban SSH jail status:"
        ssh -o StrictHostKeyChecking=no ubuntu@$EC2_IP \
            "sudo fail2ban-client status sshd 2>/dev/null" || echo "  (status unavailable)"
    else
        warn "fail2ban is installed but not running"
    fi
else
    warn "fail2ban is not installed (run install-fail2ban.sh)"
fi
echo ""

# Test 9: Docker Services Status
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[9/10] TEST: Docker Services Health"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

info "Checking critical services..."

# List of critical services
CRITICAL_SERVICES=("cloudflared" "caddy" "fastapi-app" "postgresql" "prometheus" "grafana")

for service in "${CRITICAL_SERVICES[@]}"; do
    SERVICE_RUNNING=$(ssh -o StrictHostKeyChecking=no ubuntu@$EC2_IP \
        "docker ps --format '{{.Names}}' | grep $service" 2>/dev/null || echo "")
    
    if [ -n "$SERVICE_RUNNING" ]; then
        pass "$service is running"
    else
        fail "$service is NOT running"
    fi
done
echo ""

# Test 10: Prometheus Alerts
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[10/10] TEST: Prometheus Security Alerts Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if security alerts are loaded
ALERTS_CHECK=$(ssh -o StrictHostKeyChecking=no ubuntu@$EC2_IP \
    "docker exec prometheus wget -qO- http://localhost:9090/api/v1/rules 2>/dev/null | grep -o 'High4xxErrorRate\|High5xxErrorRate\|RequestRateSpike' | wc -l" 2>/dev/null || echo "0")

if [ "$ALERTS_CHECK" -gt 0 ]; then
    pass "Security alert rules are loaded in Prometheus"
    info "Found $ALERTS_CHECK security-related alerts"
else
    warn "Security alert rules not detected in Prometheus"
fi
echo ""

# Final Summary
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                            TEST SUMMARY                                      ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Access Information:"
echo "  🌐 Public URL: $TUNNEL_URL"
echo "  🔒 Origin IP: $EC2_IP (should be hidden)"
echo ""
echo "Admin Credentials:"
echo "  👤 Username: pretamane"
echo "  🔑 Password: #ThawZin2k77!"
echo ""
echo "Protected Endpoints:"
echo "  📊 Grafana:      $TUNNEL_URL/grafana"
echo "  📈 Prometheus:   $TUNNEL_URL/prometheus"
echo "  🗄️  pgAdmin:      $TUNNEL_URL/pgadmin"
echo "  🔍 Meilisearch:  $TUNNEL_URL/meilisearch"
echo ""
echo "Manual Tests to Run:"
echo "  1. Open $TUNNEL_URL in browser (should load portfolio)"
echo "  2. Try accessing $TUNNEL_URL/grafana (should prompt for auth)"
echo "  3. Try accessing http://$EC2_IP (should timeout)"
echo "  4. Check CrowdSec: ssh ubuntu@$EC2_IP 'sudo cscli decisions list'"
echo "  5. Check fail2ban: ssh ubuntu@$EC2_IP 'sudo fail2ban-client status sshd'"
echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║  All automated tests complete! Review results above.                         ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"



