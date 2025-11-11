#!/bin/bash
# Phase 1 Deployment via SSM
# This script creates files on the EC2 instance and then executes the deployment

set -e

INSTANCE_ID="${1:-i-0c151e9556e3d35e8}"
REGION="${2:-ap-southeast-1}"

echo "=========================================="
echo "Phase 1: Deploy via SSM"
echo "=========================================="
echo "Instance ID: $INSTANCE_ID"
echo "Region: $REGION"
echo ""

# Step 1: Upload configuration files via SSM
echo "[1/4] Uploading configuration files..."

# Create Prometheus config
cat > /tmp/prometheus.yml << 'EOF'
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
          labels:
            service: "alertmanager"

rule_files:
  - "/etc/prometheus/alert-rules.yml"

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]
        labels:
          service: "prometheus"
          component: "monitoring"

  - job_name: "fastapi-app"
    static_configs:
      - targets: ["fastapi-app:9091"]
        labels:
          service: "fastapi-app"
          component: "application"
    scrape_interval: 10s
    metrics_path: "/metrics"

  - job_name: "minio"
    static_configs:
      - targets: ["minio:9000"]
        labels:
          service: "minio"
          component: "storage"
    metrics_path: "/minio/v2/metrics/cluster"

  - job_name: "grafana"
    static_configs:
      - targets: ["grafana:3000"]
        labels:
          service: "grafana"
          component: "monitoring"
    metrics_path: "/metrics"

  - job_name: "loki"
    static_configs:
      - targets: ["loki:3100"]
        labels:
          service: "loki"
          component: "logging"
    metrics_path: "/metrics"

  - job_name: "alertmanager"
    static_configs:
      - targets: ["alertmanager:9093"]
        labels:
          service: "alertmanager"
          component: "alerting"

  - job_name: "node-exporter"
    static_configs:
      - targets: ["node-exporter:9100"]
        labels:
          service: "node-exporter"
          component: "system-monitoring"
    scrape_interval: 15s

  - job_name: "cadvisor"
    static_configs:
      - targets: ["cadvisor:8080"]
        labels:
          service: "cadvisor"
          component: "container-monitoring"
    scrape_interval: 15s

  - job_name: "blackbox-exporter"
    static_configs:
      - targets: ["blackbox-exporter:9115"]
        labels:
          service: "blackbox-exporter"
          component: "synthetic-monitoring"
    metrics_path: "/metrics"
    scrape_interval: 30s
    params:
      module: ["http_2xx"]

  - job_name: "blackbox-http-public"
    metrics_path: "/probe"
    params:
      module: ["http_2xx"]
    static_configs:
      - targets:
          - "http://caddy:80/"
          - "http://caddy:80/health"
          - "http://caddy:80/api/health"
          - "http://caddy:80/grafana/api/health"
          - "http://caddy:80/prometheus/-/healthy"
        labels:
          probe_type: "http"
          endpoint_type: "public"
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: "blackbox-exporter:9115"

  - job_name: "blackbox-http-internal"
    metrics_path: "/probe"
    params:
      module: ["http_2xx"]
    static_configs:
      - targets:
          - "http://fastapi-app:8000/health"
          - "http://meilisearch:7700/health"
          - "http://minio:9000/minio/health/live"
          - "http://prometheus:9090/-/healthy"
          - "http://grafana:3000/api/health"
          - "http://loki:3100/ready"
          - "http://alertmanager:9093/-/healthy"
        labels:
          probe_type: "http"
          endpoint_type: "internal"
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: "blackbox-exporter:9115"

  - job_name: "blackbox-http-admin"
    metrics_path: "/probe"
    params:
      module: ["http_basic_auth_401"]
    static_configs:
      - targets:
          - "http://caddy:80/pgadmin"
          - "http://caddy:80/grafana"
          - "http://minio:9001"
        labels:
          probe_type: "http"
          endpoint_type: "admin"
          expected_status: "401"
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: "blackbox-exporter:9115"

  - job_name: "blackbox-tcp"
    metrics_path: "/probe"
    params:
      module: ["tcp_connect"]
    static_configs:
      - targets:
          - "postgresql:5432"
          - "meilisearch:7700"
          - "minio:9000"
          - "prometheus:9090"
          - "grafana:3000"
          - "loki:3100"
        labels:
          probe_type: "tcp"
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: "blackbox-exporter:9115"
EOF

