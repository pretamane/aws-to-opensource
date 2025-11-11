# Search Engine: Meilisearch

## Role & Responsibilities
Fast, typo-tolerant full-text search replacing AWS OpenSearch for document discovery and content queries.

## Why Meilisearch Over OpenSearch

| Aspect | AWS OpenSearch | Meilisearch | Decision |
|--------|----------------|-------------|----------|
| **Cost** | $60/month (small cluster) | Self-hosted ($0) | Meilisearch (cost) |
| **Setup** | Complex (shards, replicas) | Simple (single binary) | Meilisearch (ease) |
| **Search Speed** | <100ms | <20ms | Meilisearch (speed) |
| **Typo Tolerance** | Basic | Excellent (Levenshtein) | Meilisearch (UX) |
| **Relevance** | Manual tuning | Smart defaults | Meilisearch (OOTB) |
| **Scale** | Billions of docs | Millions of docs | OpenSearch for huge scale |

**Interview Answer**: "We chose Meilisearch for cost savings, sub-20ms search speed, and excellent typo tolerance out of the box. Our workload (<100K docs) fits well in Meilisearch's sweet spot. For billions of documents, I'd revisit OpenSearch or Elasticsearch."

## Architecture

### Service Location
- Container: `meilisearch`
- Port: 7700
- UI: http://localhost:8080/meilisearch/ (via Caddy)
- Config: `docker-compose/docker-compose.yml`
- Service Code: `docker/api/shared/search_service_meilisearch.py`

### Index Structure
```
meilisearch:7700/
  └─ documents (index)
       ├─ Searchable Attributes:
       │    ├─ filename
       │    ├─ text_content
       │    ├─ content
       │    ├─ document_type
       │    ├─ keywords
       │    └─ description
       ├─ Filterable Attributes:
       │    ├─ contact_id
       │    ├─ document_type
       │    ├─ processing_status
       │    ├─ upload_timestamp
       │    └─ file_extension
       └─ Sortable Attributes:
            ├─ upload_timestamp
            ├─ processing_timestamp
            └─ complexity_score
```

## Client Initialization

### Python SDK
```python
import meilisearch

self.client = meilisearch.Client(
    'http://meilisearch:7700',
    'master_key_here'
)
self.index_name = 'documents'
self._index = None

def get_index(self):
    """Get or create Meilisearch index"""
    if self._index is None:
        try:
            self._index = self.client.get_index(self.index_name)
        except Exception:
            self.create_index()
    return self._index
```

## Index Configuration

### Creating Index with Settings
```python
def create_index(self) -> bool:
    # Create index
    task = self.client.create_index('documents', {'primaryKey': 'id'})
    self.client.wait_for_task(task['taskUid'])
    
    self._index = self.client.get_index('documents')
    
    # Configure searchable attributes (what fields to search)
    self._index.update_searchable_attributes([
        'filename',
        'text_content',
        'content',
        'document_type',
        'keywords',
        'description'
    ])
    
    # Configure filterable attributes (what fields to filter on)
    self._index.update_filterable_attributes([
        'contact_id',
        'document_type',
        'processing_status',
        'upload_timestamp',
        'file_extension'
    ])
    
    # Configure sortable attributes
    self._index.update_sortable_attributes([
        'upload_timestamp',
        'processing_timestamp',
        'complexity_score'
    ])
    
    # Configure ranking rules (order matters!)
    self._index.update_ranking_rules([
        'words',      # Matches all query words
        'typo',       # Fewer typos = higher rank
        'proximity',  # Words closer together = higher rank
        'attribute',  # Matches in title > body
        'sort',       # Sort order
        'exactness'   # Exact matches = highest rank
    ])
    
    return True
```

### Why Configuration Matters
- **Searchable**: Only these fields contribute to search scoring
- **Filterable**: Enables `filter=contact_id:123` syntax
- **Sortable**: Allows `sort=upload_timestamp:desc`
- **Ranking**: Controls result ordering (typo vs proximity vs exactness)

