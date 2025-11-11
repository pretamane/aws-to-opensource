# Application Layer: FastAPI

## Role & Responsibilities
Main application implementing business logic, API endpoints, document processing, and observability instrumentation.

## Architecture

### Service Location
- Container: `fastapi-app`
- Config: `docker-compose/docker-compose.yml`
- Code: `docker/api/app_opensource.py`
- Components: `docker/api/components/` (background tasks, document processor)
- Models: `docker/api/models/` (Pydantic validation schemas)

### Service Dependencies
```
FastAPI
  ├─ PostgreSQL (database_service_postgres.py) - CRUD, analytics, counters
  ├─ MinIO (storage_service_minio.py) - S3-compatible uploads/downloads
  ├─ Meilisearch (search_service_meilisearch.py) - indexing, full-text search
  ├─ AWS SES (email_service.py) - notifications
  └─ Prometheus - metrics exposure on /metrics
```

## Technical Implementation

### Application Initialization
```python
app = FastAPI(
    title="Cloud-Native Document Management Platform - Open Source Edition",
    description="Enterprise document processing with PostgreSQL, Meilisearch, and MinIO",
    version="4.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS middleware
app.add_middleware(CORSMiddleware, ...)

# Service abstractions
db_service = PostgreSQLService()
search_service = MeilisearchService()
storage_service = MinIOStorageService()
email_service = EmailService()
```

### Request Flow
1. **Caddy receives request** → forwards to FastAPI on port 8000
2. **CORS middleware** → validates origin, methods, headers
3. **Metrics middleware** → records request start time
4. **Route handler** → processes with Pydantic validation
5. **Service layer** → interacts with PostgreSQL/MinIO/Meilisearch
6. **Response** → updates metrics (duration, status), returns JSON
7. **Background tasks** → async processing (document enrichment, indexing)

### Prometheus Instrumentation

#### Business Metrics
```python
# Counters (monotonically increasing)
contact_submissions_total = Counter(
    'contact_submissions_total',
    'Total contact form submissions',
    ['source', 'service']
)

document_uploads_total = Counter(
    'document_uploads_total',
    'Total document uploads',
    ['document_type', 'status']
)

document_search_queries_total = Counter(
    'document_search_queries_total',
    'Total search queries'
)

# Gauges (current value)
active_connections = Gauge(
    'active_database_connections',
    'Number of active database connections'
)

visitor_count_gauge = Gauge(
    'website_visitor_count',
    'Total website visitor count'
)
```

#### HTTP Metrics
```python
http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

http_request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint']
)
```

#### Middleware Implementation
```python
@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time
    
    http_request_duration_seconds.labels(
        method=request.method,
        endpoint=request.url.path
    ).observe(duration)
    
    http_requests_total.labels(
        method=request.method,
        endpoint=request.url.path,
        status=response.status_code
    ).inc()
    
    return response
```

### API Endpoints

#### Core Endpoints
- `GET /` - API info, version, capabilities
- `GET /health` - Health check (DB, search, storage connectivity)
- `GET /metrics` - Prometheus metrics exposition
- `GET /docs` - Swagger UI (auto-generated)

#### Business Endpoints
- `POST /contact` - Submit contact form with optional attachments
- `POST /documents/upload` - Upload documents (17 file types supported)
- `POST /documents/search` - Full-text search with filters
- `GET /documents/{id}` - Retrieve document metadata
- `GET /contacts/{id}/documents` - List documents for contact
- `GET /analytics/insights` - System analytics and trends
- `GET /stats` - Visitor statistics

### Document Processing Pipeline

#### Upload Flow
```python
@app.post("/documents/upload")
async def upload_document(
    contact_id: str,
    file: UploadFile,
    background_tasks: BackgroundTasks
):
    # 1. Validate file type
    if not is_supported_type(file.content_type):
        raise HTTPException(400, "Unsupported file type")
    
    # 2. Generate document ID
    doc_id = str(uuid.uuid4())
    
    # 3. Upload to MinIO
    file_content = await file.read()
    s3_key = f"documents/{contact_id}/{doc_id}/{file.filename}"
    storage_service.upload_file(file_content, s3_key, content_type=file.content_type)
    
    # 4. Create DB record
    doc_record = {
        'id': doc_id,
        'contact_id': contact_id,
        'filename': file.filename,
        'size': len(file_content),
        'content_type': file.content_type,
        'processing_status': 'pending'
    }
    db_service.create_document_record(doc_record)
    
    # 5. Schedule background processing
    background_tasks.add_task(process_document, doc_id)
    
    # 6. Update metrics
    document_uploads_total.labels(
        document_type=file.content_type,
        status='success'
    ).inc()
    
    return {"document_id": doc_id, "status": "uploaded"}
```

