# Database Layer: PostgreSQL

## Role & Responsibilities
Relational database storing contacts, documents, analytics, and visitor counters with ACID guarantees, JSONB flexibility, and PL/pgSQL functions.

## Migration Context: DynamoDB → PostgreSQL

### Why PostgreSQL Over DynamoDB

| Aspect | DynamoDB | PostgreSQL | Decision |
|--------|----------|------------|----------|
| **Cost** | $1.25/million writes | Fixed instance cost | PostgreSQL (predictable) |
| **Consistency** | Eventually consistent | ACID transactions | PostgreSQL (audit/banking) |
| **Queries** | Key-value only, no joins | Complex SQL, aggregations | PostgreSQL (analytics) |
| **Relationships** | Denormalized, no FK | Foreign keys, constraints | PostgreSQL (data integrity) |
| **Scaling** | Auto to millions ops/sec | Vertical + read replicas | DynamoDB for massive scale |

**Interview Answer**: "We chose PostgreSQL because we value strong consistency, complex queries, and predictable costs over DynamoDB's unlimited scale. Our workload is <1K ops/sec where PostgreSQL excels. For 100K+ ops/sec, I'd revisit DynamoDB."

## Schema Design: Hybrid Approach

### Best of Both Worlds
```sql
CREATE TABLE contact_submissions (
    -- Structured columns (fast indexing, type safety, constraints)
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    company VARCHAR(255),
    service VARCHAR(255),
    budget VARCHAR(255),
    message TEXT NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    status VARCHAR(50) DEFAULT 'new',
    
    -- Flexible metadata (schema evolution without migrations)
    document_insights JSONB DEFAULT '{}',
    
    -- Audit trail
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- GIN index for fast JSONB queries
CREATE INDEX idx_contact_insights ON contact_submissions 
USING GIN(document_insights);

-- B-tree indexes for frequent lookups
CREATE INDEX idx_contact_email ON contact_submissions(email);
CREATE INDEX idx_contact_timestamp ON contact_submissions(timestamp DESC);
CREATE INDEX idx_contact_status ON contact_submissions(status);
```

### Design Principles
1. **Core fields as columns** → benefit from type checking, constraints, standard indexes
2. **Variable metadata as JSONB** → evolve schema without ALTER TABLE
3. **Separate created/updated timestamps** → immutable audit trail

## JSONB + GIN Indexes

### The Power of JSONB
```sql
-- Store flexible metadata
UPDATE contact_submissions 
SET document_insights = jsonb_build_object(
    'total_documents', 5,
    'document_types', jsonb_build_array('pdf', 'docx'),
    'content_analysis', jsonb_build_object(
        'has_business_content', true,
        'confidence_level', 'high',
        'primary_language', 'en'
    )
)
WHERE id = 'contact-123';
```

### Fast JSONB Queries
```sql
-- Find contacts with business content
SELECT * FROM contact_submissions
WHERE document_insights->>'has_business_content' = 'true';

-- Find contacts who uploaded PDFs
SELECT * FROM contact_submissions
WHERE document_insights->'document_types' @> '["pdf"]';

-- Find contacts with high confidence
SELECT * FROM contact_submissions
WHERE document_insights->'content_analysis'->>'confidence_level' = 'high';

-- Complex nested query
SELECT 
    name,
    email,
    (document_insights->'content_analysis'->>'confidence_level') as confidence
FROM contact_submissions
WHERE (document_insights->>'total_documents')::int > 3
ORDER BY timestamp DESC;
```

**GIN Index Magic**: Indexes JSON keys and values, making these queries as fast as regular column lookups (~10ms).

## Connection Pooling

### Implementation
```python
from psycopg2.pool import SimpleConnectionPool

self.pool = SimpleConnectionPool(
    minconn=1,     # Keep 1 connection always open
    maxconn=10,    # Max 10 concurrent connections
    host='postgresql',
    port=5432,
    database='pretamane_db',
    user='pretamane',
    password='...'
)

def get_connection(self):
    return self.pool.getconn()

def return_connection(self, conn):
    self.pool.putconn(conn)
```

### Performance Impact

**Without Pool** (every request):
```
1. Open TCP connection      50ms
2. SSL handshake           20ms
3. Authenticate            10ms
4. Execute query           10ms
5. Close connection         5ms
Total: 95ms (85ms wasted!)
```