## Indexing Documents

### Add Document to Index
```python
def index_document(self, document: Dict[str, Any]) -> bool:
    index = self.get_index()
    
    # Flatten nested structures for better searching
    meili_document = {
        'id': document['id'],
        'contact_id': document['contact_id'],
        'filename': document['filename'],
        'document_type': document['document_type'],
        'text_content': document.get('text_content', ''),
        'upload_timestamp': document['upload_timestamp'],
        
        # Flatten metadata
        'word_count': document.get('metadata', {}).get('word_count', 0),
        'file_extension': document.get('metadata', {}).get('file_extension', ''),
        'language_detected': document.get('metadata', {}).get('language_detected', 'en'),
        'keywords': document.get('metadata', {}).get('keywords', []),
        
        # Processing info
        'processing_status': document.get('processing_info', {}).get('status', 'unknown'),
        'complexity_score': document.get('processing_info', {}).get('complexity_score', 0.0),
        
        # S3 metadata
        's3_key': document.get('s3_metadata', {}).get('key', ''),
        'size': document.get('s3_metadata', {}).get('size', 0),
    }
    
    # Add document (async)
    task = index.add_documents([meili_document])
    self.client.wait_for_task(task['taskUid'])
    
    return True
```

**Key Point**: Flatten nested structures; Meilisearch searches better on flat fields.

## Searching Documents

### Basic Search
```python
results = index.search('contract')

# Returns:
{
  "hits": [
    {
      "id": "doc-123",
      "filename": "contract.pdf",
      "text_content": "This is a contract for...",
      "_formatted": {  # Highlighted results
        "filename": "<em>contract</em>.pdf"
      }
    }
  ],
  "estimatedTotalHits": 42,
  "processingTimeMs": 12,
  "query": "contract"
}
```

### Advanced Search with Filters
```python
results = index.search(
    'machine learning',
    {
        'filter': 'contact_id = "contact-123" AND document_type = "pdf"',
        'attributesToRetrieve': ['id', 'filename', 'text_content'],
        'attributesToHighlight': ['filename', 'text_content'],
        'sort': ['upload_timestamp:desc'],
        'limit': 20
    }
)
```

### Typo Tolerance in Action
```python
# User types with typo
results = index.search('machne lerning')  # Missing 'i', wrong 'ea'

# Meilisearch still finds:
# - "machine learning"
# - "machine-learning"
# - "Machine Learning"
```

**How It Works**: Levenshtein distance algorithm allows up to 2 typos depending on word length.

### Filter Syntax
```python
# Single filter
filter='contact_id = "contact-123"'

# Multiple filters (AND)
filter='contact_id = "contact-123" AND document_type = "pdf"'

# OR condition
filter='document_type = "pdf" OR document_type = "docx"'

# Range
filter='upload_timestamp > 1672531200'  # Unix timestamp

# Array contains
filter='keywords IN ["contract", "legal"]'
```

## Search Service Implementation

### Python Service Wrapper
```python
def search_documents(self, query: str, filters: Optional[Dict] = None, limit: int = 10) -> Dict[str, Any]:
    index = self.get_index()
    
    # Build search options
    search_options = {
        'limit': limit,
        'attributesToRetrieve': [
            'id', 'contact_id', 'filename', 'document_type',
            'text_content', 'upload_timestamp', 'processing_status'
        ],
        'attributesToHighlight': ['filename', 'text_content'],
        'sort': ['upload_timestamp:desc']
    }
    
    # Add filters if provided
    if filters:
        filter_clauses = []
        for key, value in filters.items():
            if isinstance(value, str):
                filter_clauses.append(f'{key} = "{value}"')
            else:
                filter_clauses.append(f'{key} = {value}')
        
        if filter_clauses:
            search_options['filter'] = ' AND '.join(filter_clauses)
    
    # Execute search
    start_time = datetime.utcnow()
    results = index.search(query, search_options)
    processing_time = (datetime.utcnow() - start_time).total_seconds()
    
    return {
        'results': results['hits'],
        'total_count': results['estimatedTotalHits'],
        'query': query,
        'processing_time': processing_time
    }
```

