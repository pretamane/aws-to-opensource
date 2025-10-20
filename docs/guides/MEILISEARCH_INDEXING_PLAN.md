# Meilisearch Automatic Indexing Plan

## Overview
This document outlines the design and implementation plan for automatic document indexing in Meilisearch when documents are uploaded to the system.

## Current State
- **Document Upload**: Working via `/documents/upload` endpoint
- **Storage**: Documents saved to MinIO (S3-compatible storage)
- **Database**: Metadata saved to PostgreSQL
- **Search**: Meilisearch configured but requires manual indexing
- **Status**: Documents uploaded but NOT automatically indexed for search

## Problem Statement
Currently, when a document is uploaded:
1. File is saved to MinIO
2. Metadata is saved to PostgreSQL
3. **Missing**: Document content is NOT indexed in Meilisearch
4. **Result**: Uploaded documents are not searchable

## Solution: Background Indexing Job

### Architecture

```
┌─────────────────────────────────────────────────┐
│                Upload Flow                       │
├─────────────────────────────────────────────────┤
│                                                  │
│  1. User uploads document                       │
│     │                                            │
│     ▼                                            │
│  2. FastAPI receives file                       │
│     │                                            │
│     ├──> Save to MinIO                          │
│     │                                            │
│     ├──> Save metadata to PostgreSQL            │
│     │    (status: "pending_index")              │
│     │                                            │
│     └──> Trigger indexing job (async)           │
│          │                                       │
│          ▼                                       │
│  3. Background Worker                           │
│     │                                            │
│     ├──> Extract text from document             │
│     │                                            │
│     ├──> Index in Meilisearch                   │
│     │                                            │
│     └──> Update PostgreSQL                      │
│          (status: "indexed")                    │
│                                                  │
└─────────────────────────────────────────────────┘
```

### Implementation Options

#### Option 1: FastAPI Background Tasks (Recommended for MVP)

**Pros**:
- Simple implementation
- No additional services needed
- Built into FastAPI
- Good for low-to-medium volume

**Cons**:
- Tasks lost if app restarts
- Limited scalability
- No retry mechanism
- No task monitoring

**Implementation**:
```python
from fastapi import BackgroundTasks

async def index_document_background(document_id: str, file_content: bytes):
    """Background task to index document"""
    try:
        # Extract text
        text = extract_text_from_file(file_content, document_type)
        
        # Index in Meilisearch
        search_service.index_document({
            'id': document_id,
            'content': text,
            'metadata': {...}
        })
        
        # Update status
        db_service.update_document_status(document_id, 'indexed')
        
    except Exception as e:
        logger.error(f"Indexing failed: {e}")
        db_service.update_document_status(document_id, 'index_failed')

@app.post("/documents/upload")
async def upload_document(
    file: UploadFile,
    background_tasks: BackgroundTasks
):
    # ... save file and metadata ...
    
    # Queue indexing task
    background_tasks.add_task(
        index_document_background,
        document_id,
        file_content
    )
    
    return {"status": "uploaded", "indexing": "queued"}
```

#### Option 2: Celery Task Queue (Production-Ready)

**Pros**:
- Reliable task execution
- Automatic retries
- Task monitoring
- Scalable (multiple workers)
- Persistent task queue

**Cons**:
- Requires Redis/RabbitMQ
- More complex setup
- Additional service to manage

**Implementation**:
```python
# celery_app.py
from celery import Celery

celery_app = Celery(
    'document_indexer',
    broker='redis://redis:6379/0',
    backend='redis://redis:6379/0'
)

@celery_app.task(bind=True, max_retries=3)
def index_document_task(self, document_id: str):
    try:
        # Get document from DB
        doc = db_service.get_document(document_id)
        
        # Download from MinIO
        content = storage_service.download_file(doc['s3_key'])
        
        # Extract and index
        text = extract_text_from_file(content, doc['content_type'])
        search_service.index_document({...})
        
        # Update status
        db_service.update_document_status(document_id, 'indexed')
        
    except Exception as e:
        # Retry with exponential backoff
        raise self.retry(exc=e, countdown=60 * (2 ** self.request.retries))

# In FastAPI endpoint
@app.post("/documents/upload")
async def upload_document(file: UploadFile):
    # ... save file and metadata ...
    
    # Queue Celery task
    index_document_task.delay(document_id)
    
    return {"status": "uploaded", "indexing": "queued"}
```

**docker-compose.yml additions**:
```yaml
redis:
  image: redis:7-alpine
  container_name: redis
  restart: unless-stopped
  networks:
    - app-network

celery-worker:
  build:
    context: ./docker/api
    dockerfile: Dockerfile.opensource
  container_name: celery-worker
  command: celery -A celery_app worker --loglevel=info
  environment:
    - CELERY_BROKER_URL=redis://redis:6379/0
    - CELERY_RESULT_BACKEND=redis://redis:6379/0
  depends_on:
    - redis
    - postgresql
    - meilisearch
    - minio
  networks:
    - app-network
```

