# Observability Suite: Prometheus, Grafana, Loki

## Role & Responsibilities
Complete observability stack replacing AWS CloudWatch with metrics, dashboards, logs, and alerting.

## Why Open-Source Observability

| Aspect | AWS CloudWatch | Prometheus + Grafana + Loki | Decision |
|--------|----------------|------------------------------|----------|
| **Cost** | $10/month + $0.30/GB logs | Self-hosted ($0) | Open-source (90% savings) |
| **Retention** | 15 months metrics | Configurable (30d default) | Open-source (flexible) |
| **Query Language** | CloudWatch Insights | PromQL + LogQL | Open-source (powerful) |
| **Dashboards** | Basic | Grafana (beautiful) | Open-source (UX) |
| **Lock-in** | AWS only | Portable | Open-source (vendor neutral) |

**Interview Answer**: "We replaced CloudWatch with Prometheus/Grafana/Loki for cost savings, better query languages (PromQL, LogQL), and vendor neutrality. The stack is portable—runs anywhere, no AWS lock-in."

## The Three Pillars of Observability

### 1. Metrics (Prometheus)
- **What**: Numeric time-series data
- **When**: Trends, thresholds, alerting
- **Example**: `http_requests_total{status="200"} 1542`

### 2. Logs (Loki)
- **What**: Text events with timestamps
- **When**: Debugging specific incidents
- **Example**: `2025-01-01 10:15:23 ERROR: Database timeout`

### 3. Traces (Future)
- **What**: Request flow across services
- **When**: Microservices bottleneck analysis
- **Tool**: Jaeger/Tempo (planned)

## Architecture & Service Relationships

```
                      FastAPI
                   (metrics + logs)
                         │
                    ┌────┴────┐
                    │         │
                 /metrics   logs → /mnt/logs
                    │         │
                    ▼         ▼
              Prometheus   Promtail
              (scrapes)    (ships)
                    │         │
                    │         ▼
                    │       Loki
                    │     (stores)
                    │         │
                    └────┬────┘
                         ▼
                      Grafana
                  (dashboards)
                         │
                         ▼
                   Alertmanager
                  (notifications)
```

## Prometheus: Metrics Collection

### Service Location
- Container: `prometheus`
- Port: 9090
- UI: http://localhost:8080/prometheus/
- Config: `docker-compose/config/prometheus/prometheus.yml`
- Alert Rules: `docker-compose/config/prometheus/alert-rules.yml`

### How Prometheus Works

#### Pull-Based Model
```
Every 10 seconds:
1. Prometheus reads its scrape config
2. Makes HTTP GET to /metrics endpoint
3. Parses Prometheus text format
4. Stores in time-series database (TSDB)
5. Evaluates alert rules
```

#### Scrape Configuration
```yaml
scrape_configs:
  # FastAPI metrics
  - job_name: 'fastapi'
    scrape_interval: 10s
    static_configs:
      - targets: ['fastapi-app:9091']
    
  # MinIO metrics
  - job_name: 'minio'
    metrics_path: /minio/v2/metrics/cluster
    static_configs:
      - targets: ['minio:9000']
    
  # Node exporter (host metrics)
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
    
  # Blackbox exporter (synthetic monitoring)
  - job_name: 'blackbox'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
        - http://fastapi-app:8000/health
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - target_label: __address__
        replacement: blackbox-exporter:9115
```

### PromQL Examples

#### Request Rate
```promql
# Requests per second (5-minute rate)
rate(http_requests_total[5m])

# Requests per second by status
sum by (status) (rate(http_requests_total[5m]))

# 4xx error rate
sum(rate(http_requests_total{status=~"4.."}[5m]))
```

#### Latency
```promql
# P50 latency (median)
histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))

# P95 latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# P99 latency
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))
```

#### Resource Usage
```promql
# CPU usage
rate(process_cpu_seconds_total[1m]) * 100

# Memory usage
process_resident_memory_bytes / 1024 / 1024

# Database connections
active_database_connections
```

### Alert Rules

#### High Error Rate
```yaml
- alert: HighErrorRate
  expr: |
    sum(rate(http_requests_total{status=~"5.."}[5m])) 
    / 
    sum(rate(http_requests_total[5m])) 
    > 0.05
  for: 5m
  labels:
    severity: critical
    component: api
  annotations:
    summary: "High 5xx error rate detected"
    description: "{{ $value | humanizePercentage }} of requests failing (threshold: 5%)"
```

