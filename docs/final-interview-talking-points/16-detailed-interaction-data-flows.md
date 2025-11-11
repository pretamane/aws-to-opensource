# Detailed Interaction & Data Flows: Edge → Backend Services

##  Overview

This document provides **detailed, step-by-step interaction flows and data flows** between the edge proxy (Caddy/ALB), backend services, and data stores. Includes network diagrams, request/response flows, and data movement patterns.

---

## ️ Architecture Overview

### Current Architecture (Caddy as Edge)

```
┌─────────────────────────────────────────────────────────────────┐
│                    COMPLETE TRAFFIC FLOW ARCHITECTURE           │
└─────────────────────────────────────────────────────────────────┘

Internet
    │
    │ HTTPS (TLS terminated at Cloudflare)
    ▼
┌─────────────────┐
│ Cloudflare Edge │ (DDoS protection, TLS termination)
│   (cloudflared) │
└────────┬────────┘
         │
         │ HTTP (plain, internal)
         ▼
┌─────────────────┐
│   Caddy Proxy   │ (:80) - Single entry point
│  (Edge Layer)   │
└────────┬────────┘
         │
         │ Path-based routing
         ├─────────────────────────────────────────────┐
         │                                               │
    ┌────▼────┐                                    ┌────▼────┐
    │ FastAPI │                                    │ Grafana │
    │  :8000  │                                    │  :3000  │
    └────┬────┘                                    └─────────┘
         │
         │ Backend service calls
         ├──────────┬──────────┬──────────┐
         │          │          │          │
    ┌────▼────┐ ┌──▼───┐ ┌────▼────┐ ┌──▼───┐
    │PostgreSQL│ │MinIO │ │Meilisearch│ │AWS SES│
    │  :5432  │ │ :9000│ │  :7700  │ │  API  │
    └─────────┘ └──────┘ └─────────┘ └───────┘

┌─────────────────────────────────────────────────────────────────┐
│              MONITORING & OBSERVABILITY STACK                    │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐
│  Prometheus  │ (:9090) - Metrics storage & querying
│  (Scraper)   │
└──────┬───────┘
       │
       │ Scrapes metrics from:
       ├──────────┬──────────┬──────────┬──────────┬──────────┐
       │          │          │          │          │          │
┌──────▼──────┐ ┌─▼──────┐ ┌─▼──────┐ ┌─▼──────┐ ┌─▼──────┐
│   FastAPI   │ │  Node  │ │cAdvisor│ │Blackbox│ │ MinIO  │
│   :9091     │ │Exporter│ │ :8080  │ │ :9115  │ │ :9000  │
│  (metrics)  │ │ :9100  │ │(contain)│ │(probes)│ │(metrics)│
└─────────────┘ └────────┘ └────────┘ └────────┘ └────────┘

┌──────────────┐
│ Alertmanager │ (:9093) - Alert routing & notifications
│  (Alerting)  │
└──────┬───────┘
       │
       │ Receives alerts from Prometheus
       │ Routes to: Email, Slack, PagerDuty, etc.

┌──────────────┐
│    Promtail  │ (:9080) - Log shipper
│  (Log Agent) │
└──────┬───────┘
       │
       │ Ships logs to:
       └──────────►
              ┌──────────────┐
              │     Loki     │ (:3100) - Log aggregation
              │ (Log Store)  │
              └──────┬───────┘
                     │
                     │ Queried by:
                     └──────────►
                            ┌──────────────┐
                            │   Grafana    │ (:3000) - Visualization
                            │  (Dashboard) │
                            └──────────────┘
```

### With ALB (Alternative Architecture)

```
┌─────────────────────────────────────────────────────────────────┐
│              ALB-BASED ARCHITECTURE (Scalable)                  │
└─────────────────────────────────────────────────────────────────┘

Internet
    │
    │ HTTPS
    ▼
┌─────────────────┐
│   AWS ALB       │ (Application Load Balancer)
│  (Edge Layer)   │ - Health checks
│                 │ - SSL termination
│                 │ - Path-based routing
└────────┬────────┘
         │
         │ Target Groups
         ├─────────────────────────────────────────────┐
         │                                               │
    ┌────▼────┐                                    ┌────▼────┐
    │ Target  │                                    │ Target  │
    │ Group 1 │                                    │ Group 2 │
    │ FastAPI │                                    │ Grafana │
    └────┬────┘                                    └─────────┘
         │
         │ Multiple EC2 instances (Auto Scaling)
         ├──────────┬──────────┐
         │          │          │
    ┌────▼────┐ ┌──▼───┐ ┌────▼────┐
    │ EC2-1   │ │ EC2-2│ │ EC2-3   │
    │ Caddy   │ │Caddy │ │ Caddy   │
    │ FastAPI │ │FastAPI│ │ FastAPI │
    └────┬────┘ └──┬───┘ └────┬────┘
         │         │          │
         └─────────┼──────────┘
                   │
                   │ Shared backend services
                   ├──────────┬──────────┬──────────┐
                   │          │          │          │
              ┌────▼────┐ ┌──▼───┐ ┌────▼────┐
              │PostgreSQL│ │MinIO │ │Meilisearch│
              │  (RDS)  │ │      │ │           │
              └─────────┘ └──────┘ └───────────┘
```

---

##  Part 1: Request Flow - User → FastAPI → Database

### 1.1 Complete Request Flow: Contact Form Submission

**Scenario:** User submits contact form via `/contact` endpoint

