# Metrics Delivery Flow: Caddy + FastAPI → Prometheus

## Overview

This document explains how metrics flow through your system from application code to Prometheus, and how Caddy acts as the routing layer.

---

## ️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    METRICS FLOW DIAGRAM                         │
└─────────────────────────────────────────────────────────────────┘

User Request Flow:
┌──────────┐     ┌──────────┐     ┌──────────────┐     ┌─────────────┐
│  User    │────▶│ Cloudflare│────▶│    Caddy     │────▶│  FastAPI    │
│ Browser  │     │  Tunnel   │     │ Reverse Proxy│     │   App       │
└──────────┘     └──────────┘     └──────────────┘     └─────────────┘
                                                              │
                                                              │ Metrics
                                                              │ Collected
                                                              ▼
Metrics Scraping Flow:
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│ Prometheus  │────▶│ Docker Network│────▶│  FastAPI    │
│  (Scraper)  │     │  (Internal)   │     │ /metrics    │
└─────────────┘     └──────────────┘     └─────────────┘
        │
        │ Stores & Queries
        ▼
┌─────────────┐
│   Grafana   │
│ (Dashboard) │
└─────────────┘
```

---

##  Part 1: How FastAPI Generates Metrics

### 1.1 Metrics Definition (app_opensource.py)

FastAPI uses the `prometheus_client` library to define metrics:

```python
# Request metrics
http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']  # Labels for filtering
)

http_request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint']
)

# Business metrics
contact_submissions_total = Counter(
    'contact_submissions_total',
    'Total contact form submissions',
    ['source', 'service']
)
```

**What this means:**
- **Counter**: Increments (e.g., total requests, total errors)
- **Histogram**: Measures distributions (e.g., response times, request sizes)
- **Gauge**: Current value (e.g., active connections, queue size)

### 1.2 Metrics Collection Middleware

Every request goes through middleware that automatically collects metrics:

```python
@app.middleware("http")
async def correlation_and_metrics_middleware(request: Request, call_next):
    """Add correlation ID and collect metrics for each request"""
    start_time = time.time()
    
    try:
        response = await call_next(request)
        
        # Record metrics AFTER request completes
        duration = time.time() - start_time
        
        # Increment request counter
        http_requests_total.labels(
            method=request.method,
            endpoint=request.url.path,
            status=response.status_code
        ).inc()
        
        # Record duration histogram
        http_request_duration_seconds.labels(
            method=request.method,
            endpoint=request.url.path
        ).observe(duration)
        
        return response
    except Exception as e:
        # Record error metrics
        http_requests_total.labels(
            method=request.method,
            endpoint=request.url.path,
            status=500
        ).inc()
        raise
```

**Flow:**
1. Request arrives → Middleware starts timer
2. Request processed → FastAPI handles it
3. Response sent → Middleware records metrics
4. Metrics stored in memory → Available at `/metrics` endpoint

### 1.3 Metrics Endpoint

FastAPI exposes metrics in Prometheus format:

```python
@app.get("/metrics")
def metrics():
    """Prometheus metrics endpoint"""
    return Response(
        content=generate_latest(),  # Generates Prometheus text format
        media_type=CONTENT_TYPE_LATEST  # "text/plain; version=0.0.4"
    )
```

**What `generate_latest()` does:**
- Reads all registered metrics from memory
- Formats them in Prometheus text format
- Returns something like:

```
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",endpoint="/health",status="200"} 1523.0
http_requests_total{method="POST",endpoint="/contact",status="200"} 45.0
http_requests_total{method="GET",endpoint="/api/docs",status="401"} 12.0