#### High Latency
```yaml
- alert: HighLatency
  expr: |
    histogram_quantile(0.95, 
      rate(http_request_duration_seconds_bucket[5m])
    ) > 1.0
  for: 10m
  labels:
    severity: warning
    component: api
  annotations:
    summary: "API latency is high"
    description: "P95 latency is {{ $value }}s (threshold: 1s)"
```

#### Service Down
```yaml
- alert: ServiceDown
  expr: up{job="fastapi"} == 0
  for: 2m
  labels:
    severity: critical
    component: api
  annotations:
    summary: "FastAPI service is down"
    description: "Service has been unreachable for 2 minutes"
```

## Grafana: Dashboards & Visualization

### Service Location
- Container: `grafana`
- Port: 3000
- UI: http://localhost:8080/grafana
- Config: `docker-compose/config/grafana/`
- Credentials: admin / admin123

### Dashboard Categories

#### 1. Application Performance
```
- Request rate (req/sec)
- Error rate (%)
- Latency distribution (P50, P95, P99)
- Response status breakdown (2xx, 4xx, 5xx)
- Endpoint-specific metrics
```

#### 2. Business Metrics
```
- Contact submissions (count, rate)
- Document uploads (count, types)
- Search queries (count, latency)
- Visitor count (gauge, trend)
- Service type breakdown
```

#### 3. Infrastructure
```
- CPU usage (%)
- Memory usage (MB, %)
- Disk usage (GB, %)
- Network I/O (bytes/sec)
- Database connections (active, max)
```

#### 4. Service Health
```
- Container status (up/down)
- Health check results
- Restart count
- Uptime
```

### Dashboard Provisioning
```yaml
# docker-compose/config/grafana/provisioning/dashboards/dashboard.yml
apiVersion: 1
providers:
  - name: 'Default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards

# docker-compose/config/grafana/provisioning/datasources/datasource.yml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
  
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
```

## Loki: Log Aggregation

### Service Location
- Container: `loki`
- Port: 3100
- Config: `docker-compose/config/loki/loki-config.yml`

### How Loki Works

#### Push-Based Model
```
1. Promtail reads log files
2. Parses and labels logs
3. Pushes to Loki over HTTP
4. Loki indexes labels (not content)
5. Stores log lines compressed
6. Grafana queries via LogQL
```

### Loki Configuration
```yaml
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
  chunk_idle_period: 5m
  chunk_retain_period: 30s

schema_config:
  configs:
    - from: 2024-01-01
      store: boltdb
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb:
    directory: /loki/index
  filesystem:
    directory: /loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h  # 1 week
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20

chunk_store_config:
  max_look_back_period: 720h  # 30 days

table_manager:
  retention_deletes_enabled: true
  retention_period: 720h  # 30 days
```

**Key Points**:
- Indexes labels only (not log content) → fast queries
- 30-day retention
- 10MB/s ingestion rate

## Promtail: Log Shipping

### Service Location
- Container: `promtail`
- Config: `docker-compose/config/promtail/promtail-config.yml`

### Promtail Configuration
```yaml
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  # FastAPI logs
  - job_name: fastapi
    static_configs:
      - targets:
          - localhost
        labels:
          job: fastapi
          __path__: /mnt/logs/*.log
    pipeline_stages:
      - json:
          expressions:
            timestamp: timestamp
            level: level
            message: message
      - labels:
          level:
      - timestamp:
          source: timestamp
          format: RFC3339Nano
  
  # Caddy access logs
  - job_name: caddy
    static_configs:
      - targets:
          - localhost
        labels:
          job: caddy
          __path__: /var/log/caddy/*.log
    pipeline_stages:
      - json:
          expressions:
            request: request
            status: status
            duration: duration
      - labels:
          status:
```

### LogQL Examples

#### Basic Query
```logql
# All FastAPI logs
{job="fastapi"}

# Only errors
{job="fastapi"} |= "ERROR"

# Exclude health checks
{job="fastapi"} != "/health"
```