# Create Alert Rules
cat > /tmp/alert-rules.yml << 'EOF'
groups:
  - name: recording_rules
    interval: 60s
    rules:
      - record: cpu_usage_percent
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
      - record: memory_usage_percent
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
      - record: disk_usage_percent
        expr: (1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100

  - name: system_resources
    interval: 30s
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
          category: infrastructure
        annotations:
          summary: "High CPU usage detected on {{ $labels.instance }}"
          description: "CPU usage is above 80% (current value: {{ $value }}%)"

      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 5m
        labels:
          severity: warning
          category: infrastructure
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is above 85% (current value: {{ $value }}%)"

      - alert: ServiceDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
          category: infrastructure
        annotations:
          summary: "Service {{ $labels.job }} is down"
          description: "{{ $labels.job }} on {{ $labels.instance }} has been down for more than 2 minutes"

  - name: application_performance
    interval: 30s
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
        for: 5m
        labels:
          severity: warning
          category: application
        annotations:
          summary: "High error rate on {{ $labels.job }}"
          description: "Error rate is above 5% (current: {{ $value }})"

  - name: node_exporter_alerts
    interval: 30s
    rules:
      - alert: NodeExporterDown
        expr: up{job="node-exporter"} == 0
        for: 2m
        labels:
          severity: critical
          category: infrastructure
        annotations:
          summary: "Node exporter is down"
          description: "Node exporter has been unreachable for more than 2 minutes"

  - name: container_alerts
    interval: 30s
    rules:
      - alert: CadvisorDown
        expr: up{job="cadvisor"} == 0
        for: 2m
        labels:
          severity: critical
          category: infrastructure
        annotations:
          summary: "cAdvisor is down"
          description: "cAdvisor has been unreachable for more than 2 minutes"

  - name: blackbox_alerts
    interval: 30s
    rules:
      - alert: PublicEndpointDown
        expr: probe_success{module="http_2xx"} == 0
        for: 2m
        labels:
          severity: critical
          category: infrastructure
        annotations:
          summary: "Public endpoint is down"
          description: "Public endpoint {{ $labels.instance }} has been unreachable for more than 2 minutes"
EOF

# Create docker-compose.yml with corrected services
cat > /tmp/docker-compose.yml << 'EOF'
version: "3.8"

services:
  fastapi-app:
    build:
      context: ../docker/api
      dockerfile: Dockerfile.opensource
    container_name: fastapi-app
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      - APP_NAME=realistic-demo-pretamane
      - DB_HOST=postgresql
      - DB_PORT=5432
      - DB_NAME=${DB_NAME:-pretamane_db}
      - DB_USER=${DB_USER:-pretamane}
      - DB_PASSWORD=${DB_PASSWORD}
      - MEILISEARCH_URL=http://meilisearch:7700
      - MEILISEARCH_API_KEY=${MEILI_MASTER_KEY}
      - S3_ENDPOINT_URL=http://minio:9000
      - S3_ACCESS_KEY=${MINIO_ROOT_USER}
      - S3_SECRET_KEY=${MINIO_ROOT_PASSWORD}
      - S3_DATA_BUCKET=pretamane-data
      - AWS_REGION=${AWS_REGION:-ap-southeast-1}
      - SES_FROM_EMAIL=${SES_FROM_EMAIL}
      - SES_TO_EMAIL=${SES_TO_EMAIL}
      - PROMETHEUS_URL=http://prometheus:9090
      - ENABLE_METRICS=true
      - METRICS_PORT=9091
    volumes:
      - uploads-data:/mnt/uploads
      - processed-data:/mnt/processed
      - logs-data:/mnt/logs
    depends_on:
      - postgresql
      - meilisearch
      - minio
    networks:
      - app-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  postgresql:
    image: postgres:16-alpine
    container_name: postgresql
    restart: unless-stopped
    environment:
      - POSTGRES_DB=${DB_NAME:-pretamane_db}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./init-scripts/postgres:/docker-entrypoint-initdb.d
    networks:
      - app-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${DB_NAME:-pretamane_db}"]
      interval: 10s
      timeout: 5s
      retries: 5

  meilisearch:
    image: getmeili/meilisearch:v1.5
    container_name: meilisearch
    restart: unless-stopped
    ports:
      - "7700:7700"
    environment:
      - MEILI_MASTER_KEY=${MEILI_MASTER_KEY}
      - MEILI_ENV=production
    volumes:
      - meilisearch-data:/meili_data
    networks:
      - app-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:7700/health"]
      interval: 30s
      timeout: 5s
      retries: 3

  minio:
    image: minio/minio:latest
    container_name: minio
    restart: unless-stopped
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      - MINIO_ROOT_USER=${MINIO_ROOT_USER}
      - MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}
    volumes:
      - minio-data:/data
    networks:
      - app-network
    command: server /data --console-address ":9001"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 5s
      retries: 3

  caddy:
    image: caddy:2-alpine
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./config/caddy/Caddyfile:/etc/caddy/Caddyfile
      - caddy-data:/data
      - ../pretamane-website:/var/www/pretamane:ro
      - caddy-logs:/var/log/caddy
    networks:
      - app-network
    depends_on:
      - fastapi-app

  prometheus:
    image: prom/prometheus:v2.48.0
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - /tmp/prometheus.yml:/etc/prometheus/prometheus.yml
      - /tmp/alert-rules.yml:/etc/prometheus/alert-rules.yml
      - prometheus-data:/prometheus
    networks:
      - app-network
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--storage.tsdb.path=/prometheus"
      - "--storage.tsdb.retention.time=30d"
      - "--web.external-url=http://localhost/prometheus/"

  grafana:
    image: grafana/grafana:10.2.0
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=${GF_SECURITY_ADMIN_USER}
      - GF_SECURITY_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD}
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_ROOT_URL=http://localhost/grafana
      - GF_SERVER_SERVE_FROM_SUB_PATH=true
    volumes:
      - grafana-data:/var/lib/grafana
    networks:
      - app-network
    depends_on:
      - prometheus

  loki:
    image: grafana/loki:2.9.0
    container_name: loki
    restart: unless-stopped
    ports:
      - "3100:3100"
    volumes:
      - loki-data:/loki
    networks:
      - app-network
    command: -config.file=/etc/loki/local-config.yaml

  alertmanager:
    image: prom/alertmanager:v0.26.0
    container_name: alertmanager
    restart: unless-stopped
    ports:
      - "9093:9093"
    volumes:
      - alertmanager-data:/alertmanager
    networks:
      - app-network
    command:
      - "--config.file=/etc/alertmanager/config.yml"
      - "--storage.path=/alertmanager"

  promtail:
    image: grafana/promtail:2.9.0
    container_name: promtail
    restart: unless-stopped
    volumes:
      - logs-data:/mnt/logs:ro
      - caddy-logs:/var/log/caddy:ro
    networks:
      - app-network
    command: -config.file=/etc/promtail/config.yml
    depends_on:
      - loki

  node-exporter:
    image: prom/node-exporter:v1.7.0
    container_name: node-exporter
    restart: unless-stopped
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - "--path.procfs=/host/proc"
      - "--path.sysfs=/host/sys"
      - "--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)"
    networks:
      - app-network

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:v0.47.0
    container_name: cadvisor
    restart: unless-stopped
    privileged: true
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    devices:
      - /dev/kmsg:/dev/kmsg
    networks:
      - app-network
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:8080/metrics"]
      interval: 30s
      timeout: 5s
      retries: 3

  blackbox-exporter:
    image: prom/blackbox-exporter:v0.24.0
    container_name: blackbox-exporter
    restart: unless-stopped
    volumes:
      - ./config/blackbox/blackbox.yml:/etc/blackbox_exporter/config.yml
    networks:
      - app-network
    command:
      - "--config.file=/etc/blackbox_exporter/config.yml"