```
┌─────────────────────────────────────────────────────────────────┐
│              STEP-BY-STEP REQUEST FLOW                          │
└─────────────────────────────────────────────────────────────────┘

Step 1: User Browser
───────────────────
User fills form and clicks "Submit"
POST https://your-domain.com/contact
Headers:
  Content-Type: application/json
  X-API-Key: your-api-key-here
Body:
  {
    "name": "John Doe",
    "email": "john@example.com",
    "message": "Hello!"
  }

Step 2: Cloudflare Tunnel
─────────────────────────
Cloudflare Edge receives HTTPS request
- Validates TLS certificate
- Applies DDoS protection rules
- Forwards to tunnel endpoint
- Adds headers:
  X-Forwarded-For: 203.0.113.42 (real client IP)
  X-Forwarded-Proto: https
  CF-Connecting-IP: 203.0.113.42
  CF-Ray: 7a3b2c1d9e8f6g5h

Forwards: POST http://caddy:80/contact (plain HTTP)

Step 3: Caddy Reverse Proxy
───────────────────────────
Caddy receives request on :80
- Matches route: handle /contact
- Checks: No Basic Auth required (public endpoint)
- Applies security headers:
  Strict-Transport-Security: max-age=31536000
  X-Content-Type-Options: nosniff
  X-Frame-Options: SAMEORIGIN
  Content-Security-Policy: ...
- Logs request (JSON format):
  {
    "method": "POST",
    "path": "/contact",
    "remote_addr": "172.25.0.1",
    "status": 200,
    "latency": 0.234
  }

Forwards: POST http://fastapi-app:8000/contact
Headers preserved + added:
  X-Forwarded-For: 203.0.113.42
  X-Forwarded-Proto: https
  CF-Connecting-IP: 203.0.113.42

Step 4: FastAPI Application
───────────────────────────
FastAPI receives request
- Middleware extracts correlation ID: abc-123-def-456
- Middleware starts timer: start_time = time.time()
- Validates API key: require_api_key() dependency
  - Checks X-API-Key header
  - Compares with PUBLIC_API_KEY env var
  - If invalid: Returns 401 Unauthorized
- Parses request body: ContactForm model
- Validates data: Pydantic validation
  - name: required, max 100 chars
  - email: required, valid email format
  - message: required, max 1000 chars

Step 5: FastAPI Business Logic
───────────────────────────────
@app.post("/contact")
async def submit_contact(contact_form: ContactForm):
    # 1. Store in database
    result = await db_service.create_contact(
        name=contact_form.name,
        email=contact_form.email,
        message=contact_form.message
    )
    
    # 2. Index in search (background task)
    await search_service.index_contact(result)
    
    # 3. Send email notification (background task)
    await email_service.send_notification(result)
    
    return ContactResponse(id=result.id, status="success")

Step 6: Database Interaction (PostgreSQL)
──────────────────────────────────────────
FastAPI → PostgreSQL connection
- Connection pool: Gets connection from pool
- SQL query:
  INSERT INTO contacts (name, email, message, created_at)
  VALUES ($1, $2, $3, NOW())
  RETURNING id, name, email, message, created_at
- Parameters: ['John Doe', 'john@example.com', 'Hello!']
- PostgreSQL executes query
- Returns: {id: 123, name: 'John Doe', ...}
- Connection returned to pool

Step 7: Search Indexing (Meilisearch)
──────────────────────────────────────
FastAPI → Meilisearch (background task)
- HTTP POST http://meilisearch:7700/indexes/contacts/documents
- Headers:
  Authorization: Bearer ${MEILI_MASTER_KEY}
  Content-Type: application/json
- Body:
  {
    "id": 123,
    "name": "John Doe",
    "email": "john@example.com",
    "message": "Hello!",
    "created_at": "2024-01-15T10:30:00Z"
  }
- Meilisearch indexes document
- Returns: {"taskUid": 456, "status": "enqueued"}

Step 8: Email Notification (AWS SES)
────────────────────────────────────
FastAPI → AWS SES (background task)
- AWS SDK call: boto3.client('ses')
- Uses IAM role credentials (no hardcoded keys)
- Sends email:
  From: ${SES_FROM_EMAIL}
  To: ${SES_TO_EMAIL}
  Subject: New Contact Form Submission
  Body: "John Doe (john@example.com) submitted: Hello!"
- SES delivers email
- Returns: MessageId

Step 9: Response Flow
─────────────────────
FastAPI generates response:
- Status: 200 OK
- Headers:
  Content-Type: application/json
  X-Correlation-ID: abc-123-def-456
- Body:
  {
    "id": 123,
    "status": "success",
    "message": "Contact submitted successfully"
  }

Middleware records metrics:
- http_requests_total.labels(method="POST", endpoint="/contact", status=200).inc()
- http_request_duration_seconds.observe(0.234)

Middleware logs:
{
  "timestamp": "2024-01-15T10:30:00Z",
  "level": "INFO",
  "message": "Request completed: POST /contact - 200",
  "correlation_id": "abc-123-def-456",
  "duration": 0.234
}

Step 10: Caddy → User
──────────────────────
Caddy receives response from FastAPI
- Adds security headers
- Logs response
- Forwards to Cloudflare Tunnel

Cloudflare Tunnel → User Browser
- Receives HTTP response
- Wraps in HTTPS
- Delivers to user browser

User Browser
- Receives 200 OK
- Displays success message
```

---

##  Part 2: Data Flow - Document Upload & Processing

### 2.1 Document Upload Flow

**Scenario:** User uploads a PDF document via `/documents/upload`

```
┌─────────────────────────────────────────────────────────────────┐
│              DOCUMENT UPLOAD DATA FLOW                          │
└─────────────────────────────────────────────────────────────────┘

Step 1: User Uploads File
─────────────────────────
POST https://your-domain.com/documents/upload
Content-Type: multipart/form-data
X-API-Key: your-api-key
Body:
  file: [PDF binary data, 2MB]
  document_type: "resume"

Step 2: Caddy → FastAPI
────────────────────────
Caddy receives multipart/form-data
- Forwards to FastAPI:8000
- Preserves Content-Type header
- Streams data (doesn't buffer entire file)

Step 3: FastAPI Receives File
─────────────────────────────
@app.post("/documents/upload")
async def upload_document(
    file: UploadFile = File(...),
    document_type: str = Form(...)
):
    # 1. Validate file
    if file.size > 50MB:
        raise HTTPException(400, "File too large")
    
    # 2. Read file content
    content = await file.read()  # In-memory buffer
    
    # 3. Generate unique filename
    filename = f"{uuid.uuid4()}.pdf"
    
    # 4. Upload to MinIO
    await storage_service.upload_file(
        bucket="pretamane-data",
        key=f"documents/{filename}",
        data=content
    )

Step 4: MinIO Storage (S3-Compatible)
───────────────────────────────────────
FastAPI → MinIO API
- HTTP PUT http://minio:9000/pretamane-data/documents/abc-123.pdf
- Headers:
  Authorization: AWS4-HMAC-SHA256 ...
  Content-Type: application/pdf
  Content-Length: 2097152
- Body: [PDF binary data]
- MinIO stores file:
  - Writes to disk: /data/pretamane-data/documents/abc-123.pdf
  - Updates metadata
  - Returns: ETag, LastModified

Step 5: Database Record
────────────────────────
FastAPI → PostgreSQL
- INSERT INTO documents (filename, document_type, storage_path, size, created_at)
  VALUES ($1, $2, $3, $4, NOW())
- Parameters:
  - filename: "abc-123.pdf"
  - document_type: "resume"
  - storage_path: "documents/abc-123.pdf"
  - size: 2097152
- Returns: {id: 789, filename: "abc-123.pdf", ...}

Step 6: Search Indexing
────────────────────────
FastAPI → Meilisearch (background task)
- Extracts text from PDF (if possible)
- Indexes document:
  POST http://meilisearch:7700/indexes/documents/documents
  {
    "id": 789,
    "filename": "abc-123.pdf",
    "document_type": "resume",
    "storage_path": "documents/abc-123.pdf",
    "text_content": "Extracted PDF text...",
    "created_at": "2024-01-15T10:35:00Z"
  }

Step 7: Response
───────────────
FastAPI returns:
{
  "id": 789,
  "filename": "abc-123.pdf",
  "document_type": "resume",
  "status": "uploaded",
  "storage_path": "documents/abc-123.pdf"
}
```

---

##  Part 3: Search Query Flow

### 3.1 Document Search Flow

**Scenario:** User searches for documents via `/documents/search`