#### Advanced Filtering
```logql
# Parse JSON and filter
{job="fastapi"} 
  | json 
  | level="ERROR" 
  | line_format "{{.timestamp}} {{.message}}"

# Count errors per minute
sum(rate({job="fastapi"} |= "ERROR" [5m]))

# Top 10 error messages
topk(10, 
  sum by (message) (
    count_over_time({job="fastapi"} |= "ERROR" [1h])
  )
)
```

#### Correlation with Metrics
```
1. See high latency in Prometheus
2. Query Loki for same timeframe:
   {job="fastapi"} 
   | json
   | duration > 1000  # >1s
   | line_format "{{.endpoint}} took {{.duration}}ms"
```

## Alertmanager: Alert Routing

### Service Location
- Container: `alertmanager`
- Port: 9093
- Config: `docker-compose/config/alertmanager/config.yml`

### Configuration
```yaml
route:
  receiver: 'default'
  group_by: ['alertname', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  
  routes:
    # Critical alerts: immediate notification
    - match:
        severity: critical
      receiver: pagerduty
      continue: true
    
    # Warnings: batch and send
    - match:
        severity: warning
      receiver: slack
      group_wait: 5m

receivers:
  - name: 'default'
    webhook_configs:
      - url: 'http://localhost:5001/alerts'
  
  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: 'YOUR_PAGERDUTY_KEY'
  
  - name: 'slack'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/...'
        channel: '#alerts'
        title: 'Alert: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

## Blackbox Exporter: Synthetic Monitoring

### Service Location
- Container: `blackbox-exporter`
- Config: `docker-compose/config/blackbox/blackbox.yml`

### Configuration
```yaml
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      valid_http_versions: ["HTTP/1.1", "HTTP/2.0"]
      valid_status_codes: [200]
      method: GET
      follow_redirects: true
      fail_if_not_ssl: false
  
  http_post_2xx:
    prober: http
    http:
      method: POST
      headers:
        Content-Type: application/json
      body: '{"test": true}'
```

### Prometheus Scrape Config
```yaml
- job_name: 'blackbox'
  metrics_path: /probe
  params:
    module: [http_2xx]
  static_configs:
    - targets:
      - http://fastapi-app:8000/health
      - http://fastapi-app:8000/
  relabel_configs:
    - source_labels: [__address__]
      target_label: __param_target
    - target_label: __address__
      replacement: blackbox-exporter:9115
```

**What It Does**: Probes endpoints from an external perspective, detects issues users would see.

## Node Exporter: Host Metrics

### Service Location
- Container: `node-exporter`
- Port: 9100

### Key Metrics
```
node_cpu_seconds_total        # CPU time per mode
node_memory_MemAvailable_bytes  # Available memory
node_filesystem_avail_bytes   # Disk space
node_network_receive_bytes_total  # Network RX
node_network_transmit_bytes_total # Network TX
```

## Interview Talking Points

**"Explain your observability strategy"**
> "I implemented the three pillars: Prometheus for metrics and trending, Loki for logs and debugging, and planned Jaeger for tracing. I instrument custom business metrics (contact submissions, document uploads) not just infrastructure. Blackbox Exporter provides synthetic monitoring from the user's perspective. Alerts are layered by severity to prevent fatigue."

**"How do metrics and logs complement each other?"**
> "Metrics answer 'what is happening?' (request rate spiking). Logs answer 'why is it happening?' (database connection timeouts). I use Prometheus to detect anomalies, then drill into Loki logs filtered by timeframe and correlation ID to find root cause. Grafana ties both together in one UI."

**"What's your alerting philosophy?"**
> "Alert on symptoms (high latency, error rate) not causes (CPU usage). Use severity levels: critical → page on-call; warning → Slack notification. Group and batch alerts to prevent fatigue. Every alert must be actionable—if you can't fix it, don't alert on it."

**"How do you debug a production incident?"**
> "Start with Grafana dashboards to identify affected service and timeframe. Check Prometheus for correlated metrics (latency spike? memory leak? database connections?). Drill into Loki logs with filters to find errors and stack traces. Use correlation IDs to trace requests across services. Document findings for postmortem."

**"What would you add for production?"**
> "Distributed tracing (Jaeger), external uptime monitoring (UptimeRobot), error tracking (Sentry), and alerting to PagerDuty for 24/7 coverage. Also set up long-term metrics storage (Thanos or VictoriaMetrics) for trending beyond 30 days."