networks:
  app-network:
    driver: bridge

volumes:
  postgres-data:
  meilisearch-data:
  minio-data:
  uploads-data:
  processed-data:
  logs-data:
  prometheus-data:
  grafana-data:
  loki-data:
  caddy-data:
  caddy-logs:
  alertmanager-data:
EOF

# Upload files to EC2 via SSM
echo "[2/4] Uploading files to EC2..."

# Upload Prometheus config
aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name AWS-RunShellScript \
    --parameters "{\"commands\":[\"cat > /home/ubuntu/app/docker-compose/config/prometheus/prometheus.yml << 'EOF'\n$(cat /tmp/prometheus.yml)\nEOF\"]}" \
    --region $REGION \
    --output text > /dev/null

# Upload Alert Rules
aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name AWS-RunShellScript \
    --parameters "{\"commands\":[\"cat > /home/ubuntu/app/docker-compose/config/prometheus/alert-rules.yml << 'EOF'\n$(cat /tmp/alert-rules.yml)\nEOF\"]}" \
    --region $REGION \
    --output text > /dev/null

# Upload docker-compose.yml
aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name AWS-RunShellScript \
    --parameters "{\"commands\":[\"cat > /home/ubuntu/app/docker-compose/docker-compose.yml << 'EOF'\n$(cat /tmp/docker-compose.yml)\nEOF\"]}" \
    --region $REGION \
    --output text > /dev/null