```
┌─────────────────────────────────────────────────────────────────┐
│              SEARCH QUERY DATA FLOW                              │
└─────────────────────────────────────────────────────────────────┘

Step 1: User Search Request
───────────────────────────
GET https://your-domain.com/documents/search?q=resume&limit=10
Headers:
  X-API-Key: your-api-key

Step 2: Caddy → FastAPI
────────────────────────
Caddy forwards: GET http://fastapi-app:8000/documents/search?q=resume&limit=10

Step 3: FastAPI Search Endpoint
────────────────────────────────
@app.get("/documents/search")
async def search_documents(q: str, limit: int = 10):
    # 1. Search Meilisearch
    results = await search_service.search(
        index="documents",
        query=q,
        limit=limit
    )
    
    # 2. Enrich with database data
    enriched_results = []
    for result in results:
        doc = await db_service.get_document(result['id'])
        enriched_results.append({
            **result,
            'metadata': doc.metadata
        })
    
    return SearchResponse(results=enriched_results)

Step 4: Meilisearch Query
─────────────────────────
FastAPI → Meilisearch
- HTTP GET http://meilisearch:7700/indexes/documents/search?q=resume&limit=10
- Headers:
  Authorization: Bearer ${MEILI_MASTER_KEY}
- Meilisearch processes query:
  - Parses query: "resume"
  - Searches index: documents
  - Applies filters, typo tolerance
  - Ranks results by relevance
  - Returns top 10 matches
- Response:
  {
    "hits": [
      {
        "id": 789,
        "filename": "abc-123.pdf",
        "document_type": "resume",
        "_rankingScore": 0.95
      },
      ...
    ],
    "processingTimeMs": 12,
    "query": "resume"
  }

Step 5: Database Enrichment
────────────────────────────
FastAPI → PostgreSQL
- For each result, fetch metadata:
  SELECT id, filename, document_type, storage_path, size, created_at
  FROM documents
  WHERE id IN (789, 790, 791, ...)
- Returns enriched data

Step 6: Response
───────────────
FastAPI returns:
{
  "results": [
    {
      "id": 789,
      "filename": "abc-123.pdf",
      "document_type": "resume",
      "storage_path": "documents/abc-123.pdf",
      "ranking_score": 0.95
    },
    ...
  ],
  "query": "resume",
  "total": 10,
  "processing_time_ms": 15
}
```

---

##  Part 4: Monitoring & Metrics Flow

### 4.1 Prometheus Scraping Flow - FastAPI

**Scenario:** Prometheus scrapes application metrics from FastAPI

```
┌─────────────────────────────────────────────────────────────────┐
│              PROMETHEUS → FASTAPI METRICS FLOW                  │
└─────────────────────────────────────────────────────────────────┘

Step 1: Prometheus Scrape Schedule
───────────────────────────────────
Prometheus (every 10 seconds):
- Scrape config: prometheus.yml
- Job: fastapi-metrics
- Target: http://fastapi-app:9091/metrics
- Direct Docker network connection (NOT through Caddy)
- No authentication (internal network)
- Scrape timeout: 10s

Step 2: HTTP GET Request
─────────────────────────
Prometheus → FastAPI
- HTTP GET http://fastapi-app:9091/metrics
- Headers: User-Agent: Prometheus/2.x.x
- Connection: Keep-Alive
- Timeout: 10 seconds

Step 3: FastAPI Metrics Endpoint
─────────────────────────────────
@app.get("/metrics")
def metrics():
    return Response(
        content=generate_latest(),  # Prometheus text format
        media_type="text/plain; version=0.0.4"
    )

Step 4: Metrics Response
─────────────────────────
Prometheus receives:
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",endpoint="/health",status="200"} 1523.0
http_requests_total{method="POST",endpoint="/contact",status="200"} 45.0
http_requests_total{method="POST",endpoint="/contact",status="401"} 2.0

# HELP http_request_duration_seconds HTTP request duration
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{method="GET",endpoint="/health",le="0.005"} 1200.0
http_request_duration_seconds_bucket{method="GET",endpoint="/health",le="0.01"} 1500.0
http_request_duration_seconds_sum{method="GET",endpoint="/health"} 8.5
http_request_duration_seconds_count{method="GET",endpoint="/health"} 1523.0

# HELP contact_submissions_total Total contact form submissions
# TYPE contact_submissions_total counter
contact_submissions_total{source="website",service="fastapi"} 45.0

Step 5: Prometheus Storage
───────────────────────────
Prometheus:
- Parses metrics (Prometheus text format)
- Validates metric names and labels
- Stores in time-series database (TSDB)
- Indexes by labels (method, endpoint, status)
- Retention: 15 days (configurable)
- Available for querying via PromQL

Step 6: Grafana Query
──────────────────────
Grafana dashboard queries:
- PromQL: rate(http_requests_total[5m])
- Prometheus returns time-series data
- Grafana visualizes as graph
- Refresh interval: 30 seconds
```

### 4.2 Node Exporter - Host Metrics Collection

**Scenario:** Prometheus scrapes host/system metrics from Node Exporter

```
┌─────────────────────────────────────────────────────────────────┐
│              PROMETHEUS → NODE EXPORTER FLOW                    │
└─────────────────────────────────────────────────────────────────┘

Step 1: Prometheus Scrape Schedule
───────────────────────────────────
Prometheus (every 15 seconds):
- Scrape config: prometheus.yml
- Job: node-exporter
- Target: http://node-exporter:9100/metrics
- Scrape interval: 15s
- Scrape timeout: 10s

Step 2: Node Exporter Metrics Collection
─────────────────────────────────────────
Node Exporter collects system metrics:
- CPU metrics: /proc/stat, /proc/cpuinfo
- Memory metrics: /proc/meminfo
- Disk metrics: /proc/diskstats, /sys/block
- Network metrics: /proc/net/dev, /proc/net/sockstat
- System metrics: /proc/loadavg, /proc/uptime
- Filesystem metrics: df, mount points

Step 3: HTTP GET Request
─────────────────────────
Prometheus → Node Exporter
- HTTP GET http://node-exporter:9100/metrics
- Node Exporter reads /proc filesystem
- Generates Prometheus metrics format

Step 4: Metrics Response
─────────────────────────
Prometheus receives:
# HELP node_cpu_seconds_total Seconds the CPU spent in each mode
# TYPE node_cpu_seconds_total counter
node_cpu_seconds_total{cpu="0",mode="idle"} 12345.67
node_cpu_seconds_total{cpu="0",mode="user"} 2345.89
node_cpu_seconds_total{cpu="0",mode="system"} 567.12

# HELP node_memory_MemTotal_bytes Memory information field MemTotal_bytes
# TYPE node_memory_MemTotal_bytes gauge
node_memory_MemTotal_bytes 8.589934592e+09

# HELP node_filesystem_size_bytes Filesystem size in bytes
# TYPE node_filesystem_size_bytes gauge
node_filesystem_size_bytes{device="/dev/sda1",fstype="ext4",mountpoint="/"} 5.4975581184e+10

# HELP node_network_receive_bytes_total Network device statistic receive_bytes
# TYPE node_network_receive_bytes_total counter
node_network_receive_bytes_total{device="eth0"} 1.23456789e+09

# HELP node_load1 1m load average
# TYPE node_load1 gauge
node_load1 0.75

Step 5: Prometheus Storage
───────────────────────────
Prometheus:
- Stores host metrics with labels (cpu, device, mountpoint)
- Enables queries like:
  - CPU usage: 100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
  - Memory usage: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100
  - Disk usage: (node_filesystem_size_bytes - node_filesystem_avail_bytes) / node_filesystem_size_bytes * 100

Step 6: Grafana Visualization
──────────────────────────────
Grafana dashboard displays:
- CPU utilization graph
- Memory usage graph
- Disk I/O graph
- Network traffic graph
- Load average graph
```

