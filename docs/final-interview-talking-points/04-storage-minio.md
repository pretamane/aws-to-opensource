# Object Storage: MinIO

## Role & Responsibilities
S3-compatible object storage replacing AWS S3 and EFS for document uploads, processed files, and backups.

## Why MinIO Over AWS S3

| Aspect | AWS S3 | MinIO | Decision |
|--------|--------|-------|----------|
| **Cost** | $0.023/GB + egress | Infrastructure only | MinIO (90% savings) |
| **Egress** | $0.09/GB | Free | MinIO (no surprise bills) |
| **API** | S3 API | S3-compatible API | MinIO (portable) |
| **Latency** | Variable (internet) | Local (<5ms) | MinIO (faster) |
| **Scale** | Unlimited | Limited by disk | S3 for petabyte scale |

**Interview Answer**: "We chose MinIO for cost savings (no egress fees) and S3 API compatibility, which means our application code using boto3 works unchanged. If we need to scale beyond our instance storage, we can migrate back to S3 with zero code changes."

## Architecture

### Service Location
- Container: `minio`
- Console UI: `minio` (port 9001)
- API: port 9000
- Setup Job: `minio-setup` (one-time bucket initialization)
- Config: `docker-compose/docker-compose.yml`
- Service Code: `docker/api/shared/storage_service_minio.py`

### Bucket Structure
```
minio:9000/
  ├─ pretamane-data/         # Primary data
  │    └─ documents/
  │         └─ {contact_id}/
  │              └─ {document_id}/
  │                   └─ {filename}
  ├─ pretamane-backup/       # Automated backups
  │    ├─ postgres-dumps/
  │    ├─ prometheus-data/
  │    └─ grafana-configs/
  └─ pretamane-logs/         # Log archives
       ├─ caddy/
       └─ application/
```

## S3 API Compatibility

### boto3 Client Initialization
```python
import boto3
from botocore.client import Config

self.client = boto3.client(
    's3',
    endpoint_url='http://minio:9000',
    aws_access_key_id='minioadmin',
    aws_secret_access_key='minioadmin',
    config=Config(signature_version='s3v4'),
    region_name='us-east-1'  # MinIO doesn't use regions, but boto3 requires it
)
```

### Standard S3 Operations
```python
# Upload file
self.client.put_object(
    Bucket='pretamane-data',
    Key='documents/contact-123/doc-456/report.pdf',
    Body=file_content,
    ContentType='application/pdf',
    Metadata={'uploaded-by': 'user@example.com', 'timestamp': '2025-01-01'}
)

# Download file
response = self.client.get_object(
    Bucket='pretamane-data',
    Key='documents/contact-123/doc-456/report.pdf'
)
content = response['Body'].read()

# List files
response = self.client.list_objects_v2(
    Bucket='pretamane-data',
    Prefix='documents/contact-123/'
)
for obj in response['Contents']:
    print(obj['Key'], obj['Size'], obj['LastModified'])

# Delete file
self.client.delete_object(
    Bucket='pretamane-data',
    Key='documents/contact-123/doc-456/report.pdf'
)

# Generate presigned URL (temporary access)
url = self.client.generate_presigned_url(
    'get_object',
    Params={'Bucket': 'pretamane-data', 'Key': 'documents/.../report.pdf'},
    ExpiresIn=3600  # 1 hour
)
```

**Key Point**: Same boto3 code works with both MinIO and AWS S3—just change `endpoint_url`.

## Bucket Initialization

### Setup Job (Docker Compose)
```yaml
minio-setup:
  image: minio/mc:latest
  container_name: minio-setup
  depends_on:
    - minio
  entrypoint: >
    /bin/sh -c "
    sleep 5;
    /usr/bin/mc alias set myminio http://minio:9000 minioadmin minioadmin;
    /usr/bin/mc mb myminio/pretamane-data --ignore-existing;
    /usr/bin/mc mb myminio/pretamane-backup --ignore-existing;
    /usr/bin/mc mb myminio/pretamane-logs --ignore-existing;
    /usr/bin/mc anonymous set download myminio/pretamane-data;
    echo 'MinIO buckets created successfully';
    exit 0;
    "
```