**With Pool**:
```
1. Get connection from pool  <1ms
2. Execute query            10ms
3. Return to pool           <1ms
Total: 11ms (8.6x faster!)
```

### Pool Sizing Formula
```
maxconn = (CPU cores × 2) + disk spindles
Example: 4 cores + 1 SSD = 10 connections

Rationale:
- CPU-bound: 2× cores (context switching overhead)
- I/O-bound: Add disk parallelism
- PostgreSQL excels at <200 connections per instance
```

**Interview Point**: "Connection pools are critical for performance. Opening connections is expensive (50-100ms). Pooling amortizes that cost across requests, reducing latency by 80%+."

## PL/pgSQL Functions & Triggers

### Atomic Counter (Visitor Count)
```sql
CREATE TABLE website_visitors (
    id VARCHAR(255) PRIMARY KEY,
    count INTEGER DEFAULT 0,
    last_updated TIMESTAMPTZ DEFAULT NOW()
);

-- Atomic increment function
CREATE FUNCTION increment_visitor_count()
RETURNS INTEGER AS $$
DECLARE
    new_count INTEGER;
BEGIN
    UPDATE website_visitors 
    SET count = count + 1, 
        last_updated = NOW()
    WHERE id = 'visitor_count'
    RETURNING count INTO new_count;
    
    IF NOT FOUND THEN
        INSERT INTO website_visitors (id, count, last_updated)
        VALUES ('visitor_count', 1, NOW())
        RETURNING count INTO new_count;
    END IF;
    
    RETURN new_count;
END;
$$ LANGUAGE plpgsql;
```

**Usage**:
```python
cur.execute("SELECT increment_visitor_count()")
visitor_count = cur.fetchone()[0]
```

**Why This Works**:
- Row-level locking prevents race conditions
- Atomic: increment + timestamp update in one transaction
- Returns new value like DynamoDB's `RETURN_VALUES`

### Automatic Timestamp Updates
```sql
CREATE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

CREATE TRIGGER update_contact_submissions_updated_at
BEFORE UPDATE ON contact_submissions
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();
```

**Benefit**: Application code never forgets to update timestamps—it's guaranteed by the database.

## Initialization Flow

### Docker Compose Startup
```yaml
postgresql:
  image: postgres:16-alpine
  volumes:
    - postgres-data:/var/lib/postgresql/data
    - ./init-scripts/postgres:/docker-entrypoint-initdb.d:z
  command:
    - "postgres"
    - "-c" "max_connections=200"
    - "-c" "shared_buffers=256MB"
    - "-c" "effective_cache_size=1GB"
    - "-c" "work_mem=16MB"
```

### Init Scripts
```
/docker-entrypoint-initdb.d/
  ├─ 01-init-schema.sql
  │    ├─ CREATE TABLES
  │    ├─ CREATE INDEXES
  │    ├─ CREATE FUNCTIONS
  │    └─ CREATE TRIGGERS
  └─ 02-seed-data.sql
       └─ INSERT sample data
```

**Key Point**: Scripts run ONLY on first boot (when data volume is empty). Re-running `docker-compose up` doesn't re-execute them.

## Real Troubleshooting: Password Escaping

### Problem
API couldn't connect to DB: `authentication failed`

### Debugging
```bash
# Test connection manually
docker exec -it postgresql psql -U pretamane -d pretamane_db
# Works! ← Password correct

# Check environment in container
docker exec fastapi-app env | grep DB_PASSWORD
DB_PASSWORD=#ThawZin2k77!  ← Shell interprets # as comment!

# What actually gets set
DB_PASSWORD=  # Empty string!
```

### Root Cause
Special characters in password not escaped in `.env` file.

### Fix
```bash
# .env
DB_PASSWORD='#ThawZin2k77!'  # Quote in .env
# OR
DB_PASSWORD=\#ThawZin2k77\!   # Escape special chars
```

**Interview Takeaway**: "When authentication fails but credentials work in psql, check environment variable escaping. Special chars like #, $, ! need quotes in .env files."

## Query Optimization