echo " Files uploaded"

# Step 3: Start services
echo "[3/4] Starting monitoring services..."

aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name AWS-RunShellScript \
    --parameters '{"commands":["cd /home/ubuntu/app/docker-compose && docker-compose up -d node-exporter cadvisor blackbox-exporter prometheus"]}' \
    --region $REGION \
    --output text > /dev/null

echo "Waiting 20 seconds for services to initialize..."
sleep 20

# Step 4: Verify deployment
echo "[4/4] Verifying deployment..."

echo "Checking service status..."
aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name AWS-RunShellScript \
    --parameters '{"commands":["docker-compose ps node-exporter cadvisor blackbox-exporter prometheus"]}' \
    --region $REGION \
    --output text

echo ""
echo "Checking Prometheus targets..."
aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name AWS-RunShellScript \
    --parameters '{"commands":["curl -s http://localhost:9090/api/v1/targets | jq -r \".data.activeTargets[] | select(.health != \\\"up\\\") | \\\" DOWN: \\\" + .labels.job + \\\" (\\\" + .scrapeUrl + \\\")\\\"\" || echo \" All targets UP\""]}' \
    --region $REGION \
    --output text

echo ""
echo "Testing node-exporter..."
aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name AWS-RunShellScript \
    --parameters '{"commands":["curl -s http://localhost:9100/metrics | head -n 3"]}' \
    --region $REGION \
    --output text

echo ""
echo "Testing cAdvisor..."
aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name AWS-RunShellScript \
    --parameters '{"commands":["curl -s http://localhost:8080/metrics | head -n 3"]}' \
    --region $REGION \
    --output text

echo ""
echo "Testing blackbox probe..."
aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name AWS-RunShellScript \
    --parameters '{"commands":["curl -s \"http://localhost:9115/probe?target=http://caddy:80&module=http_2xx\" | grep \"probe_success\""]}' \
    --region $REGION \
    --output text

echo ""
echo "=========================================="
echo "Phase 1 Deployment Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Review Prometheus targets: http://54.179.230.219:9090/targets"
echo "  2. Check metrics: http://54.179.230.219:9090/graph"
echo "  3. Proceed to Phase 2 (baseline alerts)"
echo ""

