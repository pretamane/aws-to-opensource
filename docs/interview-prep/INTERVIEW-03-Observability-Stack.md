# Interview Guide: Observability Stack

##  Selling Point
"I implemented a complete observability stack (Prometheus + Grafana + Loki + Blackbox) replacing AWS CloudWatch, with custom metrics, log pipelines, and synthetic monitoring for proactive incident detection."

##  The Three Pillars of Observability

### 1. Metrics (Prometheus)
**What**: Numeric time-series data  
**When**: Trends, thresholds, alerting  
**Example**: `http_requests_total{status="200"} 1542`

### 2. Logs (Loki)
**What**: Text events with timestamps  
**When**: Debugging specific incidents  
**Example**: `2024-01-15 ERROR: Database timeout`

### 3. Traces (Future)
**What**: Request flow across services  
**When**: Microservices bottleneck analysis  
**Tool**: Jaeger/Tempo

##  How Observability Components Connect

```

  FastAPI App    
  - /metrics        Prometheus scrapes
  - Structured      every 10s
    logs           
  
                    
         Logs to    
         /mnt/logs  
        ↓            ↓
  
  Promtail       Prometheus  
  - Reads        - Stores    
    logs           metrics   
  - Labels       - Evaluates 
  - Ships          alerts    
  
                       
        Pushes          Queries
       ↓                ↓
  
    Loki          Grafana    
  - Log      ←  - Dashboards
    storage      - Alerts    
  
```

##  Prometheus Metrics Instrumentation

### Custom Business Metrics

```python
# Counter: Monotonically increasing
contact_submissions_total = Counter(
    'contact_submissions_total',
    'Total contact form submissions',
    ['source', 'service']  # Labels for grouping
)

# Usage
contact_submissions_total.labels(
    source='website',
    service='Cloud Architecture'
).inc()
```

**Query in Grafana**:
```promql
# Rate of submissions per minute
rate(contact_submissions_total[5m]) * 60

# Breakdown by service
sum by (service) (contact_submissions_total)
```

### HTTP Request Metrics

```python
http_request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'HTTP request latency',
    ['method', 'endpoint']
)

# Middleware auto-records
@app.middleware("http")
async def metrics_middleware(request, call_next):
    start = time.time()
    response = await call_next(request)
    duration = time.time() - start
    
    http_request_duration_seconds.labels(
        method=request.method,
        endpoint=request.url.path
    ).observe(duration)
```

**Why Histogram?**: Stores latency distribution (p50, p95, p99), not just average.

**Query**:
```promql
# 95th percentile latency
histogram_quantile(0.95, 
  rate(http_request_duration_seconds_bucket[5m])
)
```

##  Blackbox Exporter (Synthetic Monitoring)

### How It Works

```yaml
# Prometheus config
- job_name: "blackbox-http-public"
  params:
    module: ["http_2xx"]  # Expect 200-299
  static_configs:
    - targets:
        - "http://caddy:80/health"
        - "http://caddy:80/api/docs"
```

**Flow**:
```
Prometheus
    
     "Probe http://caddy:80/health"
    ↓
Blackbox Exporter
    
     HTTP GET
    ↓
Caddy → FastAPI
    
     200 OK
    ↓
Blackbox returns metrics:
- probe_success: 1
- probe_duration_seconds: 0.123
- probe_http_status_code: 200
```

### Blackbox Modules We Use

**1. http_2xx**: Expect success
```yaml
http_2xx:
  prober: http
  http:
    fail_if_not_ssl: false
    preferred_ip_protocol: ip4
```

**2. http_basic_auth_401**: Verify auth required
```yaml
http_basic_auth_401:
  prober: http
  http:
    fail_if_body_not_matches_regexp:
      - '401 Unauthorized'
```

**Use case**: Ensure `/grafana` returns 401 without credentials (security test).

**3. tcp_connect**: Port reachability
```yaml
tcp_connect:
  prober: tcp
```

**Use case**: Check if PostgreSQL port 5432 is open.

**Interview Insight**: "Blackbox monitoring tests from the user's perspective - it doesn't care if your process is running, it cares if users can access your service."

##  Alert Rules Architecture

### Layered Alerting Strategy

```yaml
- alert: HighErrorRate
  expr: rate(http_requests_total{status=~"5.."}[5m]) > 5
  for: 2m
  labels:
    severity: warning
  annotations:
    summary: "{{ $labels.job }}: High 5xx rate"
    description: "{{ $value }} errors/sec"
```

**Alert Components**:

1. **expr**: PromQL query (true = firing)
2. **for**: Duration before firing (anti-flapping)
3. **severity**: Routing (critical → page, warning → Slack)
4. **annotations**: Human-readable message

### Our Alert Hierarchy

| Alert | Threshold | Duration | Severity | Action |
|-------|-----------|----------|----------|--------|
| **CriticalCPUUsage** | >95% | 2m | critical | Page on-call |
| **HighCPUUsage** | >80% | 5m | warning | Slack notification |
| **ServiceDown** | `up == 0` | 2m | critical | Page on-call |
| **High5xxRate** | >5 errors/sec | 2m | critical | Page on-call |
| **High4xxRate** | >10/sec | 3m | warning | Security alert |

