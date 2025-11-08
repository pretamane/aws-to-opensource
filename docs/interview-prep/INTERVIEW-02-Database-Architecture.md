# Interview Guide: Database Architecture (PostgreSQL)

##  Selling Point
"I migrated from DynamoDB to PostgreSQL using JSONB columns for flexible metadata and GIN indexes for fast searches, maintaining NoSQL flexibility with ACID guarantees."

##  Migration Context: DynamoDB → PostgreSQL

### Why We Migrated

| Aspect | DynamoDB | PostgreSQL | Our Choice |
|--------|----------|------------|------------|
| **Cost** | ~$1.25/million writes | Fixed instance cost | PostgreSQL (predictable) |
| **Relationships** | None (denormalized) | FK constraints | PostgreSQL (data integrity) |
| **Queries** | Key-value only | Joins, aggregations | PostgreSQL (analytics) |
| **Scaling** | Auto to millions ops/sec | Vertical + sharding | DynamoDB IF massive scale |
| **Consistency** | Eventually consistent | ACID transactions | PostgreSQL (banking/audit) |

**Interview Answer**: "We chose PostgreSQL because we value strong consistency, complex queries, and predictable costs over DynamoDB's unlimited scale. Our workload is <1K ops/sec where PostgreSQL excels."

##  Schema Design Philosophy

### Best of Both Worlds: Structured + Flexible

```sql
CREATE TABLE contact_submissions (
    -- Structured columns (fast indexing, type safety)
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    
    -- Flexible metadata (schema evolution without migrations)
    document_insights JSONB,
    
    -- Automatic timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Key Design Decisions**:

1. **Core fields**: Structured columns (name, email) - frequently queried, benefit from type checking
2. **Metadata**: JSONB (document_insights) - varies per use case, changes often
3. **Timestamps**: Separate created_at/updated_at - audit trail, triggers auto-update

##  JSONB + GIN Indexes

### The Problem Without JSONB

**Option 1: EAV (Entity-Attribute-Value)** - Terrible performance
```sql
CREATE TABLE contact_metadata (
    contact_id VARCHAR,
    key VARCHAR,
    value TEXT
);
-- Query requires multiple joins, horrible performance
```

**Option 2: TEXT column** - Not queryable
```sql
metadata TEXT  -- '{"total_docs": 5}'
-- Can't query: WHERE metadata contains X
```

### Our Solution: JSONB with GIN Index

```sql
document_insights JSONB DEFAULT '{}';

CREATE INDEX idx_insights ON contact_submissions 
USING GIN(document_insights);
```

**Example Data**:
```json
{
  "total_documents": 5,
  "document_types": ["pdf", "docx"],
  "content_analysis": {
    "has_business_content": true,
    "confidence_level": "high"
  }
}
```

**Fast Queries**:
```sql
-- Find contacts with business content
SELECT * FROM contact_submissions
WHERE document_insights->>'has_business_content' = 'true';

-- Find contacts with PDFs
SELECT * FROM contact_submissions
WHERE document_insights->'document_types' @> '["pdf"]';
```

**GIN Index Magic**: Indexes JSON keys/values, making these queries as fast as regular column lookups.

##  How Services Connect to Database

```

  FastAPI App        
  (app_opensource.py)

            Imports
           ↓

  PostgreSQLService              
  (database_service_postgres.py) 
  - Connection Pool (1-10 conns) 
  - CRUD methods                 

            TCP 5432
           ↓

  PostgreSQL         
  Container          
  - Init Schema SQL  
  - Seed Data SQL    