# HELP http_request_duration_seconds HTTP request duration in seconds
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{method="GET",endpoint="/health",le="0.005"} 1200.0
http_request_duration_seconds_bucket{method="GET",endpoint="/health",le="0.01"} 1500.0
http_request_duration_seconds_bucket{method="GET",endpoint="/health",le="+Inf"} 1523.0
http_request_duration_seconds_sum{method="GET",endpoint="/health"} 8.5
http_request_duration_seconds_count{method="GET",endpoint="/health"} 1523.0
```

---

##  Part 2: How Caddy Routes Metrics Requests

### 2.1 Current Setup: Metrics NOT Exposed via Caddy

**Important:** Your `/metrics` endpoint is **NOT** routed through Caddy. This is intentional for security.

**Caddyfile (what's NOT there):**
```caddyfile
#  This route does NOT exist in your Caddyfile
handle /metrics {
    reverse_proxy fastapi-app:8000
}
```

**Why?**
- Metrics contain sensitive information (request patterns, error rates)
- Should only be accessible internally (Prometheus)
- Not exposed to public internet

### 2.2 How Prometheus Accesses Metrics

Prometheus scrapes metrics **directly** from FastAPI via Docker's internal network:

```yaml
# prometheus.yml
scrape_configs:
  - job_name: "fastapi-app"
    static_configs:
      - targets: ["fastapi-app:9091"]  # Direct Docker network access
    metrics_path: "/metrics"
```

**Network Flow:**
```
Prometheus Container
    │
    │ (Docker internal network: app-network)
    │
    ▼
FastAPI Container (fastapi-app:8000/metrics)
    OR
FastAPI Container (fastapi-app:9091/metrics) [if separate server]
```

**Current Setup:**
- FastAPI exposes `/metrics` endpoint on **port 8000** (same as API)
- Prometheus is configured to scrape from **port 9091** (separate port)
- **This is a configuration mismatch** - needs to be fixed

**Two Options:**

**Option 1: Metrics on Same Port (Current Implementation)**
- Metrics available at: `http://fastapi-app:8000/metrics`
- Prometheus config should be: `targets: ["fastapi-app:8000"]`
- **Pros**: Simpler, no extra server
- **Cons**: Metrics accessible if someone gets network access

**Option 2: Separate Metrics Port (Intended Design)**
- Requires separate HTTP server on port 9091
- Metrics available at: `http://fastapi-app:9091/metrics`
- Prometheus config: `targets: ["fastapi-app:9091"]`  (already configured)
- **Pros**: More secure (security through obscurity)
- **Cons**: Requires additional code to start metrics server

**To verify current setup:**
```bash
# Check if metrics are on port 8000 (current)
docker exec -it fastapi-app curl http://localhost:8000/metrics

# Check if metrics are on port 9091 (intended, but not implemented)
docker exec -it fastapi-app curl http://localhost:9091/metrics
# This will likely fail - port 9091 not listening
```

**To fix the mismatch:**
Either:
1. Change Prometheus config to use port 8000, OR
2. Implement separate metrics server on port 9091

---

##  Part 3: Complete Metrics Flow

### 3.1 User Request → Metrics Collection

```
Step 1: User makes request
┌──────────┐
│  User    │ GET /api/health
│ Browser  │
└────┬─────┘
     │
     ▼
Step 2: Cloudflare Tunnel (TLS termination)
┌──────────┐
│Cloudflare│ HTTPS → HTTP
│  Tunnel  │
└────┬─────┘
     │
     ▼
Step 3: Caddy routes to FastAPI
┌──────────┐
│  Caddy   │ reverse_proxy fastapi-app:8000
│  :80     │
└────┬─────┘
     │
     ▼
Step 4: FastAPI processes request
┌─────────────┐
│  FastAPI    │
│  :8000      │
│             │
│ Middleware: │
│ 1. Start timer
│ 2. Process request
│ 3. Record metrics:
│    - http_requests_total++
│    - http_request_duration_seconds.observe()
│ 4. Return response
└─────────────┘
```

### 3.2 Prometheus Scraping → Storage

```
Step 1: Prometheus scrapes (every 10 seconds)
┌─────────────┐
│ Prometheus  │ GET /metrics
│  :9090      │
└────┬────────┘
     │
     │ (Docker network: app-network)
     │ Direct connection (NOT through Caddy)
     │
     ▼
Step 2: FastAPI returns metrics
┌─────────────┐
│  FastAPI    │ Response: Prometheus text format
│  :9091      │
│ /metrics    │
└─────────────┘
     │
     ▼
Step 3: Prometheus stores metrics
┌─────────────┐
│ Prometheus  │ Stores in time-series database
│  Database   │
└─────────────┘
```

### 3.3 Grafana Visualization