**Why Duration Matters**:

- **Too short** (30s): Alert on transient spikes (false positives)
- **Too long** (10m): Incident already impacting users
- **Sweet spot**: 2-5 minutes catches real issues, filters noise

**Interview Story**: "I tune alert thresholds based on historical p95 metrics plus a margin. For example, if normal CPU is 20-40% with p95 at 60%, I alert at 80% to catch abnormal load without crying wolf."

##  Loki Log Pipeline

### Promtail Configuration

```yaml
- job_name: caddy-access
  static_configs:
    - targets: [localhost]
      labels:
        job: caddy
        log_type: access
  pipeline_stages:
    - json:  # Parse JSON log
        expressions:
          status: status
          method: request.method
          uri: request.uri
    - labels:  # Attach as queryable labels
        status:
        method:
```

**Log Flow**:
```
Caddy writes JSON log:
{"ts":1672531200,"status":404,"request":{"method":"GET","uri":"/unknown"}}
        ↓
Promtail reads, parses JSON
        ↓
Loki stores with labels:
{job="caddy", log_type="access", status="404", method="GET"}
        ↓
Query in Grafana:
{job="caddy", status="404"}
```

### Label Cardinality Warning

** Bad (high cardinality)**:
```yaml
- labels:
    user_id:        # Millions of unique values!
    request_id:     # Every request unique!
```

** Good (low cardinality)**:
```yaml
- labels:
    status:   # ~10 values (200, 404, 500...)
    method:   # 5 values (GET, POST, PUT...)
    job:      # ~10 services
```

**Why**: Loki creates index entries per unique label combination. High cardinality = index explosion = OOM.

**Interview Answer**: "Labels should have low cardinality (10-100 unique values). For high-cardinality data like user IDs, keep them in log content and filter at query time."

##  Metrics vs Logs: When to Use What

| Scenario | Use | Example |
|----------|-----|---------|
| "What's the error rate?" | **Metrics** | `sum(rate(http_requests_total{status="500"}[5m]))` |
| "Why did request X fail?" | **Logs** | `{job="api"} \|= "request_id=X" \|= "ERROR"` |
| "Is latency increasing?" | **Metrics** | `histogram_quantile(0.95, http_duration_bucket)` |
| "What error message occurred?" | **Logs** | `{job="api"} \|= "ERROR" \| json \| line_format "{{.msg}}"` |
| "Alert if service down" | **Metrics** | `up{job="api"} == 0` |
| "Show stack trace" | **Logs** | Full text search in Loki |

**Interview Insight**: "Metrics answer 'how much' and 'how often' questions. Logs answer 'what happened' and 'why'. Use metrics for dashboards/alerts, logs for debugging."

##  Troubleshooting Real Incident

**Scenario**: Users report "slow website"

**Step 1: Check Metrics (Grafana)**
```promql
rate(http_request_duration_seconds_sum[5m])
/ rate(http_request_duration_seconds_count[5m])
```
→ Shows average latency jumped from 100ms to 5s at 10:15 AM

**Step 2: Check Service Health**
```promql
up{job="fastapi-app"}
```
→ Service is up (1), not crashed

**Step 3: Check Database Connections**
```promql
active_database_connections
```
→ Pool exhausted (10/10 connections in use)

**Step 4: Check Logs (Loki)**
```logql
{job="fastapi"} |= "ERROR" | json | line_format "{{.timestamp}} {{.message}}"
```
→ Logs show: `psycopg2.pool.PoolError: connection pool exhausted`

**Root Cause**: Database connection pool too small (maxconn=10).

**Fix**: Increase pool size:
```python
maxconn=20  # Was 10
```

**Interview Narrative**: "I used a layered approach: metrics to identify when latency spiked, health checks to rule out crashes, resource metrics to find pool exhaustion, and logs to confirm the exact error. This demonstrates systematic troubleshooting."

##  Production Improvements

1. **Grafana Dashboards**: Create pre-built dashboards for API latency, error rates, DB connections
2. **Alert Routing**: Send critical alerts to PagerDuty, warnings to Slack
3. **Long-term Storage**: Ship metrics to Thanos for unlimited retention
4. **Trace Integration**: Add Jaeger for distributed tracing
5. **Log Retention**: Implement tiered storage (hot 7d, warm 30d, cold 90d)

##  Interview Talking Points

1. **"Three pillars strategy"**: Metrics for trends/alerts, logs for debugging, traces for latency analysis (future).
2. **"Custom business metrics"**: Not just infrastructure - track contact submissions, document uploads.
3. **"Synthetic monitoring with Blackbox"**: Proactive testing from user perspective.
4. **"Layered alerting"**: Severity-based routing prevents alert fatigue.
5. **"Troubleshooting methodology"**: Start with metrics (when), move to logs (why), verify with health checks.