```

### Connection Pooling Explained

```python
self.pool = SimpleConnectionPool(
    minconn=1,     # Keep 1 connection always open
    maxconn=10,    # Max 10 concurrent connections
    host='postgresql',
    database='pretamane_db',
    user='pretamane',
    password='...'
)
```

**Why Pooling Matters**:

**Without Pool** (every request):
```
1. Open TCP connection      50ms
2. SSL handshake           20ms
3. Execute query           10ms
4. Close connection         5ms
Total: 85ms (70ms wasted!)
```

**With Pool**:
```
1. Get connection from pool  <1ms
2. Execute query            10ms
3. Return to pool           <1ms
Total: 11ms (7x faster!)
```

**Pool Sizing Formula**:
```
maxconn = (CPU cores × 2) + disk spindles
Example: 4 cores + 1 SSD = 10 connections
```

**Interview Insight**: "Connection pools are critical for performance. Opening connections is expensive (50-100ms). Pooling amortizes that cost across requests, reducing latency by 80%+."

##  Atomic Counter (Visitor Count)

### DynamoDB Equivalent

```python
# DynamoDB atomic increment
dynamodb.update_item(
    TableName='visitors',
    Key={'id': 'count'},
    UpdateExpression='ADD #count :inc',
    ExpressionAttributeNames={'#count': 'count'},
    ExpressionAttributeValues={':inc': 1}
)
```

### PostgreSQL Function

```sql
CREATE FUNCTION increment_visitor_count()
RETURNS INTEGER AS $$
DECLARE
    new_count INTEGER;
BEGIN
    UPDATE website_visitors 
    SET count = count + 1, last_updated = NOW()
    WHERE id = 'visitor_count'
    RETURNING count INTO new_count;
    
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
- **Row-level locking**: Prevents race conditions
- **Atomic**: Increment + timestamp update in one transaction
- **Returns new value**: Like DynamoDB's RETURN_VALUES

**Interview Story**: "I replicated DynamoDB's atomic counter using a PostgreSQL function with row-level locking, ensuring concurrent requests don't lose increments."

##  Automatic Timestamp Updates

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

**What Happens**:
1. Application updates contact: `UPDATE contact_submissions SET status='contacted' WHERE id='123'`
2. Trigger fires BEFORE update
3. Sets `updated_at = NOW()` automatically
4. Update proceeds with fresh timestamp

**Benefit**: Application code never forgets to update timestamps - it's guaranteed by the database.

##  Data Initialization Flow

```
Docker Compose Start
        ↓

 PostgreSQL Container 
 Starts                

           
           ↓ Mounts volume

 /docker-entrypoint-initdb.d/ 
 - 01-init-schema.sql         
 - 02-seed-data.sql           

            Executes in order
           ↓
01: CREATE TABLES, INDEXES, FUNCTIONS, TRIGGERS
02: INSERT sample contacts, documents
           ↓
     Database Ready
```

**Key Point**: Scripts run ONLY on first boot (when data volume is empty). Re-running `docker-compose up` doesn't re-execute them.

##  Real Troubleshooting: Password Escaping

**Problem**: API can't connect to DB: `authentication failed`

**Debugging**:
```bash
# Test connection manually
docker exec -it postgresql psql -U pretamane -d pretamane_db
# Works! ← Password correct

# Check environment in container
docker exec fastapi-app env | grep DB_PASSWORD
DB_PASSWORD=#ThawZin2k77!  ← Shell interprets # as comment!
```

**Root Cause**: Special characters in password not escaped in `.env` file.

**Fix**:
```bash
# .env
DB_PASSWORD='#ThawZin2k77!'  # Quote in .env
```

**Interview Takeaway**: "When authentication fails but credentials work in psql, check environment variable escaping. Special chars like #, $, ! need quotes in .env files."

##  Production Improvements

1. **Replication**: Set up streaming replication for HA
2. **Backups**: Automated `pg_dump` to S3/MinIO every 6 hours
3. **Monitoring**: Add `pg_stat_statements` extension for query performance
4. **Connection Pooling**: Use PgBouncer for external pooling (supports 10K+ connections)
5. **Partitioning**: Partition large tables by date for faster queries

##  Interview Talking Points

1. **"JSONB gives NoSQL flexibility with SQL reliability"**: Schema evolution without migrations, still queryable with GIN indexes.
2. **"Connection pooling is critical for performance"**: Reduces latency 7x by reusing connections.
3. **"Database functions encapsulate business logic"**: Atomic counters, triggers guarantee consistency.
4. **"Structured+Flexible hybrid"**: Core fields as columns, metadata as JSONB.
5. **"Migration strategy"**: Moved from DynamoDB to Postgres, kept same semantics (atomic counters, timestamps).