### 4.3 cAdvisor - Container Metrics Collection

**Scenario:** Prometheus scrapes container metrics from cAdvisor

```
┌─────────────────────────────────────────────────────────────────┐
│              PROMETHEUS → cADVISOR FLOW                         │
└─────────────────────────────────────────────────────────────────┘

Step 1: Prometheus Scrape Schedule
───────────────────────────────────
Prometheus (every 15 seconds):
- Scrape config: prometheus.yml
- Job: cadvisor
- Target: http://cadvisor:8080/metrics
- Scrape interval: 15s

Step 2: cAdvisor Container Discovery
─────────────────────────────────────
cAdvisor:
- Discovers Docker containers via Docker API
- Monitors container runtime (Docker daemon)
- Tracks containers: fastapi-app, postgresql, minio, etc.
- Collects metrics for each container

Step 3: cAdvisor Metrics Collection
────────────────────────────────────
cAdvisor collects container metrics:
- CPU usage: /sys/fs/cgroup/cpu/*
- Memory usage: /sys/fs/cgroup/memory/*
- Disk I/O: /sys/fs/cgroup/blkio/*
- Network I/O: /proc/net/dev (filtered by container)
- Container info: Docker API (name, image, labels)

Step 4: HTTP GET Request
─────────────────────────
Prometheus → cAdvisor
- HTTP GET http://cadvisor:8080/metrics
- cAdvisor generates metrics for all containers

Step 5: Metrics Response
─────────────────────────
Prometheus receives:
# HELP container_cpu_usage_seconds_total Cumulative cpu time consumed in seconds
# TYPE container_cpu_usage_seconds_total counter
container_cpu_usage_seconds_total{container="fastapi-app",name="fastapi-app"} 123.45
container_cpu_usage_seconds_total{container="postgresql",name="postgresql"} 67.89

# HELP container_memory_usage_bytes Current memory usage in bytes
# TYPE container_memory_usage_bytes gauge
container_memory_usage_bytes{container="fastapi-app",name="fastapi-app"} 1.23456789e+08
container_memory_usage_bytes{container="postgresql",name="postgresql"} 5.67890123e+08

# HELP container_network_receive_bytes_total Cumulative count of bytes received
# TYPE container_network_receive_bytes_total counter
container_network_receive_bytes_total{container="fastapi-app",name="fastapi-app"} 1.234e+09

# HELP container_fs_reads_bytes_total Cumulative count of bytes read
# TYPE container_fs_reads_bytes_total counter
container_fs_reads_bytes_total{container="fastapi-app",name="fastapi-app"} 5.678e+09

# HELP container_start_time_seconds Start time of the container since unix epoch
# TYPE container_start_time_seconds gauge
container_start_time_seconds{container="fastapi-app",name="fastapi-app"} 1.704e+09

Step 6: Prometheus Storage
───────────────────────────
Prometheus:
- Stores container metrics with labels (container, name)
- Enables queries like:
  - Container CPU: rate(container_cpu_usage_seconds_total{container="fastapi-app"}[5m])
  - Container Memory: container_memory_usage_bytes{container="fastapi-app"}
  - Container Network: rate(container_network_receive_bytes_total{container="fastapi-app"}[5m])

Step 7: Grafana Container Dashboard
────────────────────────────────────
Grafana dashboard displays:
- Container CPU usage per container
- Container memory usage per container
- Container network I/O per container
- Container disk I/O per container
- Container count and status
```

### 4.4 Blackbox Exporter - Synthetic Monitoring

**Scenario:** Prometheus triggers Blackbox probes for health checks

```
┌─────────────────────────────────────────────────────────────────┐
│              PROMETHEUS → BLACKBOX → TARGETS FLOW               │
└─────────────────────────────────────────────────────────────────┘

Step 1: Prometheus Scrape Schedule
───────────────────────────────────
Prometheus (every 30 seconds):
- Scrape config: prometheus.yml
- Job: blackbox-http-public
- Metrics path: /probe
- Params: module=http_2xx
- Targets:
  - http://caddy:80/
  - http://caddy:80/health
  - http://fastapi-app:8000/health

Step 2: Prometheus → Blackbox Request
──────────────────────────────────────
Prometheus → Blackbox Exporter
- HTTP GET http://blackbox:9115/probe?module=http_2xx&target=http://caddy:80/health
- Blackbox receives probe request
- Parses target URL and module

Step 3: Blackbox HTTP Probe
────────────────────────────
Blackbox → Target (Caddy)
- HTTP GET http://caddy:80/health
- Headers: User-Agent: Blackbox Exporter
- Timeout: 5 seconds
- Follow redirects: Yes (max 3)
- Validates: HTTP status 200-299

Step 4: Target Response
────────────────────────
Caddy → Blackbox
- HTTP 200 OK
- Response time: 12ms
- Response body: {"status": "healthy"}
- Headers: Content-Type: application/json

Step 5: Blackbox Metrics Generation
────────────────────────────────────
Blackbox generates metrics:
- probe_http_status_code: 200
- probe_http_duration_seconds: 0.012
- probe_success: 1 (if status 200-299)
- probe_http_ssl: 0 (no SSL)
- probe_http_content_length: 25

Step 6: Blackbox → Prometheus Response
───────────────────────────────────────
Blackbox → Prometheus
- Returns metrics in Prometheus format:
# HELP probe_http_status_code Response HTTP status code
# TYPE probe_http_status_code gauge
probe_http_status_code{instance="http://caddy:80/health",job="blackbox-http-public"} 200

# HELP probe_http_duration_seconds Duration of http request in seconds
# TYPE probe_http_duration_seconds gauge
probe_http_duration_seconds{instance="http://caddy:80/health",job="blackbox-http-public"} 0.012

# HELP probe_success Displays whether or not the probe was a success
# TYPE probe_success gauge
probe_success{instance="http://caddy:80/health",job="blackbox-http-public"} 1

Step 7: Prometheus Storage
───────────────────────────
Prometheus:
- Stores probe metrics
- Enables alerting rules:
  - ALERT ProbeDown: probe_success == 0
  - ALERT ProbeSlow: probe_http_duration_seconds > 1

Step 8: TCP Probes (Database, Services)
────────────────────────────────────────
Prometheus → Blackbox → TCP Targets
- Job: blackbox-tcp
- Module: tcp_connect
- Targets:
  - postgresql:5432
  - meilisearch:7700
  - minio:9000

Blackbox performs TCP connect:
- TCP SYN → Target
- Target responds: TCP SYN-ACK
- Blackbox responds: TCP ACK
- Connection established
- Metrics: probe_tcp_duration_seconds, probe_success
```

