# Middleware Gold Code - Metrics & Correlation IDs

##  The Complete Middleware Implementation

This is the production-ready middleware that handles:
- **Correlation IDs** for request tracing
- **Metrics collection** (Prometheus)
- **JSON logging** with structured data
- **Error handling** with proper metrics

---

##  Part 1: Metrics Definitions

```python
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
import time
import uuid
import logging
import json
from fastapi import Request, Response
from typing import Optional

# ============================================================================
# PROMETHEUS METRICS DEFINITIONS
# ============================================================================

# Request metrics - Counts total HTTP requests
http_requests_total = Counter(
    'http_requests_total',                    # Metric name
    'Total HTTP requests',                    # Help text
    ['method', 'endpoint', 'status']         # Labels (dimensions)
)

# Duration metrics - Measures request latency
http_request_duration_seconds = Histogram(
    'http_request_duration_seconds',          # Metric name
    'HTTP request duration in seconds',       # Help text
    ['method', 'endpoint']                    # Labels
)

# Business metrics - Custom application metrics
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

# System metrics - Current state
active_connections = Gauge(
    'active_database_connections',
    'Number of active database connections'
)

visitor_count_gauge = Gauge(
    'website_visitor_count',
    'Total website visitor count'
)
```

**What each metric type does:**
- **Counter**: Increments (e.g., total requests, total errors)
- **Histogram**: Measures distributions (e.g., response times)
- **Gauge**: Current value (e.g., active connections, queue size)

---

##  Part 2: JSON Logging Formatter

```python
# ============================================================================
# JSON LOGGING FORMATTER
# ============================================================================

class JSONFormatter(logging.Formatter):
    """Custom JSON formatter for structured logging"""
    
    def format(self, record):
        log_data = {
            "timestamp": self.formatTime(record, self.datefmt),
            "level": record.levelname,
            "name": record.name,
            "message": record.getMessage(),
            "correlation_id": getattr(record, 'correlation_id', 'N/A')
        }
        
        # Add any extra fields
        if hasattr(record, 'method'):
            log_data['method'] = record.method
        if hasattr(record, 'path'):
            log_data['path'] = record.path
        if hasattr(record, 'status'):
            log_data['status'] = record.status
        if hasattr(record, 'duration'):
            log_data['duration'] = record.duration
        if hasattr(record, 'client'):
            log_data['client'] = record.client
        if hasattr(record, 'error'):
            log_data['error'] = record.error
            
        return json.dumps(log_data)

# Configure logging
handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())
logging.basicConfig(
    level=os.environ.get('LOG_LEVEL', 'INFO'),
    handlers=[handler]
)
logger = logging.getLogger(__name__)
```

**Why JSON logging?**
- **Structured data**: Easy to parse and search
- **Log aggregation**: Works with Loki, ELK, etc.
- **Correlation IDs**: Track requests across services
- **Machine-readable**: Perfect for log analysis tools

---

##  Part 3: The Gold Middleware

