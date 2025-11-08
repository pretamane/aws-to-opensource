#!/bin/bash
# Phase 1 Simple Deployment via SSM
# Uploads files one by one to avoid JSON parsing issues

set -e

INSTANCE_ID="${1:-i-0c151e9556e3d35e8}"
REGION="${2:-ap-southeast-1}"

echo "=========================================="
echo "Phase 1: Simple SSM Deployment"
echo "=========================================="
echo ""

# Step 1: Upload Prometheus config
echo "[1/6] Uploading Prometheus config..."
PROMETHEUS_CONFIG=$(cat << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    environment: "production"
    project: "realistic-demo-pretamane"

alerting:
  alertmanagers:
    - static_configs:
        - targets: ["alertmanager:9093"]

rule_files:
  - "/etc/prometheus/alert-rules.yml"

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]
  - job_name: "fastapi-app"
    static_configs:
      - targets: ["fastapi-app:9091"]
    metrics_path: "/metrics"
  - job_name: "node-exporter"
    static_configs:
      - targets: ["node-exporter:9100"]
  - job_name: "cadvisor"
    static_configs:
      - targets: ["cadvisor:8080"]
  - job_name: "blackbox-exporter"
    static_configs:
      - targets: ["blackbox-exporter:9115"]
    metrics_path: "/metrics"
EOF
)

aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name AWS-RunShellScript \
    --parameters "{\"commands\":[\"cat > /home/ubuntu/app/docker-compose/config/prometheus/prometheus.yml << 'EOF2'\n$PROMETHEUS_CONFIG\nEOF2\"]}" \
    --region $REGION > /dev/null

echo "✓ Prometheus config uploaded"

# Step 2: Upload Alert Rules
echo "[2/6] Uploading Alert Rules..."
ALERT_RULES=$(cat << 'EOF'
groups:
  - name: system_resources
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage"
      - alert: ServiceDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Service down"
EOF
)

aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name AWS-RunShellScript \
    --parameters "{\"commands\":[\"cat > /home/ubuntu/app/docker-compose/config/prometheus/alert-rules.yml << 'EOF2'\n$ALERT_RULES\nEOF2\"]}" \
    --region $REGION > /dev/null

echo "✓ Alert rules uploaded"

# Step 3: Start services
echo "[3/6] Starting monitoring services..."

aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name AWS-RunShellScript \
    --parameters '{"commands":["cd /home/ubuntu/app/docker-compose && docker-compose up -d node-exporter cadvisor blackbox-exporter prometheus"]}' \
    --region $REGION > /dev/null

echo "✓ Services started, waiting 15 seconds..."
sleep 15

# Step 4: Check service status
echo "[4/6] Checking service status..."
aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name AWS-RunShellScript \
    --parameters '{"commands":["docker-compose ps node-exporter cadvisor blackbox-exporter prometheus"]}' \
    --region $REGION

# Step 5: Check Prometheus targets
echo "[5/6] Checking Prometheus targets..."
echo ""
aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name AWS-RunShellScript \
    --parameters '{"commands":["curl -s http://localhost:9090/api/v1/targets | jq -r \".data.activeTargets[] | \\\"  \\\" + (.health | if . == \\\"up\\\" then \\\"✓\\\" else \\\"❌\\\" end) + \\\" \\\" + .labels.job + \\\" - \\\" + .scrapeUrl\""]}' \
    --region $REGION

# Step 6: Test endpoints
echo "[6/6] Testing endpoints..."
echo ""

echo "Testing node-exporter..."
aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name AWS-RunShellScript \
    --parameters '{"commands":["curl -s http://localhost:9100/metrics | head -n 3"]}' \
    --region $REGION

echo ""
echo "Testing cAdvisor..."
aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name AWS-RunShellScript \
    --parameters '{"commands":["curl -s http://localhost:8080/metrics | head -n 3"]}' \
    --region $REGION

echo ""
echo "Testing blackbox probe..."
aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name AWS-RunShellScript \
    --parameters '{"commands":["curl -s \"http://localhost:9115/probe?target=http://caddy:80&module=http_2xx\" | grep \"probe_success\""]}' \
    --region $REGION

echo ""
echo "=========================================="
echo "Phase 1 Deployment Complete!"
echo "=========================================="
echo ""
echo "Access Prometheus UI:"
echo "  http://54.179.230.219:9090/targets"
echo ""

