# Interview Guide: Object Storage (MinIO)

##  Selling Point
"I implemented S3-compatible object storage with MinIO, maintaining code portability while reducing costs, and solved complex subpath routing to serve the web console behind a reverse proxy."

##  Why MinIO Over AWS S3

### Cost Comparison

| Aspect | AWS S3 | MinIO (Self-Hosted) |
|--------|--------|---------------------|
| **Storage** | $0.023/GB/month | Server disk cost (fixed) |
| **PUT requests** | $0.005 per 1,000 | Free (your server) |
| **GET requests** | $0.0004 per 1,000 | Free (your server) |
| **Data transfer** | $0.09/GB egress | Free (local network) |
| **Example**: 100GB, 1M requests/month | ~$7.30/month | $0 (after server cost) |

**Break-even**: If you need persistent storage and already have server capacity, MinIO is cheaper.

### S3 API Compatibility Advantage

**Same code works on both**:
```python
import boto3

# AWS S3
s3 = boto3.client('s3',
    endpoint_url='https://s3.amazonaws.com',
    aws_access_key_id='AKIA...',
    aws_secret_access_key='...')

# MinIO (literally just change endpoint!)
s3 = boto3.client('s3',
    endpoint_url='http://minio:9000',  # ← Only change
    aws_access_key_id='minioadmin',
    aws_secret_access_key='minioadmin')

# Same methods work
s3.upload_file('doc.pdf', 'my-bucket', 'documents/doc.pdf')
s3.list_objects_v2(Bucket='my-bucket', Prefix='documents/')
```

**Interview Point**: "S3 API is the industry standard. By using MinIO, I can develop locally, test thoroughly, and migrate to AWS S3/Wasabi/Backblaze with zero code changes."

##  MinIO Architecture in Our Stack

```

  User Browser                       

               
                HTTP :8080
               ↓

  Caddy Reverse Proxy                
  - /minio/* → MinIO Console (9001)  
  - /api/upload → FastAPI → MinIO    

               
        
        ↓             ↓
  
 MinIO API       MinIO Console
 Port 9000       Port 9001    
 (S3 compat)     (Web UI)     
  
       
        Stores to
       ↓

 /data volume 
 - pretamane-data    (uploads)   
 - pretamane-backup  (backups)   
 - pretamane-logs    (app logs)  

```

##  Bucket Initialization Pattern

### Setup Container

```yaml
minio-setup:
  image: minio/mc:latest  # MinIO Client
  depends_on:
    - minio
  entrypoint: >
    /bin/sh -c "
    sleep 5;
    mc alias set myminio http://minio:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD;
    mc mb myminio/pretamane-data --ignore-existing;
    mc mb myminio/pretamane-backup --ignore-existing;
    mc mb myminio/pretamane-logs --ignore-existing;
    mc anonymous set download myminio/pretamane-data;
    exit 0;
    "
```

### What Each Command Does

**1. Create Alias**:
```bash
mc alias set myminio http://minio:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD
```
- Saves MinIO credentials
- Future commands use `myminio` instead of full URL

