# Open-Source Stack FastAPI Application
# Replaces AWS services with open-source alternatives:
# - DynamoDB → PostgreSQL
# - OpenSearch → Meilisearch
# - S3/EFS → MinIO + Local Storage
# - CloudWatch → Prometheus + Loki

from fastapi import FastAPI, Request, Response, HTTPException, UploadFile, File, Form, BackgroundTasks
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
import os
import logging
from datetime import datetime
from typing import Optional
import time

# Import services for open-source stack
from shared.database_service_postgres import PostgreSQLService
from shared.search_service_meilisearch import MeilisearchService
from shared.storage_service_minio import MinIOStorageService
from shared.email_service import EmailService

# Import models
from models.contact import ContactForm, ContactResponse
from models.document import DocumentUpload, DocumentResponse, SearchRequest, SearchResponse
from models.response import HealthResponse, AnalyticsResponse, StatsResponse

# Configure logging
logging.basicConfig(
    level=os.environ.get('LOG_LEVEL', 'INFO'),
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s'
)
logger = logging.getLogger(__name__)

# ============================================================================
# PROMETHEUS METRICS
# ============================================================================

# Request metrics
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

# Business metrics
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

# System metrics
active_connections = Gauge(
    'active_database_connections',
    'Number of active database connections'
)

visitor_count_gauge = Gauge(
    'website_visitor_count',
    'Total website visitor count'
)

# ============================================================================
# INITIALIZE FASTAPI APP
# ============================================================================

app = FastAPI(
    title="Cloud-Native Document Management Platform - Open Source Edition",
    description="Enterprise document processing with PostgreSQL, Meilisearch, and MinIO",
    version="4.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=[os.environ.get('ALLOWED_ORIGIN', '*')],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization"],
)

# Global service instances
db_service = None
search_service = None
storage_service = None
email_service = None

# ============================================================================
# MIDDLEWARE FOR METRICS
# ============================================================================

@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    """Collect metrics for each request"""
    start_time = time.time()
    
    response = await call_next(request)
    
    # Record metrics
    duration = time.time() - start_time
    http_requests_total.labels(
        method=request.method,
        endpoint=request.url.path,
        status=response.status_code
    ).inc()
    
    http_request_duration_seconds.labels(
        method=request.method,
        endpoint=request.url.path
    ).observe(duration)
    
    return response

# ============================================================================
# STARTUP AND SHUTDOWN
# ============================================================================

@app.on_event("startup")
async def startup_event():
    """Initialize services on startup"""
    global db_service, search_service, storage_service, email_service
    
    logger.info("Starting Open-Source Stack Application...")
    logger.info(f"Database: PostgreSQL")
    logger.info(f"Search: Meilisearch")
    logger.info(f"Storage: MinIO (S3-compatible)")
    logger.info(f"Email: AWS SES")
    
    try:
        # Initialize PostgreSQL service
        db_service = PostgreSQLService()
        logger.info("PostgreSQL service initialized")
        
        # Initialize Meilisearch service
        search_service = MeilisearchService()
        logger.info("Meilisearch service initialized")
        
        # Initialize MinIO storage service
        storage_service = MinIOStorageService()
        logger.info("MinIO storage service initialized")
        
        # Initialize email service (AWS SES - kept for cost efficiency)
        import boto3
        ses_client = boto3.client('ses', region_name=os.environ.get('AWS_REGION', 'ap-southeast-1'))
        email_service = EmailService(ses_client)
        logger.info("Email service (SES) initialized")
        
        logger.info("Application startup complete!")
        
    except Exception as e:
        logger.error(f"Error during startup: {str(e)}")
        raise

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    logger.info("Shutting down application...")
    
    if db_service:
        db_service.close()
        logger.info("Database connections closed")
    
    logger.info("Application shutdown complete!")

# ============================================================================
# HEALTH AND INFO ENDPOINTS
# ============================================================================

@app.get("/")
def read_root():
    """Root endpoint with API information"""
    return {
        "message": "Cloud-Native Document Management Platform - Open Source Edition",
        "version": "4.0.0",
        "architecture": "EC2 + Docker Compose",
        "stack": {
            "database": "PostgreSQL 16",
            "search": "Meilisearch",
            "storage": "MinIO (S3-compatible)",
            "proxy": "Caddy",
            "monitoring": "Prometheus + Grafana",
            "logging": "Loki + Promtail",
            "email": "AWS SES"
        },
        "features": [
            "Contact form processing",
            "Document upload (17 file types)",
            "Full-text search with Meilisearch",
            "Real-time analytics",
            "Prometheus metrics",
            "Structured logging",
            "S3-compatible storage"
        ],
        "cost_optimization": "90% cost reduction vs AWS EKS",
        "endpoints": {
            "api_docs": "/docs",
            "health": "/health",
            "metrics": "/metrics",
            "contact": "/contact",
            "documents": "/documents/*",
            "search": "/documents/search",
            "analytics": "/analytics/insights"
        }
    }