### 4.5 MinIO Metrics Scraping

**Scenario:** Prometheus scrapes MinIO S3-compatible storage metrics

```
┌─────────────────────────────────────────────────────────────────┐
│              PROMETHEUS → MINIO METRICS FLOW                    │
└─────────────────────────────────────────────────────────────────┘

Step 1: Prometheus Scrape Schedule
───────────────────────────────────
Prometheus (every 30 seconds):
- Scrape config: prometheus.yml
- Job: minio
- Target: http://minio:9000/minio/v2/metrics/cluster
- Basic Auth: minioadmin / minioadmin

Step 2: HTTP GET Request
─────────────────────────
Prometheus → MinIO
- HTTP GET http://minio:9000/minio/v2/metrics/cluster
- Headers:
  Authorization: Basic bWluaW9hZG1pbjptaW5pb2FkbWlu
  User-Agent: Prometheus/2.x.x

Step 3: MinIO Metrics Response
───────────────────────────────
MinIO exposes Prometheus metrics:
# HELP minio_disk_usage_bytes Total disk usage by a disk
# TYPE minio_disk_usage_bytes gauge
minio_disk_usage_bytes{disk="/data"} 5.67890123e+10

# HELP minio_network_sent_bytes_total Total number of bytes sent
# TYPE minio_network_sent_bytes_total counter
minio_network_sent_bytes_total 1.23456789e+11

# HELP minio_network_received_bytes_total Total number of bytes received
# TYPE minio_network_received_bytes_total counter
minio_network_received_bytes_total 9.87654321e+10

# HELP minio_s3_requests_total Total number of s3 requests
# TYPE minio_s3_requests_total counter
minio_s3_requests_total{request_type="PutObject"} 1234.0
minio_s3_requests_total{request_type="GetObject"} 5678.0

# HELP minio_s3_requests_errors_total Total number of s3 requests with errors
# TYPE minio_s3_requests_errors_total counter
minio_s3_requests_errors_total{request_type="PutObject"} 5.0

Step 4: Prometheus Storage
───────────────────────────
Prometheus:
- Stores MinIO metrics
- Enables queries:
  - Storage usage: minio_disk_usage_bytes
  - Request rate: rate(minio_s3_requests_total[5m])
  - Error rate: rate(minio_s3_requests_errors_total[5m])
```

---

##  Part 4.6: Complete Observability Stack Integration

### 4.6.1 End-to-End Observability Flow

**Scenario:** Complete observability pipeline from application to visualization

```
┌─────────────────────────────────────────────────────────────────┐
│              COMPLETE OBSERVABILITY DATA FLOW                   │
└─────────────────────────────────────────────────────────────────┘

Application Layer (FastAPI)
────────────────────────────
FastAPI generates:
- Metrics: HTTP requests, response times, error rates
- Logs: Request logs, error logs, application logs
- Events: Contact submissions, document uploads

Metrics Collection Pipeline
────────────────────────────
1. FastAPI → Prometheus (every 10s)
   - Endpoint: /metrics
   - Metrics: http_requests_total, http_request_duration_seconds
   
2. Node Exporter → Prometheus (every 15s)
   - Endpoint: /metrics
   - Metrics: node_cpu_seconds_total, node_memory_MemTotal_bytes
   
3. cAdvisor → Prometheus (every 15s)
   - Endpoint: /metrics
   - Metrics: container_cpu_usage_seconds_total, container_memory_usage_bytes
   
4. Blackbox → Prometheus (every 30s)
   - Endpoint: /probe
   - Metrics: probe_success, probe_http_duration_seconds
   
5. MinIO → Prometheus (every 30s)
   - Endpoint: /minio/v2/metrics/cluster
   - Metrics: minio_s3_requests_total, minio_disk_usage_bytes

Log Collection Pipeline
────────────────────────
1. Docker Containers → Log Files
   - Location: /var/lib/docker/containers/*/*-json.log
   - Format: JSON logs with timestamp, stream, log
   
2. Promtail → Docker API
   - Discovers containers
   - Monitors log files
   - Extracts labels: container_name, container_id, image
   
3. Promtail → Loki (every 1s batch)
   - Endpoint: /loki/api/v1/push
   - Format: Protobuf-encoded log streams
   - Batches: 1MB or 1 second timeout

Alerting Pipeline
──────────────────
1. Prometheus → Alert Rule Evaluation (every 15s)
   - Evaluates: alert-rules.yml, slo-rules.yml
   - Conditions: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
   
2. Prometheus → Alertmanager (when alert fires)
   - Endpoint: /api/v1/alerts
   - Format: JSON array of alerts
   - Labels: alertname, severity, service
   
3. Alertmanager → Routing
   - Groups alerts by labels
   - Applies inhibition rules
   - Routes to receivers: email, slack
   
4. Alertmanager → Notifications
   - Email: SMTP server
   - Slack: Webhook URL
   - PagerDuty: API endpoint

Visualization Pipeline
───────────────────────
1. Grafana → Prometheus (user query)
   - Query: rate(http_requests_total[5m])
   - Endpoint: /api/v1/query_range
   - Returns: Time-series data
   
2. Grafana → Loki (user query)
   - Query: {container_name="fastapi-app"} |= "error"
   - Endpoint: /loki/api/v1/query_range
   - Returns: Log streams
   
3. Grafana → Visualization
   - Metrics: Time-series graphs
   - Logs: Log panel with filtering
   - Alerts: Alert panel with status
   - Dashboards: Combined metrics + logs + alerts

Complete Flow Example
──────────────────────
1. User makes request: POST /contact
2. FastAPI processes request:
   - Logs: "INFO Request: POST /contact - 200"
   - Metrics: http_requests_total{method="POST",endpoint="/contact",status="200"}.inc()
3. Promtail collects log: Ships to Loki
4. Prometheus scrapes metrics: Stores in TSDB
5. Grafana displays:
   - Metrics: Request rate graph
   - Logs: Request log entries
6. If error rate > threshold:
   - Prometheus fires alert: HighErrorRate
   - Alertmanager routes: Sends email + Slack
   - User receives: Alert notification
```

---

##  Part 5: Alerting Flow - Prometheus → Alertmanager

### 5.1 Alert Evaluation & Routing

**Scenario:** Prometheus evaluates alert rules and sends alerts to Alertmanager