#### Option 3: Polling Worker (Simple Alternative)

**Pros**:
- Simple to implement
- Independent of FastAPI
- Easy to monitor
- Can run as separate container

**Cons**:
- Polling delay (not instant)
- Less efficient than event-driven
- Requires database polling

**Implementation**:
```python
# indexing_worker.py
import time
from datetime import datetime

def indexing_worker():
    """Poll for documents needing indexing"""
    while True:
        try:
            # Get pending documents
            pending_docs = db_service.get_documents_by_status('pending_index', limit=10)
            
            for doc in pending_docs:
                try:
                    # Mark as processing
                    db_service.update_document_status(doc['id'], 'indexing')
                    
                    # Download and index
                    content = storage_service.download_file(doc['s3_key'])
                    text = extract_text_from_file(content, doc['content_type'])
                    search_service.index_document({...})
                    
                    # Mark as indexed
                    db_service.update_document_status(doc['id'], 'indexed')
                    
                except Exception as e:
                    logger.error(f"Failed to index {doc['id']}: {e}")
                    db_service.update_document_status(doc['id'], 'index_failed')
            
            # Wait before next poll
            time.sleep(30)  # Poll every 30 seconds
            
        except Exception as e:
            logger.error(f"Worker error: {e}")
            time.sleep(60)

if __name__ == "__main__":
    indexing_worker()
```

**docker-compose.yml**:
```yaml
indexing-worker:
  build:
    context: ./docker/api
    dockerfile: Dockerfile.opensource
  container_name: indexing-worker
  command: python indexing_worker.py
  environment:
    - DB_HOST=postgresql
    - S3_ENDPOINT_URL=http://minio:9000
    - MEILISEARCH_URL=http://meilisearch:7700
  depends_on:
    - postgresql
    - meilisearch
    - minio
  networks:
    - app-network
  restart: unless-stopped
```

## Recommended Approach: Phased Implementation

### Phase 1: FastAPI Background Tasks (Immediate)
- **Timeline**: 2-3 hours
- **Effort**: Low
- **Risk**: Low
- **Benefit**: Documents become searchable immediately after upload

**Steps**:
1. Add `index_document_background()` function to `app_opensource.py`
2. Update `/documents/upload` endpoint to use `BackgroundTasks`
3. Add text extraction utilities
4. Test with sample documents
5. Deploy to EC2

### Phase 2: Add Retry Logic (Short-term)
- **Timeline**: 1-2 hours
- **Effort**: Low
- **Risk**: Low
- **Benefit**: Handle transient failures

**Steps**:
1. Add retry decorator to indexing function
2. Store failed documents in separate status
3. Add manual retry endpoint for admins
4. Monitor indexing success rate

### Phase 3: Polling Worker (Medium-term)
- **Timeline**: 4-6 hours
- **Effort**: Medium
- **Risk**: Low
- **Benefit**: More reliable, independent of API

**Steps**:
1. Create `indexing_worker.py` script
2. Add worker service to docker-compose
3. Implement batch processing
4. Add worker health monitoring
5. Deploy and test

### Phase 4: Celery Queue (Long-term, if needed)
- **Timeline**: 1-2 days
- **Effort**: High
- **Risk**: Medium
- **Benefit**: Production-grade task queue

**Steps**:
1. Add Redis service
2. Install Celery dependencies
3. Create Celery app and tasks
4. Add Celery worker service
5. Add Flower for monitoring
6. Migrate from background tasks
7. Deploy and test

## Text Extraction Strategy

### Supported File Types
```python
TEXT_EXTRACTORS = {
    'text/plain': extract_text_plain,
    'application/json': extract_text_json,
    'text/csv': extract_text_csv,
    'application/pdf': extract_text_pdf,  # Requires PyPDF2
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document': extract_text_docx,  # Requires python-docx
    # Add more as needed
}

def extract_text_from_file(content: bytes, content_type: str) -> str:
    """Extract searchable text from file"""
    extractor = TEXT_EXTRACTORS.get(content_type, extract_text_fallback)
    return extractor(content)
```

### Dependencies to Add
```txt
# requirements.opensource.txt additions
PyPDF2==3.0.1           # PDF text extraction
python-docx==1.1.0      # Word document extraction
openpyxl==3.1.2         # Excel extraction
python-pptx==0.6.23     # PowerPoint extraction
```

## Indexing Configuration

### Meilisearch Index Settings
```python
# Configure index for optimal search
search_service.get_index().update_settings({
    'searchableAttributes': [
        'filename',
        'content',
        'description',
        'tags'
    ],
    'filterableAttributes': [
        'contact_id',
        'document_type',
        'upload_timestamp',
        'processing_status'
    ],
    'sortableAttributes': [
        'upload_timestamp',
        'filename'
    ],
    'rankingRules': [
        'words',
        'typo',
        'proximity',
        'attribute',
        'sort',
        'exactness'
    ],
    'stopWords': ['the', 'a', 'an'],  # Add more as needed
    'synonyms': {
        'doc': ['document', 'file'],
        'img': ['image', 'picture', 'photo']
    }
})
```