@app.get("/health")
def health_check():
    """Comprehensive health check"""
    try:
        health_status = {
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat() + 'Z',
            "version": "4.0.0",
            "services": {}
        }
        
        # Check PostgreSQL
        try:
            visitor_count = db_service.get_visitor_count()
            health_status["services"]["postgresql"] = "connected"
            health_status["visitor_count"] = visitor_count
            visitor_count_gauge.set(visitor_count)
        except Exception as e:
            health_status["services"]["postgresql"] = f"error: {str(e)}"
        
        # Check Meilisearch
        try:
            stats = search_service.get_index_stats()
            health_status["services"]["meilisearch"] = "connected"
            health_status["search_stats"] = stats
        except Exception as e:
            health_status["services"]["meilisearch"] = f"error: {str(e)}"
        
        # Check MinIO
        try:
            bucket_exists = storage_service.bucket_exists(storage_service.data_bucket)
            health_status["services"]["minio"] = "connected" if bucket_exists else "bucket_missing"
        except Exception as e:
            health_status["services"]["minio"] = f"error: {str(e)}"
        
        # Check SES
        try:
            import boto3
            ses = boto3.client('ses', region_name=os.environ.get('AWS_REGION', 'ap-southeast-1'))
            ses.get_send_quota()
            health_status["services"]["ses"] = "connected"
        except Exception as e:
            health_status["services"]["ses"] = f"error: {str(e)}"
        
        return health_status
        
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        raise HTTPException(
            status_code=503,
            detail={
                "status": "unhealthy",
                "error": str(e),
                "timestamp": datetime.utcnow().isoformat() + 'Z'
            }
        )

@app.get("/metrics")
def metrics():
    """Prometheus metrics endpoint"""
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

# ============================================================================
# CONTACT FORM ENDPOINTS
# ============================================================================

@app.post("/contact", response_model=ContactResponse)
async def submit_contact(contact_form: ContactForm):
    """Submit contact form"""
    start_time = time.time()
    
    try:
        # Create contact record
        import uuid
        contact_id = f"contact_{int(time.time())}_{str(uuid.uuid4())[:8]}"
        timestamp = datetime.utcnow().isoformat() + 'Z'
        
        contact_data = {
            'id': contact_id,
            'name': contact_form.name,
            'email': contact_form.email,
            'company': contact_form.company or 'Not specified',
            'service': contact_form.service or 'Not specified',
            'budget': contact_form.budget or 'Not specified',
            'message': contact_form.message,
            'timestamp': timestamp,
            'status': 'new',
            'source': contact_form.source or 'website',
            'userAgent': contact_form.userAgent or '',
            'pageUrl': contact_form.pageUrl or ''
        }
        
        # Save to PostgreSQL
        db_service.create_contact_record(contact_data)
        
        # Update visitor count
        visitor_count = db_service.update_visitor_count()
        
        # Get document count
        documents = db_service.get_contact_documents(contact_id)
        documents_count = len(documents)
        
        # Send email notification
        try:
            email_service.send_contact_notification(
                contact_form.name, contact_form.email,
                contact_data['company'], contact_data['service'],
                contact_data['budget'], contact_form.message,
                timestamp, contact_data['source'],
                contact_data['userAgent'], contact_data['pageUrl'],
                documents_count
            )
        except Exception as e:
            logger.warning(f"Email notification failed: {str(e)}")
        
        # Record metrics
        contact_submissions_total.labels(
            source=contact_data['source'],
            service=contact_data['service']
        ).inc()
        
        # Record processing time
        duration = time.time() - start_time
        logger.info(f"Contact submission processed in {duration:.2f}s")
        
        return ContactResponse(
            message='Contact form submitted successfully!',
            contactId=contact_id,
            timestamp=timestamp,
            visitor_count=visitor_count,
            documents_count=documents_count
        )
        
    except Exception as e:
        logger.error(f"Error processing contact submission: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Internal Error: {str(e)}"
        )

# ============================================================================
# DOCUMENT ENDPOINTS
# ============================================================================