### Document Lookup with Joins
```sql
-- Get contact with all documents
SELECT 
    c.id,
    c.name,
    c.email,
    json_agg(json_build_object(
        'id', d.id,
        'filename', d.filename,
        'size', d.size,
        'status', d.processing_status
    )) as documents
FROM contact_submissions c
LEFT JOIN documents d ON d.contact_id = c.id
WHERE c.id = $1
GROUP BY c.id, c.name, c.email;
```

### Analytics Aggregations
```sql
-- Contact submissions by service
SELECT 
    service,
    COUNT(*) as count,
    AVG((document_insights->>'total_documents')::int) as avg_docs
FROM contact_submissions
WHERE timestamp > NOW() - INTERVAL '30 days'
GROUP BY service
ORDER BY count DESC;

-- Document processing status breakdown
SELECT 
    processing_status,
    COUNT(*) as count,
    AVG(size)::int as avg_size_bytes
FROM documents
GROUP BY processing_status;
```

## Failure Modes & Recovery

### Connection Pool Exhausted
- **Symptom**: Requests hang, eventually timeout
- **Detection**: Prometheus metric `active_database_connections` == 10/10
- **Root Cause**: Slow queries holding connections, or high concurrent load
- **Fix**: Increase pool size, optimize slow queries, add read replica

### Disk Full
- **Symptom**: INSERT/UPDATE fails with "disk full" error
- **Detection**: Prometheus `node_filesystem_avail_bytes` < threshold
- **Recovery**: Delete old data, increase volume size, enable log rotation
- **Mitigation**: Set up disk usage alerts, automate cleanup

### Slow Queries
- **Symptom**: High request latency
- **Detection**: Prometheus P95 latency > 1s, Loki shows slow query logs
- **Debugging**: 
  ```sql
  -- Enable slow query logging
  SET log_min_duration_statement = 1000;  -- Log queries >1s
  
  -- Analyze query plan
  EXPLAIN ANALYZE SELECT ...;
  ```
- **Fix**: Add indexes, rewrite query, increase `work_mem`

## Production Improvements

1. **Replication**: Set up streaming replication for HA
   ```sql
   -- On primary
   CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD '...';
   
   -- On replica
   pg_basebackup -h primary -D /var/lib/postgresql/data -U replicator -P
   ```

2. **Backups**: Automated `pg_dump` to S3/MinIO every 6 hours
   ```bash
   pg_dump -h postgresql -U pretamane pretamane_db | \
   gzip | \
   aws s3 cp - s3://backups/postgres/dump-$(date +%Y%m%d-%H%M%S).sql.gz
   ```

3. **Monitoring**: Add `pg_stat_statements` extension for query performance
   ```sql
   CREATE EXTENSION pg_stat_statements;
   
   SELECT query, calls, total_time, mean_time 
   FROM pg_stat_statements 
   ORDER BY total_time DESC LIMIT 10;
   ```

4. **Connection Pooling**: Use PgBouncer for external pooling (supports 10K+ connections)

5. **Partitioning**: Partition large tables by date for faster queries
   ```sql
   CREATE TABLE contacts_y2025m01 PARTITION OF contact_submissions
   FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
   ```

## Interview Talking Points

**"Why PostgreSQL over DynamoDB?"**
> "We value strong consistency, complex queries, and predictable costs over DynamoDB's unlimited scale. Our workload is <1K ops/sec where PostgreSQL excels. We also needed joins for analytics (e.g., contact → documents → search results), which DynamoDB can't do efficiently."

**"How did you maintain DynamoDB semantics?"**
> "I replicated atomic counters with PL/pgSQL functions using row-level locking, kept flexible metadata with JSONB columns, and used triggers for automatic timestamps. The application code barely changed—just swapped the database service class."

**"Explain your schema design philosophy"**
> "Hybrid approach: core fields as typed columns for type safety and fast lookups; variable metadata as JSONB for schema flexibility. GIN indexes make JSONB queries fast. This gives us SQL reliability with NoSQL flexibility."

**"What's the performance impact of connection pooling?"**
> "Without pooling, every request paid 50-100ms opening a connection. With pooling (1-10 connections), that's amortized, reducing latency by 7x. The pool blocks if exhausted, providing natural backpressure instead of overwhelming the database."

**"How would you scale this database layer?"**
> "Vertical first: larger instance, more memory. Then read replicas for analytics queries. If write-heavy, partition tables by date. For global scale, consider Citus (distributed Postgres) or migrate back to DynamoDB. But our current load doesn't need it."