```
┌─────────────────────────────────────────────────────────────────┐
│              PROMETHEUS → ALERTMANAGER ALERT FLOW               │
└─────────────────────────────────────────────────────────────────┘

Step 1: Prometheus Alert Rule Evaluation
──────────────────────────────────────────
Prometheus (every 15 seconds):
- Evaluates alert rules: alert-rules.yml, slo-rules.yml
- Checks conditions against stored metrics
- Examples:
  - ALERT HighErrorRate: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
  - ALERT ServiceDown: probe_success == 0
  - ALERT HighMemoryUsage: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9

Step 2: Alert Firing
─────────────────────
Prometheus detects alert condition:
- Alert: HighErrorRate
- Status: Firing
- Labels:
  - alertname: HighErrorRate
  - severity: critical
  - service: fastapi-app
  - endpoint: /contact
- Annotations:
  - summary: "High error rate detected"
  - description: "Error rate is 15% (threshold: 10%)"
- Starts at: 2024-01-15T10:30:00Z

Step 3: Prometheus → Alertmanager
───────────────────────────────────
Prometheus → Alertmanager
- HTTP POST http://alertmanager:9093/api/v1/alerts
- Body: JSON array of alerts
[
  {
    "labels": {
      "alertname": "HighErrorRate",
      "severity": "critical",
      "service": "fastapi-app"
    },
    "annotations": {
      "summary": "High error rate detected",
      "description": "Error rate is 15% (threshold: 10%)"
    },
    "startsAt": "2024-01-15T10:30:00Z",
    "endsAt": "0001-01-01T00:00:00Z"
  }
]

Step 4: Alertmanager Processing
─────────────────────────────────
Alertmanager receives alert:
- Groups alerts by labels (group_by: ['alertname', 'severity'])
- Deduplicates similar alerts
- Applies inhibition rules (suppress lower severity if higher severity fires)
- Applies silence rules (user-silenced alerts)
- Routes to receiver based on routing tree

Step 5: Alert Routing
──────────────────────
Alertmanager routing tree (config.yml):
- Route: /severity=critical → receiver: critical-alerts
- Route: /severity=warning → receiver: warning-alerts
- Route: /alertname=ServiceDown → receiver: oncall-team

Routing matches:
- Alert: HighErrorRate (severity: critical)
- Route: critical-alerts
- Receiver: email + slack

Step 6: Alert Notification
───────────────────────────
Alertmanager sends notifications:

Email Notification:
- To: admin@example.com
- Subject: [CRITICAL] HighErrorRate - fastapi-app
- Body:
  Alert: HighErrorRate
  Severity: critical
  Service: fastapi-app
  Description: Error rate is 15% (threshold: 10%)
  Started: 2024-01-15T10:30:00Z

Slack Notification:
- Webhook: https://hooks.slack.com/services/...
- Channel: #alerts
- Message:
   *HighErrorRate* (CRITICAL)
  Service: fastapi-app
  Error rate is 15% (threshold: 10%)
  Started: 2024-01-15T10:30:00Z

Step 7: Alert Resolution
─────────────────────────
When condition no longer true:
- Prometheus: Alert status changes to Resolved
- Prometheus → Alertmanager: Sends resolved alert
- Alertmanager: Sends resolved notification
- Email/Slack: "Alert resolved: HighErrorRate"
```

### 5.2 Alertmanager Web UI

**Scenario:** User views alerts in Alertmanager UI

```
┌─────────────────────────────────────────────────────────────────┐
│              ALERTMANAGER WEB UI ACCESS                         │
└─────────────────────────────────────────────────────────────────┘

Step 1: User Access
───────────────────
User → Caddy: GET /alertmanager
- Caddy: Basic Auth required (pretamane / #ThawZin2k77!)
- Caddy → Alertmanager: GET http://alertmanager:9093

Step 2: Alertmanager UI
────────────────────────
Alertmanager displays:
- Active Alerts: List of firing alerts
- Silenced Alerts: User-silenced alerts
- Alert Groups: Grouped by labels
- Alert Details: Labels, annotations, timeline
- Silence: Create silence rules
- Status: Alertmanager cluster status
```

---

##  Part 6: Logging Flow - Promtail → Loki → Grafana

### 6.1 Promtail Log Collection & Shipping

**Scenario:** Promtail collects logs from containers and ships to Loki

```
┌─────────────────────────────────────────────────────────────────┐
│              PROMTAIL → LOKI LOG SHIPPING FLOW                  │
└─────────────────────────────────────────────────────────────────┘

Step 1: Promtail Container Discovery
─────────────────────────────────────
Promtail (promtail-config.yml):
- Discovers Docker containers via Docker API
- Monitors log files: /var/lib/docker/containers/*/*-json.log
- Tracks containers: fastapi-app, postgresql, caddy, etc.
- Labels: container_name, container_id, image

Step 2: Log File Monitoring
────────────────────────────
Promtail monitors log files:
- FastAPI logs: /var/lib/docker/containers/abc123.../abc123...-json.log
- PostgreSQL logs: /var/lib/docker/containers/def456.../def456...-json.log
- Caddy logs: /var/lib/docker/containers/ghi789.../ghi789...-json.log
- Reads log files: tail -f style (follows new lines)
- Parses JSON logs: Extracts timestamp, level, message

Step 3: Log Processing
───────────────────────
Promtail processes logs:
- Parses JSON log format:
  {
    "log": "2024-01-15T10:30:00Z INFO Request completed: POST /contact - 200\n",
    "stream": "stdout",
    "time": "2024-01-15T10:30:00.123456789Z"
  }
- Extracts labels:
  - job: docker-logs
  - container_name: fastapi-app
  - stream: stdout
  - level: INFO (parsed from log message)
- Adds metadata: hostname, pod labels

Step 4: Log Batching
─────────────────────
Promtail batches logs:
- Batch size: 1048576 bytes (1MB)
- Batch wait: 1 second
- Max batch size: 10MB
- Batch timeout: 10 seconds

Step 5: Promtail → Loki HTTP Push
───────────────────────────────────
Promtail → Loki
- HTTP POST http://loki:3100/loki/api/v1/push
- Headers:
  Content-Type: application/x-protobuf
  X-Scope-OrgID: (optional, for multi-tenancy)
- Body: Protobuf-encoded log streams
- Batch: Multiple log entries in one request

Step 6: Loki Ingestion
───────────────────────
Loki receives log streams:
- Parses Protobuf payload
- Extracts labels and log entries
- Validates labels (label name restrictions)
- Stores logs in chunks (compressed)
- Indexes by labels (label-based indexing)
- Retention: 30 days (configurable)

Step 7: Loki Storage
─────────────────────
Loki stores logs:
- Chunk storage: Filesystem (local) or S3-compatible (MinIO)
- Index storage: Boltdb (local) or Cassandra (distributed)
- Chunk format: Compressed log entries
- Index format: Label → Chunk mapping
- Query performance: Label-based queries are fast
```

### 6.2 Log Query Flow - Grafana → Loki

**Scenario:** User queries logs in Grafana dashboard