### Bucket Policies
```bash
# Make bucket public for downloads (not recommended for production)
mc anonymous set download myminio/pretamane-data

# Set read-only policy
mc anonymous set public myminio/pretamane-data

# Custom policy (more granular)
cat > bucket-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"AWS": "*"},
      "Action": ["s3:GetObject"],
      "Resource": ["arn:aws:s3:::pretamane-data/*"]
    }
  ]
}
EOF
mc anonymous set-json bucket-policy.json myminio/pretamane-data
```

## Subpath Routing Fix

### The Problem
MinIO Console expects to be at root `/`, but we want it at `/minio` for unified routing.

### Two-Part Solution

#### 1. Caddy Configuration
```nginx
# Redirect root /minio to /minio/
redir /minio /minio/

# Handle /minio/* requests
handle /minio* {
    basic_auth {
        pretamane $2a$14$VBOmQYX9BQOaEPTCUXEIGekFJp9xfzMo8cs7ocDgMcjTYr68mIuNO
    }
    uri strip_prefix /minio
    reverse_proxy minio:9001
}
```

**Key**: `uri strip_prefix /minio` removes the prefix before forwarding to MinIO.

#### 2. MinIO Environment Variable
```yaml
environment:
  - MINIO_BROWSER_REDIRECT_URL=http://localhost:8080/minio
```

**Key**: MinIO knows its external URL and generates correct asset paths.

### Real Debugging Story

**Symptom**: MinIO Console loaded but was completely unstyled (white page, plain HTML).

**Investigation**:
1. Browser console: `GET /static/css/main.css → 404`
2. Network tab: CSS requested at `/static/css/main.css` (wrong path)
3. Should be: `/minio/static/css/main.css`

**Root Cause**: Using `handle_path /minio/*` stripped the path too early, causing wrong routing.

**Fix**: Changed to `handle /minio* { uri strip_prefix /minio }` with correct directive order.

**Verification**:
```bash
curl -I http://localhost:8080/minio/static/css/main.css
# Before: 404 Not Found
# After: 200 OK, Content-Type: text/css
```

**Interview Takeaway**: "Subpath routing needs configuration on both proxy and application. I debugged by checking browser console for 404s, network tab for Content-Type mismatches, and Caddy logs for routing decisions."

## Presigned URLs

### Use Case
Provide temporary access to private files without exposing credentials.

### Implementation
```python
def get_presigned_url(self, key: str, expiration: int = 3600) -> str:
    """Generate presigned URL for file access (expires in 1 hour)"""
    url = self.client.generate_presigned_url(
        'get_object',
        Params={'Bucket': 'pretamane-data', 'Key': key},
        ExpiresIn=expiration
    )
    return url

# Usage
doc_url = storage_service.get_presigned_url(
    'documents/contact-123/doc-456/report.pdf',
    expiration=3600
)
# Returns: http://minio:9000/pretamane-data/documents/...?X-Amz-Signature=...
```

### How It Works
1. Server generates URL with signature and expiration timestamp
2. Client accesses URL directly (no auth needed)
3. MinIO validates signature and timestamp
4. After expiration, URL becomes invalid

## Distributed Mode (Production)

### Single Node (Current)
```yaml
minio:
  command: server /data --console-address ":9001"
  volumes:
    - minio-data:/data
```

### Distributed Mode (4+ Nodes)
```bash
# Node 1
minio server http://node{1...4}/data{1...4} --console-address ":9001"

# Node 2
minio server http://node{1...4}/data{1...4} --console-address ":9001"

# Node 3, 4...
```

**Benefits**:
- High availability: survives node failures
- Erasure coding: automatically distributes and repairs data
- Higher throughput: parallel reads/writes