#### Background Processing
```python
async def process_document(doc_id: str):
    # 1. Retrieve from storage
    doc = db_service.get_document(doc_id)
    file_content = storage_service.download_file(doc['s3_key'])
    
    # 2. Extract text
    text = extract_text(file_content, doc['content_type'])
    
    # 3. Analyze content
    metadata = {
        'word_count': len(text.split()),
        'language': detect_language(text),
        'keywords': extract_keywords(text),
        'entities': extract_entities(text)
    }
    
    # 4. Update DB
    db_service.update_document_status(doc_id, 'completed', metadata)
    
    # 5. Index for search
    search_service.index_document({
        'id': doc_id,
        'contact_id': doc['contact_id'],
        'filename': doc['filename'],
        'text_content': text,
        'metadata': metadata
    })
```

### Error Handling & Resilience

#### Service Connection Retries
```python
# PostgreSQL with connection pool
# - Pool exhaustion: blocks until connection available
# - Connection failure: pool automatically retries
# - Health check detects persistent issues

# MinIO retries
for attempt in range(3):
    try:
        return storage_service.upload_file(...)
    except Exception as e:
        if attempt == 2:
            raise
        time.sleep(2 ** attempt)  # exponential backoff
```

#### Correlation IDs
```python
@app.middleware("http")
async def add_correlation_id(request: Request, call_next):
    correlation_id = request.headers.get('X-Correlation-ID', str(uuid.uuid4()))
    request.state.correlation_id = correlation_id
    
    logger.info(f"[{correlation_id}] {request.method} {request.url.path}")
    response = await call_next(request)
    response.headers['X-Correlation-ID'] = correlation_id
    
    return response
```

### Health Checks

#### Comprehensive Health Endpoint
```python
@app.get("/health")
async def health_check():
    health = {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "components": {}
    }
    
    # Check PostgreSQL
    try:
        db_service.get_visitor_count()
        health["components"]["database"] = "healthy"
    except:
        health["components"]["database"] = "unhealthy"
        health["status"] = "degraded"
    
    # Check MinIO
    try:
        storage_service.bucket_exists('pretamane-data')
        health["components"]["storage"] = "healthy"
    except:
        health["components"]["storage"] = "unhealthy"
        health["status"] = "degraded"
    
    # Check Meilisearch
    try:
        search_service.get_index()
        health["components"]["search"] = "healthy"
    except:
        health["components"]["search"] = "unhealthy"
        health["status"] = "degraded"
    
    return health
```

## Failure Modes & Recovery

### Database Unavailable
- **Symptom**: 500 errors on all endpoints requiring DB
- **Detection**: Health check fails, Prometheus alert fires
- **Recovery**: Connection pool retries; Docker restart policy restarts PostgreSQL
- **Mitigation**: Increase connection pool timeout, add circuit breaker

### MinIO Unreachable
- **Symptom**: Document uploads fail
- **Detection**: Upload endpoint returns 500, metrics show storage errors
- **Recovery**: Retry with exponential backoff, fallback to local disk temporarily
- **Mitigation**: Implement upload queue for retry later

### Meilisearch Down
- **Symptom**: Search returns empty results
- **Detection**: Search endpoint slow/error, health check fails
- **Recovery**: Return cached/DB results without search ranking
- **Mitigation**: Create fallback PostgreSQL full-text search

### High Latency
- **Symptom**: Request duration >1s
- **Detection**: Prometheus histogram P95 > threshold
- **Root Causes**: 
  - DB connection pool exhausted → increase pool size
  - Slow query → add indexes, optimize
  - Large document processing → move to async queue
- **Recovery**: Scale horizontally (add FastAPI replicas)

## Interview Talking Points

**"Why service abstraction layers?"**
> "I created `PostgreSQLService`, `MinIOStorageService`, and `MeilisearchService` to decouple the application from specific implementations. This made the AWS→open-source migration straightforward—I swapped out DynamoDB for PostgreSQL by changing one class, not 50 files. It also enables testing with mocks."

**"How do you handle database connection pooling?"**
> "I use `psycopg2.pool.SimpleConnectionPool` with 1-10 connections. Without pooling, each request paid 50-100ms opening a connection. With pooling, that's amortized across requests, reducing latency by 7x. The pool blocks if all connections are in use, providing natural backpressure."

**"Explain your metrics strategy"**
> "I instrument both business metrics (contact submissions, document uploads) and infrastructure metrics (request rate, latency, DB connections). Business metrics answer 'how is the product used?'; infrastructure metrics answer 'is the system healthy?'. Prometheus scrapes `/metrics` every 10s, and Grafana visualizes trends and alerts on anomalies."

**"How do you ensure reliability?"**
> "Multiple layers: health checks detect failures, Docker restart policies recover crashed services, connection pools handle transient issues, correlation IDs trace requests through the system, and structured logging enables post-incident analysis. Every external call has timeout + retry logic."