```
Step 1: User opens Grafana dashboard
┌──────────┐
│  User    │ http://your-domain/grafana
│ Browser  │
└────┬─────┘
     │
     ▼
Step 2: Caddy routes to Grafana (with Basic Auth)
┌──────────┐
│  Caddy   │ reverse_proxy grafana:3000
│  :80     │
└────┬─────┘
     │
     ▼
Step 3: Grafana queries Prometheus
┌─────────────┐     ┌─────────────┐
│  Grafana    │────▶│ Prometheus  │
│  :3000      │     │  :9090      │
│             │     │             │
│ Dashboard:  │     │ Query:      │
│ - Request   │     │ rate(http_  │
│   rate      │     │  requests_  │
│ - Latency   │     │  total[5m]) │
│ - Errors    │     │             │
└─────────────┘     └─────────────┘
```

---

##  Part 4: Detailed Technical Flow

### 4.1 Metrics Collection in Code

**Example: Contact Form Submission**

```python
@app.post("/contact")
async def submit_contact(contact_form: ContactForm):
    """Submit contact form"""
    start_time = time.time()
    
    try:
        # Business logic
        result = await db_service.create_contact(...)
        
        # Business metric (explicit)
        contact_submissions_total.labels(
            source="website",
            service="fastapi"
        ).inc()
        
        return result
    except Exception as e:
        # Error automatically recorded by middleware
        raise
```

**What gets recorded:**
1. **Automatic (middleware):**
   - `http_requests_total{method="POST", endpoint="/contact", status="200"}` +1
   - `http_request_duration_seconds{method="POST", endpoint="/contact"}` = 0.234s

2. **Explicit (business logic):**
   - `contact_submissions_total{source="website", service="fastapi"}` +1

### 4.2 Metrics Endpoint Response

**Request:**
```bash
curl http://fastapi-app:8000/metrics
```

**Response (Prometheus format):**
```
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",endpoint="/health",status="200"} 1523.0
http_requests_total{method="POST",endpoint="/contact",status="200"} 45.0
http_requests_total{method="POST",endpoint="/contact",status="401"} 2.0

# HELP http_request_duration_seconds HTTP request duration in seconds
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{method="GET",endpoint="/health",le="0.005"} 1200.0
http_request_duration_seconds_bucket{method="GET",endpoint="/health",le="0.01"} 1500.0
http_request_duration_seconds_bucket{method="GET",endpoint="/health",le="+Inf"} 1523.0
http_request_duration_seconds_sum{method="GET",endpoint="/health"} 8.5
http_request_duration_seconds_count{method="GET",endpoint="/health"} 1523.0

# HELP contact_submissions_total Total contact form submissions
# TYPE contact_submissions_total counter
contact_submissions_total{source="website",service="fastapi"} 45.0
```

### 4.3 Prometheus Scraping Configuration

```yaml
# prometheus.yml
scrape_configs:
  - job_name: "fastapi-app"
    static_configs:
      - targets: ["fastapi-app:9091"]  # Docker service name + port
        labels:
          service: "fastapi-app"
          component: "application"
    scrape_interval: 10s  # How often to scrape
    metrics_path: "/metrics"  # Endpoint path
```

**What Prometheus does:**
1. Every 10 seconds, Prometheus makes HTTP GET request to `http://fastapi-app:9091/metrics`
2. FastAPI responds with metrics in Prometheus format
3. Prometheus parses and stores metrics in its time-series database
4. Metrics are queryable via PromQL (Prometheus Query Language)

---

##  Part 5: Security Considerations

### 5.1 Why Metrics Are NOT Public

**Current Setup:**
- `/metrics` endpoint is **NOT** in Caddyfile
- Only accessible via Docker internal network
- Prometheus scrapes directly (no Caddy routing)

**Security Benefits:**
1. **No public exposure**: Can't be accessed from internet
2. **No authentication needed**: Internal network is trusted
3. **Reduced attack surface**: One less endpoint to secure

### 5.2 If You Need Public Metrics (Not Recommended)

**Option 1: Expose via Caddy with Basic Auth**
```caddyfile
handle /metrics {
    basic_auth {
        pretamane $2a$14$VBOmQYX9BQOaEPTCUXEIGekFJp9xfzMo8cs7ocDgMcjTYr68mIuNO
    }
    reverse_proxy fastapi-app:8000
}
```

**Option 2: Separate Metrics Port (Current Intent)**
```python
# Run separate metrics server on port 9091
from prometheus_client import start_http_server

# In startup
start_http_server(9091)  # Separate server for metrics
```