**Trade-offs**:
- Requires 4+ nodes minimum
- More complex setup
- Higher cost

## Monitoring & Metrics

### MinIO Metrics Endpoint
```bash
curl http://minio:9000/minio/v2/metrics/cluster
```

### Prometheus Scrape Config
```yaml
- job_name: 'minio'
  metrics_path: /minio/v2/metrics/cluster
  static_configs:
    - targets: ['minio:9000']
```

### Key Metrics
- `minio_bucket_usage_total_bytes` - Storage used per bucket
- `minio_s3_requests_total` - Request count by API operation
- `minio_s3_errors_total` - Error count
- `minio_disk_storage_available` - Available disk space
- `minio_network_sent_bytes_total` - Network egress

## Failure Modes & Recovery

### Disk Full
- **Symptom**: Upload fails with "no space left on device"
- **Detection**: Prometheus `minio_disk_storage_available` < threshold
- **Recovery**: Delete old files, increase volume size, enable lifecycle policies
- **Mitigation**: Set up disk usage alerts, automate cleanup

### Bucket Doesn't Exist
- **Symptom**: Upload fails with "NoSuchBucket" error
- **Detection**: Application logs show bucket creation errors
- **Recovery**: Re-run `minio-setup` job or create manually
- **Mitigation**: Application ensures bucket exists on startup

### Slow Uploads
- **Symptom**: Upload takes >30s for 10MB file
- **Detection**: Prometheus P95 upload latency > threshold
- **Root Causes**: 
  - Disk I/O bottleneck → use SSD, increase IOPS
  - Network bottleneck → check Docker network settings
  - Large files → implement chunked uploads
- **Recovery**: Scale to distributed mode for parallel writes

### Data Corruption
- **Symptom**: Downloaded file doesn't match hash
- **Detection**: Application validates checksums
- **Recovery**: Restore from backup
- **Mitigation**: Enable MinIO versioning, regular integrity checks

## Production Improvements

1. **Distributed Mode**: 4+ nodes for HA and erasure coding
2. **TLS**: Enable HTTPS for MinIO API and Console
3. **Access Keys**: Rotate credentials, use per-app keys
4. **Lifecycle Policies**: Auto-delete old files, transition to glacier
5. **Versioning**: Keep previous versions for rollback
6. **Replication**: Replicate critical buckets to second cluster
7. **Backup**: Regular snapshots to S3/BackBlaze B2

## Interview Talking Points

**"Why MinIO over S3?"**
> "Cost savings (no egress fees), faster local access (<5ms vs internet latency), and S3 API compatibility for portability. Our boto3 code works unchanged with both MinIO and S3—just change the endpoint URL. For massive scale (petabytes), I'd migrate back to S3."

**"How did you solve the subpath routing issue?"**
> "MinIO Console was loading but unstyled because CSS requests went to wrong paths. I debugged with browser console (404s), network tab (Content-Type), and Caddy logs (routing). Fixed by configuring both sides: Caddy `uri strip_prefix /minio` and MinIO `MINIO_BROWSER_REDIRECT_URL`. Verified Content-Type headers returned correctly."

**"What's your backup strategy?"**
> "Daily PostgreSQL dumps to MinIO `pretamane-backup` bucket, with optional replication to S3 for offsite backup. MinIO versioning keeps previous file versions. For disaster recovery, I can restore from any backup and rebuild the stack with Terraform + Docker Compose in 15 minutes."

**"How would you scale MinIO?"**
> "Current single-node setup handles our load (<100 GB, <1K req/sec). For scale: add 3 more nodes to enable distributed mode with erasure coding (survives 2 node failures), or migrate to AWS S3 with same code. Distributed mode also increases throughput via parallel I/O."

**"Explain S3 API compatibility"**
> "MinIO implements the S3 API, so any S3-compatible tool works: boto3, AWS CLI, Terraform S3 backend, database backups, etc. This is vendor lock-in prevention—we can switch storage backends without rewriting code. It's open standards in action."