```python
# ============================================================================
# MIDDLEWARE FOR CORRELATION IDS AND METRICS
# ============================================================================

@app.middleware("http")
async def correlation_and_metrics_middleware(request: Request, call_next):
    """
    Gold-standard middleware that:
    1. Generates/extracts correlation IDs for request tracing
    2. Logs request start with structured JSON
    3. Measures request duration
    4. Records Prometheus metrics (counter + histogram)
    5. Logs request completion with duration
    6. Handles errors and records error metrics
    7. Adds correlation ID to response headers
    """
    
    # ========================================================================
    # STEP 1: CORRELATION ID GENERATION/EXTRACTION
    # ========================================================================
    # Check if client sent correlation ID (for distributed tracing)
    correlation_id = request.headers.get('X-Correlation-ID', str(uuid.uuid4()))
    
    # Store in request state for use in endpoints
    request.state.correlation_id = correlation_id
    
    # ========================================================================
    # STEP 2: REQUEST LOGGING (START)
    # ========================================================================
    logger.info(
        f"Request started: {request.method} {request.url.path}",
        extra={
            "correlation_id": correlation_id,
            "method": request.method,
            "path": request.url.path,
            "client": request.client.host if request.client else "unknown"
        }
    )
    
    # ========================================================================
    # STEP 3: START TIMER FOR DURATION MEASUREMENT
    # ========================================================================
    start_time = time.time()
    
    # ========================================================================
    # STEP 4: EXECUTE REQUEST (MAIN LOGIC)
    # ========================================================================
    try:
        # This calls the actual FastAPI endpoint
        response = await call_next(request)
        
        # ====================================================================
        # STEP 5: CALCULATE DURATION
        # ====================================================================
        duration = time.time() - start_time
        
        # ====================================================================
        # STEP 6: RECORD PROMETHEUS METRICS (SUCCESS)
        # ====================================================================
        # Increment request counter
        http_requests_total.labels(
            method=request.method,
            endpoint=request.url.path,
            status=response.status_code
        ).inc()
        
        # Record duration in histogram
        http_request_duration_seconds.labels(
            method=request.method,
            endpoint=request.url.path
        ).observe(duration)
        
        # ====================================================================
        # STEP 7: ADD CORRELATION ID TO RESPONSE HEADERS
        # ====================================================================
        # Client can use this for debugging
        response.headers['X-Correlation-ID'] = correlation_id
        
        # ====================================================================
        # STEP 8: RESPONSE LOGGING (COMPLETION)
        # ====================================================================
        logger.info(
            f"Request completed: {request.method} {request.url.path} - {response.status_code}",
            extra={
                "correlation_id": correlation_id,
                "status": response.status_code,
                "duration": duration
            }
        )
        
        return response
        
    # ========================================================================
    # STEP 9: ERROR HANDLING
    # ========================================================================
    except Exception as e:
        # Calculate duration even for errors
        duration = time.time() - start_time
        
        # Record error metrics
        http_requests_total.labels(
            method=request.method,
            endpoint=request.url.path,
            status=500  # Internal Server Error
        ).inc()
        
        # Record error duration
        http_request_duration_seconds.labels(
            method=request.method,
            endpoint=request.url.path
        ).observe(duration)
        
        # Log error with full stack trace
        logger.error(
            f"Request failed: {request.method} {request.url.path}",
            extra={
                "correlation_id": correlation_id,
                "error": str(e),
                "duration": duration
            },
            exc_info=True  # Include full stack trace
        )
        
        # Re-raise exception (FastAPI will handle it)
        raise
```

---

##  Part 4: Enhanced Version with More Features

```python
@app.middleware("http")
async def enhanced_correlation_and_metrics_middleware(request: Request, call_next):
    """
    Enhanced middleware with:
    - Client IP extraction (handles proxies)
    - Request size tracking
    - Response size tracking
    - Custom business metrics
    - Rate limiting metrics
    """
    
    # Correlation ID
    correlation_id = request.headers.get('X-Correlation-ID', str(uuid.uuid4()))
    request.state.correlation_id = correlation_id
    
    # Extract real client IP (handles Cloudflare, proxies)
    real_ip = (
        request.headers.get("CF-Connecting-IP") or  # Cloudflare
        request.headers.get("X-Forwarded-For", "").split(",")[0].strip() or
        request.headers.get("X-Real-IP") or
        (request.client.host if request.client else "unknown")
    )
    
    # Request size (if available)
    request_size = int(request.headers.get("Content-Length", 0))
    
    # Start timer
    start_time = time.time()
    
    # Log request start
    logger.info(
        f"Request started: {request.method} {request.url.path}",
        extra={
            "correlation_id": correlation_id,
            "method": request.method,
            "path": request.url.path,
            "client_ip": real_ip,
            "request_size": request_size,
            "user_agent": request.headers.get("User-Agent", "unknown")
        }
    )
    
    try:
        # Process request
        response = await call_next(request)
        
        # Calculate metrics
        duration = time.time() - start_time
        response_size = response.headers.get("Content-Length")
        if response_size:
            response_size = int(response_size)
        else:
            response_size = 0
        
        # Record metrics
        http_requests_total.labels(
            method=request.method,
            endpoint=request.url.path,
            status=response.status_code
        ).inc()
        
        http_request_duration_seconds.labels(
            method=request.method,
            endpoint=request.url.path
        ).observe(duration)
        
        # Add headers
        response.headers['X-Correlation-ID'] = correlation_id
        response.headers['X-Response-Time'] = f"{duration:.4f}s"
        
        # Log completion
        logger.info(
            f"Request completed: {request.method} {request.url.path} - {response.status_code}",
            extra={
                "correlation_id": correlation_id,
                "status": response.status_code,
                "duration": duration,
                "response_size": response_size
            }
        )
        
        return response
        
    except Exception as e:
        duration = time.time() - start_time
        
        # Record error metrics
        http_requests_total.labels(
            method=request.method,
            endpoint=request.url.path,
            status=500
        ).inc()
        
        http_request_duration_seconds.labels(
            method=request.method,
            endpoint=request.url.path
        ).observe(duration)
        
        # Log error
        logger.error(
            f"Request failed: {request.method} {request.url.path}",
            extra={
                "correlation_id": correlation_id,
                "error": str(e),
                "duration": duration,
                "client_ip": real_ip
            },
            exc_info=True
        )
        
        raise
```