## Performance Characteristics

### Search Speed
- **Typical**: 10-20ms for <100K documents
- **Complex Query**: 30-50ms with filters and sorting
- **Typo Tolerance**: Minimal overhead (<5ms)

### Index Size
- **Documents**: 100MB text = ~20MB index
- **Compression**: Automatic via FST (Finite State Transducer)
- **Memory**: ~1GB for 1M small documents

### Throughput
- **Single Instance**: ~1K queries/sec
- **Indexing**: ~10K docs/sec (batched)

## Failure Modes & Recovery

### Index Doesn't Exist
- **Symptom**: Search returns error "Index not found"
- **Detection**: Application logs show index errors
- **Recovery**: Auto-create index with configuration
- **Mitigation**: Ensure index exists on app startup

### Search Returns Empty Results
- **Symptom**: Known documents not found
- **Detection**: Verify document in Meilisearch UI
- **Root Causes**:
  - Document not indexed → check indexing logs
  - Wrong searchable attributes → reconfigure index
  - Typo too far off → adjust typo tolerance settings
- **Recovery**: Re-index documents

### High Search Latency
- **Symptom**: Search takes >100ms
- **Detection**: Prometheus P95 latency metric
- **Root Causes**:
  - Too many documents → add replica for load balancing
  - Complex filters → optimize filter attributes
  - Large result set → reduce limit, paginate
- **Recovery**: Scale horizontally (multiple instances)

### Out of Memory
- **Symptom**: Meilisearch crashes
- **Detection**: Docker logs show OOM errors
- **Root Causes**:
  - Index too large → increase memory limit
  - Too many concurrent searches → add rate limiting
- **Recovery**: Restart with more memory, reduce index size

## Production Improvements

1. **Replicas**: Multiple instances behind load balancer
2. **API Keys**: Separate keys for admin, search, and index
3. **Snapshots**: Regular index backups for disaster recovery
4. **Monitoring**: Export metrics to Prometheus
5. **Rate Limiting**: Prevent abuse of search API
6. **Synonyms**: Configure domain-specific synonyms
7. **Stop Words**: Remove common words from indexing

## Interview Talking Points

**"Why Meilisearch over OpenSearch?"**
> "Cost, speed, and ease of use. Meilisearch delivers <20ms search with excellent typo tolerance out of the box, while OpenSearch costs $60/month and requires complex shard/replica configuration. Our workload (<100K docs) fits Meilisearch's sweet spot. For billions of documents, I'd revisit OpenSearch."

**"How does typo tolerance work?"**
> "Meilisearch uses Levenshtein distance to allow 1-2 typos depending on word length. It's built into the ranking algorithm, so 'machne lerning' automatically matches 'machine learning' with slightly lower score than exact match. This dramatically improves search UX without manual configuration."

**"Explain your indexing strategy"**
> "I flatten nested document structures into Meilisearch-friendly fields, configure searchable/filterable/sortable attributes explicitly, and batch document additions for efficiency. The ranking rules prioritize exact matches, then low-typo matches, then proximity. This gives great relevance without manual tuning."

**"What's the search performance?"**
> "Typical search: 10-20ms for our index size. This is 5x faster than our previous OpenSearch setup. Meilisearch uses an FST (Finite State Transducer) for compression and fast lookups. For our traffic (<100 searches/sec), a single instance is plenty. For scale, I'd add replicas behind a load balancer."

**"How would you handle search failures?"**
> "Multiple layers: if Meilisearch is down, fall back to PostgreSQL full-text search (slower but functional). If search returns empty, verify document was indexed and check logs. For production, I'd add health checks, Prometheus alerts on high latency, and auto-restart on crashes."