```
┌─────────────────────────────────────────────────────────────────┐
│              GRAFANA → LOKI LOG QUERY FLOW                      │
└─────────────────────────────────────────────────────────────────┘

Step 1: User Query in Grafana
──────────────────────────────
User → Grafana: Logs dashboard
- Query: {container_name="fastapi-app"} |= "error"
- Time range: Last 1 hour
- Grafana → Loki: LogQL query

Step 2: Grafana → Loki Query
─────────────────────────────
Grafana → Loki
- HTTP GET http://loki:3100/loki/api/v1/query_range
- Query: {container_name="fastapi-app"} |= "error"
- Parameters:
  - query: {container_name="fastapi-app"} |= "error"
  - limit: 1000
  - start: 1705316400 (Unix timestamp)
  - end: 1705320000 (Unix timestamp)
  - step: 1s

Step 3: Loki Query Processing
──────────────────────────────
Loki processes query:
- Parses LogQL: {container_name="fastapi-app"} |= "error"
- Label matcher: container_name="fastapi-app"
- Line filter: |= "error" (contains "error")
- Searches index: Finds chunks matching label
- Reads chunks: Decompresses and filters logs
- Applies line filter: Filters logs containing "error"

Step 4: Loki Response
──────────────────────
Loki → Grafana
- HTTP 200 OK
- Body: JSON log streams
{
  "status": "success",
  "data": {
    "resultType": "streams",
    "result": [
      {
        "stream": {
          "container_name": "fastapi-app",
          "level": "ERROR",
          "job": "docker-logs"
        },
        "values": [
          ["1705316500000000000", "2024-01-15T10:31:40Z ERROR Database connection failed"],
          ["1705316600000000000", "2024-01-15T10:31:50Z ERROR Request failed: 500 Internal Server Error"]
        ]
      }
    ]
  }
}

Step 5: Grafana Visualization
──────────────────────────────
Grafana displays logs:
- Log panel: Shows log entries
- Time series: Shows log volume over time
- Log details: Timestamp, level, message
- Log filters: Filter by level, search text
- Log context: View logs before/after selected log
```

### 6.3 Real-Time Log Streaming

**Scenario:** User streams logs in real-time

```
┌─────────────────────────────────────────────────────────────────┐
│              REAL-TIME LOG STREAMING FLOW                       │
└─────────────────────────────────────────────────────────────────┘

Step 1: User Starts Live Tail
──────────────────────────────
User → Grafana: Enable "Live" toggle
- Query: {container_name="fastapi-app"}
- Grafana → Loki: WebSocket connection

Step 2: Grafana → Loki WebSocket
──────────────────────────────────
Grafana → Loki
- WebSocket: ws://loki:3100/loki/api/v1/tail
- Query: {container_name="fastapi-app"}
- Loki: Opens tailing connection

Step 3: Real-Time Log Streaming
─────────────────────────────────
Promtail → Loki → Grafana (real-time):
- Promtail ships new log: "2024-01-15T10:32:00Z INFO New request"
- Loki receives log: Stores and streams to connected clients
- Grafana receives log: Displays in log panel in real-time
- User sees: Log appears immediately (no refresh needed)

Step 4: Log Aggregation Queries
────────────────────────────────
Grafana → Loki: Aggregation queries
- Query: sum(count_over_time({container_name="fastapi-app"}[1m]))
- Result: Log volume per minute
- Visualization: Time series graph
```

---

##  Part 7: ALB Integration (Scalable Architecture)

### 7.1 ALB-Based Architecture Flow

**Scenario:** How ALB would replace Caddy for horizontal scaling

```
┌─────────────────────────────────────────────────────────────────┐
│              ALB-BASED REQUEST FLOW                             │
└─────────────────────────────────────────────────────────────────┘

Step 1: User Request
────────────────────
GET https://your-domain.com/api/health
- DNS resolves to ALB endpoint
- ALB receives HTTPS request

Step 2: ALB Processing
───────────────────────
AWS ALB:
- Terminates TLS (SSL certificate from ACM)
- Applies security policies
- Matches listener rule:
  - Path: /api/*
  - Target Group: fastapi-target-group
- Health check: Verifies target health
- Load balancing: Selects healthy target
  - Algorithm: Round-robin (or least connections)
  - Sticky sessions: Optional (session affinity)

Step 3: Target Selection
────────────────────────
ALB selects target from target group:
- Target Group: fastapi-target-group
- Targets:
  - EC2-1:8080 (healthy)
  - EC2-2:8080 (healthy)
  - EC2-3:8080 (healthy)
- Selected: EC2-2:8080

Step 4: Request Forwarding
───────────────────────────
ALB forwards to target:
- HTTP GET http://ec2-2-internal-ip:8080/api/health
- Headers added:
  X-Forwarded-For: 203.0.113.42
  X-Forwarded-Proto: https
  X-Forwarded-Port: 443
  X-Real-IP: 203.0.113.42

Step 5: EC2 Instance (Caddy)
────────────────────────────
EC2-2 receives request:
- Caddy listens on :8080
- Matches route: /api/* → fastapi-app:8000
- Forwards to FastAPI container

Step 6: FastAPI Processing
──────────────────────────
FastAPI processes request (same as before)
- Returns health check response

Step 7: Response Path
─────────────────────
Response flows back:
FastAPI → Caddy → ALB → User
- ALB adds response headers
- ALB terminates connection
- User receives HTTPS response
```

### 7.2 ALB Target Group Configuration

```yaml
# Terraform ALB Configuration
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public.*.id]
  
  enable_deletion_protection = false
  enable_http2                = true
  enable_cross_zone_load_balancing = true
}

resource "aws_lb_target_group" "fastapi" {
  name     = "${var.project_name}-fastapi-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
  }
  
  stickiness {
    enabled = false
    type    = "lb_cookie"
  }
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fastapi.arn
  }
}

resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fastapi.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}
```

---

##  Part 8: Security Headers & Authentication Flow

### 8.1 Authentication Flow

```
┌─────────────────────────────────────────────────────────────────┐
│              AUTHENTICATION & AUTHORIZATION FLOW                 │
└─────────────────────────────────────────────────────────────────┘

Public Endpoint (/api/health)
─────────────────────────────
1. User → Caddy: GET /api/health
2. Caddy checks: No Basic Auth required
3. Caddy → FastAPI: Forwards request
4. FastAPI: No API key required (health check)
5. Response: 200 OK

Protected Endpoint (/contact)
──────────────────────────────
1. User → Caddy: POST /contact
   Headers: X-API-Key: abc123...
2. Caddy: No Basic Auth (public endpoint)
3. Caddy → FastAPI: Forwards with X-API-Key header
4. FastAPI middleware: require_api_key()
   - Extracts X-API-Key header
   - Compares with PUBLIC_API_KEY env var
   - If match: Continue
   - If no match: Returns 401 Unauthorized
5. FastAPI processes request
6. Response: 200 OK or 401 Unauthorized

Admin Endpoint (/grafana)
──────────────────────────
1. User → Caddy: GET /grafana
2. Caddy: Basic Auth required
   - Prompts for username/password
   - Validates: pretamane / #ThawZin2k77!
   - If valid: Continue
   - If invalid: Returns 401 Unauthorized
3. Caddy → Grafana: Forwards request
4. Grafana: May require additional authentication
5. Response: Grafana dashboard or 401
```

---

##  Part 9: Network Communication Matrix

### 9.1 Complete Communication Matrix