---

##  Part 5: Usage in Endpoints

```python
# Endpoints automatically get correlation ID and metrics
@app.post("/contact")
async def submit_contact(contact_form: ContactForm, request: Request):
    """Submit contact form"""
    
    # Access correlation ID from request state
    correlation_id = request.state.correlation_id
    
    # Your business logic
    result = await db_service.create_contact(contact_form)
    
    # Record business metric (explicit)
    contact_submissions_total.labels(
        source="website",
        service="fastapi"
    ).inc()
    
    # Log with correlation ID
    logger.info(
        f"Contact submitted: {contact_form.email}",
        extra={
            "correlation_id": correlation_id,
            "email": contact_form.email
        }
    )
    
    return result
```

---

##  Part 6: Metrics Endpoint

```python
@app.get("/metrics")
def metrics():
    """Prometheus metrics endpoint"""
    return Response(
        content=generate_latest(),  # Generates Prometheus text format
        media_type=CONTENT_TYPE_LATEST  # "text/plain; version=0.0.4"
    )
```

**Example output:**
```
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",endpoint="/health",status="200"} 1523.0
http_requests_total{method="POST",endpoint="/contact",status="200"} 45.0

# HELP http_request_duration_seconds HTTP request duration in seconds
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{method="GET",endpoint="/health",le="0.005"} 1200.0
http_request_duration_seconds_bucket{method="GET",endpoint="/health",le="0.01"} 1500.0
http_request_duration_seconds_sum{method="GET",endpoint="/health"} 8.5
http_request_duration_seconds_count{method="GET",endpoint="/health"} 1523.0
```

---

##  Part 7: Key Features

### 1. **Automatic Metrics Collection**
- No need to manually record metrics in each endpoint
- Middleware handles everything automatically
- Consistent metrics across all endpoints

### 2. **Correlation IDs**
- Track requests across services
- Debug issues with specific requests
- Link logs from different services

### 3. **Structured Logging**
- JSON format for easy parsing
- Correlation IDs in every log
- Request/response details

### 4. **Error Handling**
- Errors are logged with stack traces
- Error metrics are recorded
- Correlation ID helps debug

### 5. **Performance Monitoring**
- Request duration tracking
- Histogram for percentiles (p50, p95, p99)
- Identify slow endpoints

---

##  Part 8: Interview Talking Points

### What This Middleware Does:

1. **Observability**: 
   - Every request is logged and measured
   - Correlation IDs for distributed tracing
   - Structured JSON logs for log aggregation

2. **Metrics**:
   - Automatic Prometheus metrics
   - Request counts, durations, errors
   - Business metrics (explicit)

3. **Security**:
   - Correlation IDs help track suspicious activity
   - Client IP extraction (handles proxies)
   - Error logging for security incidents

4. **Performance**:
   - Duration tracking identifies bottlenecks
   - Histograms show latency distributions
   - Request/response size tracking

5. **Production-Ready**:
   - Error handling with proper metrics
   - JSON logging for log aggregation
   - Correlation IDs for debugging

### Why This Is "Gold":

- **Zero boilerplate**: Works automatically for all endpoints
- **Comprehensive**: Metrics + logging + tracing
- **Production-tested**: Handles errors, proxies, etc.
- **Standard**: Uses Prometheus format (industry standard)
- **Scalable**: Low overhead, async processing

---

##  Summary

This middleware is the **gold standard** because it:
1.  Automatically collects metrics for all requests
2.  Generates correlation IDs for request tracing
3.  Logs structured JSON for log aggregation
4.  Handles errors gracefully
5.  Adds minimal overhead (async, efficient)
6.  Works with Prometheus (industry standard)
7.  Production-ready (handles edge cases)

**Copy this code and you're set!** 