@app.post("/documents/upload", response_model=DocumentResponse)
async def upload_document(
    file: UploadFile = File(...),
    contact_id: str = Form(...),
    document_type: str = Form(...),
    description: Optional[str] = Form(None),
    tags: Optional[str] = Form("")
):
    """Upload and process documents"""
    try:
        # Read file
        content = await file.read()
        
        # Generate document ID
        import uuid
        document_id = str(uuid.uuid4())
        timestamp = datetime.utcnow().isoformat() + 'Z'
        
        # Upload to MinIO
        s3_key = f"documents/{contact_id}/{document_id}_{file.filename}"
        storage_service.upload_file(
            file_content=content,
            key=s3_key,
            content_type=file.content_type,
            metadata={
                'contact_id': contact_id,
                'document_type': document_type,
                'upload_timestamp': timestamp
            }
        )
        
        # Save metadata to PostgreSQL
        document_data = {
            'id': document_id,
            'contact_id': contact_id,
            'filename': file.filename,
            'size': len(content),
            'content_type': file.content_type or 'application/octet-stream',
            'document_type': document_type,
            'description': description or '',
            'tags': tags.split(',') if tags else [],
            'upload_timestamp': timestamp,
            'processing_status': 'pending',
            's3_bucket': storage_service.data_bucket,
            's3_key': s3_key
        }
        
        db_service.create_document_record(document_data)
        
        # Record metrics
        document_uploads_total.labels(
            document_type=document_type,
            status='success'
        ).inc()
        
        logger.info(f"Document uploaded: {document_id}")
        
        return DocumentResponse(
            document_id=document_id,
            filename=file.filename,
            size=len(content),
            content_type=file.content_type or 'application/octet-stream',
            upload_timestamp=timestamp,
            processing_status='pending',
            contact_id=contact_id,
            s3_path=f"s3://{storage_service.data_bucket}/{s3_key}"
        )
        
    except Exception as e:
        logger.error(f"Error uploading document: {str(e)}")
        document_uploads_total.labels(
            document_type=document_type,
            status='error'
        ).inc()
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/documents/search", response_model=SearchResponse)
async def search_documents(search_request: SearchRequest):
    """Search documents using Meilisearch"""
    try:
        document_search_queries_total.inc()
        
        start_time = time.time()
        
        # Search with Meilisearch
        results = search_service.search_documents(
            query=search_request.query,
            filters=search_request.filters,
            limit=search_request.limit
        )
        
        processing_time = time.time() - start_time
        
        return SearchResponse(
            results=results['results'],
            total_count=results['total_count'],
            query=search_request.query,
            processing_time=processing_time
        )
        
    except Exception as e:
        logger.error(f"Error searching documents: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/contacts/{contact_id}/documents")
async def get_contact_documents(contact_id: str):
    """Get all documents for a contact"""
    try:
        documents = db_service.get_contact_documents(contact_id)
        
        return {
            'contact_id': contact_id,
            'documents': documents,
            'total_count': len(documents)
        }
        
    except Exception as e:
        logger.error(f"Error getting contact documents: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# ============================================================================
# ANALYTICS ENDPOINTS
# ============================================================================

@app.get("/analytics/insights", response_model=AnalyticsResponse)
async def get_analytics():
    """Get system analytics and insights"""
    try:
        analytics_data = db_service.get_analytics_data()
        return AnalyticsResponse(**analytics_data)
        
    except Exception as e:
        logger.error(f"Error getting analytics: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/stats", response_model=StatsResponse)
async def get_stats():
    """Get visitor statistics"""
    try:
        visitor_count = db_service.get_visitor_count()
        
        return StatsResponse(
            visitor_count=visitor_count,
            timestamp=datetime.utcnow().isoformat() + 'Z',
            enhanced_features=True
        )
        
    except Exception as e:
        logger.error(f"Error getting stats: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# ============================================================================
# ADMIN ENDPOINTS
# ============================================================================

@app.get("/admin/system-info")
async def get_system_info():
    """Get system information and resource usage"""
    try:
        return {
            "version": "4.0.0",
            "architecture": "opensource",
            "services": {
                "database": "PostgreSQL 16",
                "search": "Meilisearch",
                "storage": "MinIO",
                "monitoring": "Prometheus + Grafana",
                "logging": "Loki + Promtail"
            },
            "storage_stats": {
                "data_bucket": storage_service.get_bucket_size(storage_service.data_bucket),
                "backup_bucket": storage_service.get_bucket_size(storage_service.backup_bucket)
            },
            "search_stats": search_service.get_index_stats(),
            "timestamp": datetime.utcnow().isoformat() + 'Z'
        }
        
    except Exception as e:
        logger.error(f"Error getting system info: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# ============================================================================
# CORS PREFLIGHT
# ============================================================================

@app.options("/contact")
async def contact_options():
    """Handle CORS preflight for contact endpoint"""
    return Response(
        status_code=200,
        headers={
            "Access-Control-Allow-Origin": os.environ.get('ALLOWED_ORIGIN', '*'),
            "Access-Control-Allow-Methods": "POST, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type, Authorization"
        }
    )

# ============================================================================
# ERROR HANDLERS
# ============================================================================

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """Handle HTTP exceptions"""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": exc.detail,
            "timestamp": datetime.utcnow().isoformat() + 'Z'
        }
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)