**2. Make Buckets**:
```bash
mc mb myminio/pretamane-data --ignore-existing
```
- `mb` = make bucket
- `--ignore-existing` = idempotent (doesn't fail if exists)

**3. Set Bucket Policy**:
```bash
mc anonymous set download myminio/pretamane-data
```
- Public read access (`s3:GetObject`)
- Anyone can download, but not list/upload/delete

**Interview Insight**: "I use an init container pattern to automate bucket creation. It's idempotent (safe to run multiple times) and version-controlled (buckets defined in code, not manual UI clicks)."

##  Console Subpath Routing (The Hard Problem)

### The Challenge

MinIO Console expects to be at **root** (`/`), but we want it at **subpath** (`/minio`).

**Without proper config**:
```html
<!-- MinIO HTML -->
<base href="/">
<link href="./static/css/main.css">

<!-- Browser requests -->
http://localhost:8080/static/css/main.css   Wrong!
                      ↑ Missing /minio prefix
```

### Two-Part Solution

#### Part 1: Caddy Path Handling

```nginx
handle /minio* {
    basic_auth { ... }
    uri strip_prefix /minio  # Strip before forwarding
    reverse_proxy minio:9001
}
```

**What happens**:
```
User requests: /minio/static/css/main.css
                    ↓ uri strip_prefix
Caddy forwards: /static/css/main.css to minio:9001
                    ↓
MinIO serves: /static/css/main.css (found!)
```

#### Part 2: MinIO Environment Variable

```yaml
minio:
  environment:
    - MINIO_BROWSER_REDIRECT_URL=http://localhost:8080/minio
```

**Result**: MinIO emits `<base href="/minio/">` in HTML

**Browser now requests**:
```
<link href="./static/css/main.css">
→ Resolves to: http://localhost:8080/minio/static/css/main.css 
```

### Real Debugging Story

**Problem**: MinIO Console loaded but unstyled (white page)

**Step 1**: Check browser console
```
Failed to load resource: /static/css/main.css (404)
```

**Step 2**: Check what Caddy received
```bash
curl -I http://localhost:8080/minio/static/css/main.css
# HTTP/1.1 200 OK
# Content-Type: text/html  ← Should be text/css!
```

**Step 3**: Check what MinIO received
```bash
docker logs caddy | grep "css/main.css"
# GET /static/css/main.css → fastapi-app:8000
```

**Root Cause**: Used `handle_path` instead of `handle + uri strip_prefix`, path stripped too early, Caddy routed to wrong backend.

**Fix**: Changed to `handle /minio* { uri strip_prefix /minio }`

**Interview Narrative**: "I debugged by checking browser network tab (wrong path), curl to verify response headers (wrong content-type), and Caddy logs to see routing decision. This systematic approach identified path stripping happened at wrong stage."

##  Storage Service Implementation

### Python Integration

```python
class MinIOStorageService:
    def __init__(self):
        self.client = boto3.client('s3',
            endpoint_url=os.environ.get('S3_ENDPOINT_URL'),
            aws_access_key_id=os.environ.get('S3_ACCESS_KEY'),
            aws_secret_access_key=os.environ.get('S3_SECRET_KEY')
        )
    
    def upload_file(self, file_obj, bucket, key):
        """Upload file to MinIO"""
        try:
            self.client.upload_fileobj(
                file_obj,
                bucket,
                key,
                ExtraArgs={
                    'ContentType': 'application/pdf',
                    'Metadata': {
                        'uploaded-by': 'contact-form',
                        'upload-timestamp': datetime.utcnow().isoformat()
                    }
                }
            )
            logger.info(f"Uploaded {key} to {bucket}")
            return True
        except Exception as e:
            logger.error(f"Upload failed: {e}")
            return False
```

### File Path Structure

```
pretamane-data/
 documents/
    contact_001/
       requirements.pdf
       architecture.png
    contact_002/
       proposal.docx
    ...
 public/
     website-assets/
         logo.png
         brochure.pdf
```

**Naming Strategy**:
- Group by contact: Easy to delete all files for a contact
- Hierarchical: Supports prefix searches
- Readable: `contact_001/requirements.pdf` vs `8a9f2e1b-3c4d.pdf`

##  Bucket Policies & Access Control

### Public Download Policy

```bash
mc anonymous set download myminio/pretamane-data
```

**Equivalent AWS S3 Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": "*",
    "Action": ["s3:GetObject"],
    "Resource": ["arn:aws:s3:::pretamane-data/*"]
  }]
}
```

**What's Allowed**:
-  Download: `GET /pretamane-data/documents/file.pdf`
-  List: `GET /pretamane-data/` (returns 403)
-  Upload: `PUT /pretamane-data/new.pdf` (requires auth)
-  Delete: `DELETE /pretamane-data/file.pdf` (requires auth)

**Use Case**: Public assets (whitepapers, logos) that anyone can download but not list/modify.

### Private Bucket (Default)

```bash
# No anonymous policy set
```

**All operations require signed requests** (AWS SigV4):
```python
# Generates temporary signed URL (valid 1 hour)
url = s3_client.generate_presigned_url(
    'get_object',
    Params={'Bucket': 'pretamane-backup', 'Key': 'db-backup.sql'},
    ExpiresIn=3600
)
# Returns: http://minio:9000/pretamane-backup/db-backup.sql?X-Amz-Algorithm=...
```

**Interview Point**: "For sensitive documents, I use presigned URLs with short expiration (1-24 hours). User gets a temporary download link without needing AWS credentials."

##  MinIO Metrics & Monitoring

### Prometheus Scrape Configuration

```yaml
- job_name: "minio"
  static_configs:
    - targets: ["minio:9000"]
  metrics_path: "/minio/v2/metrics/cluster"