| Source | Target | Port | Protocol | Purpose | Auth Required |
|--------|--------|------|----------|---------|---------------|
| **User Browser** | Cloudflare | 443 | HTTPS | All user traffic | No (TLS) |
| **Cloudflare** | Caddy | 80 | HTTP | Tunnel forwarding | No (internal) |
| **Caddy** | FastAPI | 8000 | HTTP | API requests | No (internal) |
| **Caddy** | Grafana | 3000 | HTTP | Dashboard | Basic Auth |
| **Caddy** | Prometheus | 9090 | HTTP | Metrics UI | Basic Auth |
| **Caddy** | Alertmanager | 9093 | HTTP | Alert UI | Basic Auth |
| **Caddy** | MinIO Console | 9001 | HTTP | Storage UI | Basic Auth |
| **FastAPI** | PostgreSQL | 5432 | PostgreSQL | Database queries | Password |
| **FastAPI** | Meilisearch | 7700 | HTTP | Search queries | API Key |
| **FastAPI** | MinIO API | 9000 | HTTP (S3) | File storage | Access Key |
| **FastAPI** | AWS SES | 443 | HTTPS | Email sending | IAM Role |
| **Prometheus** | FastAPI | 9091 | HTTP | Metrics scraping | No (internal) |
| **Prometheus** | Node Exporter | 9100 | HTTP | Host metrics scraping | No (internal) |
| **Prometheus** | cAdvisor | 8080 | HTTP | Container metrics scraping | No (internal) |
| **Prometheus** | Blackbox | 9115 | HTTP | Probe metrics scraping | No (internal) |
| **Prometheus** | MinIO | 9000 | HTTP | Storage metrics scraping | Basic Auth |
| **Prometheus** | Alertmanager | 9093 | HTTP | Alert sending | No (internal) |
| **Blackbox** | Caddy | 80 | HTTP | HTTP health probes | No (internal) |
| **Blackbox** | FastAPI | 8000 | HTTP | HTTP health probes | No (internal) |
| **Blackbox** | PostgreSQL | 5432 | TCP | TCP connect probes | No (internal) |
| **Blackbox** | Meilisearch | 7700 | TCP | TCP connect probes | No (internal) |
| **Blackbox** | MinIO | 9000 | TCP | TCP connect probes | No (internal) |
| **Grafana** | Prometheus | 9090 | HTTP | Query metrics | No (internal) |
| **Grafana** | Loki | 3100 | HTTP | Query logs | No (internal) |
| **Promtail** | Docker API | 2375 | HTTP | Container log discovery | No (internal) |
| **Promtail** | Loki | 3100 | HTTP | Ship logs | No (internal) |
| **Loki** | MinIO | 9000 | HTTP (S3) | Log chunk storage | Access Key |
| **Alertmanager** | Email SMTP | 587 | SMTP | Email notifications | Username/Password |
| **Alertmanager** | Slack API | 443 | HTTPS | Slack notifications | Webhook URL |

---

##  Part 10: Data Flow Patterns

### 10.1 Write Pattern (Contact Submission)

```
User Input
    │
    ▼
Caddy (validates, logs)
    │
    ▼
FastAPI (validates API key, parses data)
    │
    ├─→ PostgreSQL (writes contact record)
    │       │
    │       └─→ Returns: {id: 123, ...}
    │
    ├─→ Meilisearch (indexes in background)
    │       │
    │       └─→ Returns: {taskUid: 456}
    │
    └─→ AWS SES (sends email in background)
            │
            └─→ Returns: {messageId: "abc"}
    │
    ▼
Response to User
```

### 8.2 Read Pattern (Document Search)

```
User Query
    │
    ▼
Caddy (routes to FastAPI)
    │
    ▼
FastAPI (validates API key)
    │
    ├─→ Meilisearch (search index)
    │       │
    │       └─→ Returns: [{id: 789, score: 0.95}, ...]
    │
    └─→ PostgreSQL (enrich with metadata)
            │
            └─→ Returns: {id: 789, filename: "...", ...}
    │
    ▼
Response to User (combined results)
```

### 10.3 File Upload Pattern

```
User Upload (multipart/form-data)
    │
    ▼
Caddy (streams to FastAPI)
    │
    ▼
FastAPI (reads file into memory)
    │
    ├─→ MinIO (uploads file)
    │       │
    │       └─→ Returns: {etag: "...", path: "documents/abc.pdf"}
    │
    ├─→ PostgreSQL (saves metadata)
    │       │
    │       └─→ Returns: {id: 789, ...}
    │
    └─→ Meilisearch (indexes in background)
            │
            └─→ Returns: {taskUid: 456}
    │
    ▼
Response to User
```

---

##  Part 11: Key Differences: Caddy vs ALB

### 11.1 Comparison Table

| Feature | Caddy (Current) | ALB (Scalable) |
|---------|----------------|----------------|
| **Cost** | Free | ~$20/month |
| **TLS** | Cloudflare handles | ACM certificate |
| **Load Balancing** | Single instance | Multiple targets |
| **Health Checks** | Basic | Advanced (configurable) |
| **Path Routing** | Native (Caddyfile) | Listener rules |
| **SSL Termination** | Cloudflare | ALB |
| **DDoS Protection** | Cloudflare | AWS Shield (paid) |
| **Scaling** | Vertical only | Horizontal (Auto Scaling) |
| **Configuration** | Caddyfile | Terraform/Console |
| **Subpath Routing** | Native support | Requires path rewriting |

### 11.2 When to Use Each

**Use Caddy When:**
- Single instance deployment
- Cost optimization is priority
- Simple path-based routing
- Cloudflare Tunnel for TLS

**Use ALB When:**
- Multiple instances needed
- High availability required
- Auto Scaling needed
- AWS-native integration preferred

---

##  Summary

### Key Takeaways:

1. **Single Entry Point**: Caddy consolidates all traffic through one port
2. **Path-Based Routing**: Different paths route to different services
3. **Internal Networking**: Services communicate via Docker DNS
4. **Security Layers**: Edge auth (Caddy) + Application auth (FastAPI)
5. **Data Flow**: User → Edge → App → Backend → Response
6. **Metrics Flow**: Prometheus scrapes directly from FastAPI, Node Exporter, cAdvisor, Blackbox, MinIO
7. **Logging Flow**: Promtail collects logs → Loki stores logs → Grafana queries logs
8. **Alerting Flow**: Prometheus evaluates rules → Alertmanager routes alerts → Notifications (Email/Slack)
9. **Synthetic Monitoring**: Blackbox performs HTTP/TCP probes for health checks
10. **ALB Alternative**: For horizontal scaling, ALB replaces Caddy

### Interview Talking Points:

- **Edge Consolidation**: Reduced attack surface from 8 ports to 1
- **Path-Based Routing**: Simplified service discovery
- **Internal Networking**: Docker DNS eliminates need for service registry
- **Security Defense-in-Depth**: Multiple authentication layers
- **Complete Observability**: Metrics (Prometheus), Logs (Loki), Alerts (Alertmanager)
- **Host Metrics**: Node Exporter collects system-level metrics (CPU, memory, disk, network)
- **Container Metrics**: cAdvisor collects container-level metrics (per-container CPU, memory, I/O)
- **Synthetic Monitoring**: Blackbox performs HTTP/TCP health probes for service availability
- **Log Aggregation**: Promtail ships container logs to Loki for centralized log storage
- **Alert Routing**: Alertmanager routes alerts based on severity to Email/Slack
- **Scalability Path**: Can migrate to ALB + Auto Scaling when needed