## Monitoring and Observability

### Metrics to Track
```python
# Add Prometheus metrics
indexing_total = Counter('document_indexing_total', 'Total documents indexed', ['status'])
indexing_duration = Histogram('document_indexing_duration_seconds', 'Time to index document')
indexing_queue_size = Gauge('document_indexing_queue_size', 'Number of documents pending indexing')

# In indexing function
with indexing_duration.time():
    # ... indexing logic ...
    indexing_total.labels(status='success').inc()
```

### Logging
```python
logger.info(f"Indexing document {document_id}", extra={
    'document_id': document_id,
    'filename': filename,
    'size_bytes': size,
    'content_type': content_type
})
```

### Database Status Tracking
```sql
-- Document processing statuses
-- pending_index: Uploaded, waiting for indexing
-- indexing: Currently being indexed
-- indexed: Successfully indexed
-- index_failed: Indexing failed (needs retry)
-- index_skipped: Skipped (unsupported file type)
```

## Testing Plan

### Unit Tests
```python
def test_text_extraction():
    """Test text extraction from various file types"""
    assert extract_text_plain(b"Hello World") == "Hello World"
    assert extract_text_json(b'{"key": "value"}') == '{"key": "value"}'

def test_indexing_success():
    """Test successful document indexing"""
    result = index_document_background(doc_id, content)
    assert result['status'] == 'indexed'

def test_indexing_failure_retry():
    """Test retry logic on failure"""
    # Mock Meilisearch failure
    # Verify retry attempted
    pass
```

### Integration Tests
```bash
# Upload document
curl -X POST http://localhost:8000/documents/upload \
  -F "file=@test.txt" \
  -F "contact_id=test123" \
  -F "document_type=proposal"

# Wait for indexing
sleep 5

# Search for document
curl -X POST http://localhost:8000/documents/search \
  -H "Content-Type: application/json" \
  -d '{"query": "test content", "limit": 10}'

# Verify document appears in results
```

## Rollout Plan

### Step 1: Implement Background Tasks (Week 1)
- Add indexing function to app
- Update upload endpoint
- Add basic text extraction
- Deploy to EC2
- Monitor for 1 week

### Step 2: Add Monitoring (Week 2)
- Add Prometheus metrics
- Create Grafana dashboard
- Set up alerts for failed indexing
- Monitor success rate

### Step 3: Optimize (Week 3)
- Add retry logic
- Implement batch processing
- Optimize text extraction
- Add more file type support

### Step 4: Scale (Week 4+)
- Evaluate need for Celery
- If needed, implement Celery queue
- Add multiple workers
- Load test

## Success Criteria

- [ ] Documents automatically indexed within 30 seconds of upload
- [ ] 95%+ indexing success rate
- [ ] Failed documents logged and retryable
- [ ] Search returns newly uploaded documents
- [ ] Monitoring dashboard shows indexing metrics
- [ ] No impact on upload API response time
- [ ] Text extraction works for all supported file types

## Cost Impact

**Phase 1 (Background Tasks)**:
- No additional costs
- Uses existing FastAPI container resources

**Phase 3 (Polling Worker)**:
- Minimal additional RAM (~100MB)
- Minimal additional CPU (<5%)
- No new services

**Phase 4 (Celery)**:
- Redis: ~50MB RAM
- Celery worker: ~200MB RAM
- Total additional: ~250MB RAM
- Still within t3.medium capacity

## Timeline Summary

| Phase | Duration | Effort | Status |
|-------|----------|--------|--------|
| Phase 1: Background Tasks | 2-3 hours | Low | Pending |
| Phase 2: Retry Logic | 1-2 hours | Low | Pending |
| Phase 3: Polling Worker | 4-6 hours | Medium | Pending |
| Phase 4: Celery (if needed) | 1-2 days | High | Future |

## Next Steps

1. **Implement Phase 1** (Background Tasks)
   - Add indexing function
   - Update upload endpoint
   - Test locally
   - Deploy to EC2

2. **Create Monitoring Dashboard**
   - Add Prometheus metrics
   - Create Grafana panel
   - Set up alerts

3. **Document Usage**
   - Update API documentation
   - Add search examples
   - Document supported file types

4. **User Testing**
   - Upload test documents
   - Verify search works
   - Collect feedback

## References

- FastAPI Background Tasks: https://fastapi.tiangolo.com/tutorial/background-tasks/
- Meilisearch Python SDK: https://github.com/meilisearch/meilisearch-python
- Celery Documentation: https://docs.celeryq.dev/
- Text Extraction Libraries:
  - PyPDF2: https://pypdf2.readthedocs.io/
  - python-docx: https://python-docx.readthedocs.io/
  - openpyxl: https://openpyxl.readthedocs.io/