```

### Key Metrics Exposed

| Metric | Type | What It Measures |
|--------|------|------------------|
| `minio_cluster_capacity_raw_total_bytes` | Gauge | Total storage capacity |
| `minio_cluster_capacity_usable_free_bytes` | Gauge | Free space remaining |
| `minio_s3_requests_total` | Counter | Total S3 API requests |
| `minio_s3_requests_errors_total` | Counter | Failed requests |
| `minio_bucket_objects_size_distribution` | Histogram | Object size distribution |

### Alert Example

```yaml
- alert: MinIOHighDiskUsage
  expr: (1 - (minio_cluster_capacity_usable_free_bytes / minio_cluster_capacity_raw_total_bytes)) > 0.8
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "MinIO disk usage >80%"
    description: "Only {{ $value }}% free space remaining"
```

##  Production Improvements

### Current Setup (Single Node)
```
Single MinIO Container
 /data volume (local disk)
```

**Limitations**:
-  No redundancy (disk failure = data loss)
-  No horizontal scaling
-  Single point of failure

### Production Setup (Distributed Mode)

```yaml
# Minimum 4 nodes for distributed MinIO
version: '3.8'
services:
  minio1:
    image: minio/minio
    command: server http://minio{1...4}/data{1...2}
    
  minio2:
    image: minio/minio
    command: server http://minio{1...4}/data{1...2}
    
  minio3:
    image: minio/minio
    command: server http://minio{1...4}/data{1...2}
    
  minio4:
    image: minio/minio
    command: server http://minio{1...4}/data{1...2}
```

**Features**:
-  Erasure coding (survives N/2 disk failures)
-  Horizontal scaling
-  High availability
-  Automatic data healing

### Backup Strategy

**Daily Automated Backup**:
```bash
#!/bin/bash
# Cron: 0 2 * * * /scripts/backup-minio.sh

DATE=$(date +%Y%m%d)
mc mirror --remove myminio/pretamane-data s3/backup-bucket/minio/$DATE/
```

**Cross-Region Replication**:
```bash
mc replicate add myminio/pretamane-data \
  --remote-bucket arn:aws:s3:::aws-backup-bucket \
  --replicate delete,delete-marker
```

##  Interview Talking Points

1. **"S3 API compatibility = portability"**: Same code works locally (MinIO) and cloud (AWS S3, Backblaze, Wasabi).

2. **"Subpath routing requires two-sided config"**: Proxy strips prefix, app knows base path via env var.

3. **"Init container pattern for automation"**: Buckets created via code (version-controlled, idempotent).

4. **"Bucket policies for security"**: Public download for assets, private with presigned URLs for sensitive docs.

5. **"Production path: distributed mode"**: Current single-node for demo, can scale to 4+ nodes with erasure coding for HA.

6. **"Real debugging example"**: Identified path stripping issue by checking browser console, response headers, and proxy logs systematically.
