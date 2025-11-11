#!/bin/bash
# Phase 1 - Deploy Exporters and Verify Targets
# Part of the phased observability rollout

set -e

INSTANCE_ID="${1:-i-0c151e9556e3d35e8}"
INSTANCE_IP="${2:-54.179.230.219}"
REGION="${3:-ap-southeast-1}"

echo "=========================================="
echo "Phase 1: Deploy Exporters & Verify Targets"
echo "=========================================="
echo ""
echo "Instance ID: $INSTANCE_ID"
echo "Instance IP: $INSTANCE_IP"
echo "Region: $REGION"
echo ""

# Check SSH connectivity
echo "[1/6] Checking SSH connectivity..."
if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$INSTANCE_IP "echo 'SSH OK'" &>/dev/null; then
    echo "ERROR: Cannot connect to EC2 instance via SSH"
    echo "Please ensure:"
    echo "  1. SSH key is loaded: ssh-add ~/.ssh/your-key.pem"
    echo "  2. Security group allows SSH from your IP"
    exit 1
fi
echo " SSH connectivity OK"
echo ""

# Upload corrected configs (Phase 0 already done locally)
echo "[2/6] Uploading Phase 0 corrected configs to EC2..."
ssh ubuntu@$INSTANCE_IP "mkdir -p ~/app/docker-compose/config/{prometheus,alertmanager,promtail,blackbox}"

# Upload Prometheus configs
scp /home/guest/aws-to-opensource/docker-compose/config/prometheus/prometheus.yml \
    ubuntu@$INSTANCE_IP:~/app/docker-compose/config/prometheus/prometheus.yml

scp /home/guest/aws-to-opensource/docker-compose/config/prometheus/alert-rules.yml \
    ubuntu@$INSTANCE_IP:~/app/docker-compose/config/prometheus/alert-rules.yml

# Upload Alertmanager configs
scp /home/guest/aws-to-opensource/docker-compose/config/alertmanager/config.yml \
    ubuntu@$INSTANCE_IP:~/app/docker-compose/config/alertmanager/config.yml

scp /home/guest/aws-to-opensource/docker-compose/config/alertmanager/default.tmpl \
    ubuntu@$INSTANCE_IP:~/app/docker-compose/config/alertmanager/default.tmpl

# Upload Promtail config
scp /home/guest/aws-to-opensource/docker-compose/config/promtail/promtail-config.yml \
    ubuntu@$INSTANCE_IP:~/app/docker-compose/config/promtail/promtail-config.yml

# Upload docker-compose.yml (with healthcheck fixes)
scp /home/guest/aws-to-opensource/docker-compose/docker-compose.yml \
    ubuntu@$INSTANCE_IP:~/app/docker-compose/docker-compose.yml

echo " Configs uploaded"
echo ""

# Start/restart monitoring services
echo "[3/6] Starting exporters and Prometheus..."
ssh ubuntu@$INSTANCE_IP "cd ~/app/docker-compose && docker-compose up -d node-exporter cadvisor blackbox-exporter prometheus"

echo "Waiting 15 seconds for services to initialize..."
sleep 15
echo " Services started"
echo ""

# Verify services are running
echo "[4/6] Verifying services are running..."
ssh ubuntu@$INSTANCE_IP "cd ~/app/docker-compose && docker-compose ps node-exporter cadvisor blackbox-exporter prometheus"
echo ""

# Check Prometheus targets
echo "[5/6] Checking Prometheus targets..."
echo ""
echo "Fetching target health from Prometheus API..."
ssh ubuntu@$INSTANCE_IP "curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.health != \"up\") | \" DOWN: \" + .labels.job + \" (\" + .scrapeUrl + \")\"' || echo ' All targets UP'"

echo ""
echo "Full target list:"
ssh ubuntu@$INSTANCE_IP "curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | \"  \" + (.health | if . == \"up\" then \"\" else \"\" end) + \" \" + .labels.job + \" - \" + .scrapeUrl'"
echo ""

# Test exporter endpoints
echo "[6/6] Testing exporter endpoints..."
echo ""

echo "Testing node-exporter (system metrics)..."
ssh ubuntu@$INSTANCE_IP "curl -s http://localhost:9100/metrics | head -n 5"
echo "   node-exporter responding"
echo ""

echo "Testing cAdvisor (container metrics)..."
ssh ubuntu@$INSTANCE_IP "curl -s http://localhost:8080/metrics | head -n 5"
echo "   cAdvisor responding"
echo ""

echo "Testing blackbox-exporter (probe to Caddy)..."
ssh ubuntu@$INSTANCE_IP "curl -s 'http://localhost:9115/probe?target=http://caddy:80&module=http_2xx' | grep 'probe_success'"
echo "   blackbox-exporter responding"
echo ""

echo "=========================================="
echo "Phase 1 Deployment Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Review Prometheus targets: http://$INSTANCE_IP:9090/targets"
echo "  2. Check metrics: http://$INSTANCE_IP:9090/graph"
echo "  3. Proceed to Phase 2 (baseline alerts)"
echo ""
echo "CLI validation commands:"
echo "  ssh ubuntu@$INSTANCE_IP 'curl http://localhost:9090/api/v1/targets | jq'"
echo "  ssh ubuntu@$INSTANCE_IP 'curl http://localhost:9100/metrics | head'"
echo "  ssh ubuntu@$INSTANCE_IP 'curl http://localhost:8080/metrics | head'"
echo ""