**Why separate port?**
- Metrics on port 8000: Accessible if someone gets into your network
- Metrics on port 9091: Only Prometheus knows about it (security through obscurity)

---

##  Part 6: Metrics Types and Use Cases

### 6.1 Request Metrics (Automatic)

**Collected by middleware:**
- `http_requests_total`: Total requests by method, endpoint, status
- `http_request_duration_seconds`: Response time distribution

**Use cases:**
- **Rate monitoring**: How many requests per second?
- **Error tracking**: What percentage are errors?
- **Performance**: What's the 95th percentile latency?

**Grafana queries:**
```promql
# Request rate
rate(http_requests_total[5m])

# Error rate
rate(http_requests_total{status=~"5.."}[5m])

# 95th percentile latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

### 6.2 Business Metrics (Explicit)

**Collected in business logic:**
- `contact_submissions_total`: Contact form submissions
- `document_uploads_total`: Document uploads
- `document_search_queries_total`: Search queries

**Use cases:**
- **Business intelligence**: How many contacts per day?
- **Feature usage**: Which features are most used?
- **Growth tracking**: Is usage increasing?

**Grafana queries:**
```promql
# Contact submissions per hour
rate(contact_submissions_total[1h])

# Total documents uploaded
sum(document_uploads_total)
```

### 6.3 System Metrics (Gauges)

**Current values:**
- `active_database_connections`: Current DB connections
- `website_visitor_count`: Current visitor count

**Use cases:**
- **Resource monitoring**: Are we hitting connection limits?
- **Capacity planning**: How many concurrent users?

---

## ️ Part 7: Troubleshooting Metrics

### 7.1 Check if Metrics Are Being Collected

```bash
# From inside Docker network
docker exec -it fastapi-app curl http://localhost:8000/metrics

# Should return Prometheus format text
```

### 7.2 Check if Prometheus Is Scraping

```bash
# Access Prometheus UI (via Caddy)
http://your-domain/prometheus/targets

# Should show "fastapi-app" target as "UP"
```

### 7.3 Check Metrics in Grafana

1. Open Grafana: `http://your-domain/grafana`
2. Go to Explore
3. Query: `http_requests_total`
4. Should see data points

### 7.4 Common Issues

**Issue 1: No metrics in Prometheus**
- **Check**: Is FastAPI `/metrics` endpoint responding?
- **Fix**: Verify `prometheus_client` is installed and metrics are registered

**Issue 2: Prometheus can't reach FastAPI**
- **Check**: Are they on the same Docker network?
- **Fix**: Verify `docker-compose.yml` network configuration

**Issue 3: Metrics show zero**
- **Check**: Are requests actually going through FastAPI?
- **Fix**: Verify Caddy is routing correctly

---

##  Interview Talking Points

### Key Points to Emphasize:

1. **Separation of Concerns:**
   - Caddy handles routing and security
   - FastAPI handles business logic and metrics collection
   - Prometheus handles metrics storage and querying

2. **Security:**
   - Metrics endpoint not exposed publicly
   - Internal network access only
   - No authentication needed (trusted network)

3. **Observability:**
   - Automatic metrics collection (middleware)
   - Business metrics (explicit in code)
   - Full request tracing (correlation IDs)

4. **Scalability:**
   - Metrics don't impact request performance (async)
   - Prometheus can scrape multiple instances
   - Grafana can query multiple Prometheus instances

5. **Production-Ready:**
   - SLO monitoring (slo-rules.yml)
   - Budget-burn alerts
   - Structured logging with correlation IDs

---

##  Summary

**Flow:**
1. **User Request** → Caddy → FastAPI → Metrics collected in memory
2. **Prometheus** → Scrapes FastAPI `/metrics` → Stores in time-series DB
3. **Grafana** → Queries Prometheus → Displays dashboards

**Key Concepts:**
- Metrics are collected **automatically** by middleware
- Metrics are exposed on **internal network only** (not via Caddy)
- Prometheus **pulls** metrics (not push)
- All metrics are in **Prometheus text format**

**Security:**
- `/metrics` endpoint is **NOT** in Caddyfile
- Only accessible via Docker internal network
- Prometheus scrapes directly (no public exposure)

