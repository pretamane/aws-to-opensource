# Operational Flows & Scenarios

##  Contact Submission + Document Upload Flow

### User Story
User visits portfolio site, fills contact form with resume attachment, submits.

### Technical Flow
```
1. User Browser
   └─ POST /contact (multipart/form-data)
      ├─ name, email, company, service, message
      └─ file: resume.pdf (2MB)

2. Caddy (Edge)
   ├─ Apply security headers (HSTS, CSP, XFO, nosniff)
   ├─ Log request to /var/log/caddy/access.log
   └─ Forward to fastapi-app:8000/contact

3. FastAPI Application
   ├─ CORS middleware validates origin
   ├─ Metrics middleware records start time
   ├─ Pydantic validates payload
   ├─ Generate contact_id (UUID)
   └─ Record Prometheus metrics
       ├─ contact_submissions_total.labels(source='website', service='Cloud Architecture').inc()
       └─ http_requests_total.labels(method='POST', endpoint='/contact', status='200').inc()

4. PostgreSQL Service (Database)
   ├─ Get connection from pool (1-10 available)
   ├─ INSERT INTO contact_submissions (id, name, email, ..., document_insights)
   ├─ Return contact_id
   └─ Return connection to pool

5. MinIO Service (Storage)
   ├─ Generate S3 key: documents/{contact_id}/{doc_id}/resume.pdf
   ├─ Upload via boto3: put_object(Bucket='pretamane-data', Key=..., Body=file_bytes)
   ├─ Set metadata: {'uploaded-by': email, 'timestamp': now}
   └─ Return S3 URL

6. Background Task (Async Processing)
   ├─ Extract text from PDF (PyPDF2 / pdfminer)
   ├─ Analyze content
   │   ├─ Word count: 1,247
   │   ├─ Language: English
   │   ├─ Keywords: ['python', 'docker', 'aws', 'kubernetes']
   │   └─ Confidence: 'high'
   ├─ Update PostgreSQL
   │   └─ UPDATE contact_submissions 
   │       SET document_insights = '{"total_documents": 1, "document_types": ["pdf"], ...}'
   │       WHERE id = contact_id
   └─ Update processing_status = 'completed'

7. Meilisearch Service (Search Index)
   ├─ Prepare document for indexing
   ├─ POST /indexes/documents/documents
   │   {
   │     "id": doc_id,
   │     "contact_id": contact_id,
   │     "filename": "resume.pdf",
   │     "text_content": "extracted text here...",
   │     "keywords": ["python", "docker", "aws"],
   │     "document_type": "pdf"
   │   }
   └─ Wait for indexing task to complete

8. Email Service (AWS SES)
   ├─ Compose notification email
   ├─ ses.send_email(
   │     Source='noreply@example.com',
   │     Destination={'ToAddresses': ['admin@example.com']},
   │     Message={'Subject': 'New Contact', 'Body': '...'}
   │   )
   └─ Log email sent

9. Observability
   ├─ Prometheus scrapes /metrics (10s interval)
   │   └─ contact_submissions_total, http_request_duration_seconds
   ├─ Promtail tails /mnt/logs/app.log
   │   └─ Ships to Loki with labels {job="fastapi", level="INFO"}
   └─ Grafana dashboard auto-refreshes
       └─ "Contact Submissions (24h)" graph updates

10. Response to User
    └─ 200 OK {"contact_id": "...", "message": "Submitted successfully"}
```

### Performance Metrics
- **Total time**: 150-300ms
- **Database write**: 10-15ms (from pool)
- **MinIO upload**: 50-100ms (2MB file)
- **Meilisearch index**: 20-30ms (async, doesn't block response)
- **SES email**: 100-200ms (async background task)

##  Document Search Flow

### User Story
User searches for "python developer" to find relevant documents.

### Technical Flow
```
1. User Browser
   └─ POST /documents/search {"query": "python developer", "filters": {"document_type": "pdf"}}

2. Caddy
   └─ Forward to fastapi-app:8000/documents/search

3. FastAPI
   ├─ Validate request (Pydantic)
   ├─ Record start time
   └─ Call MeilisearchService.search_documents()

4. Meilisearch
   ├─ Parse query: ["python", "developer"]
   ├─ Apply typo tolerance (Levenshtein distance)
   ├─ Search index with ranking rules:
   │   ├─ words: both words present
   │   ├─ typo: fewer typos = higher rank
   │   ├─ proximity: "python developer" together > separated
   │   └─ exactness: exact match > partial
   ├─ Apply filter: document_type = "pdf"
   ├─ Return top 10 results with highlights
   └─ Processing time: 12ms

5. FastAPI
   ├─ Enrich results with PostgreSQL metadata
   │   └─ JOIN with contact_submissions for contact names
   ├─ Format response
   ├─ Record metrics
   │   ├─ document_search_queries_total.inc()
   │   └─ http_request_duration_seconds.observe(0.025)  # 25ms total
   └─ Return results

6. Response
   {
     "results": [
       {
         "id": "doc-123",
         "filename": "john-resume.pdf",
         "contact_name": "John Doe",
         "highlights": {
           "text_content": "...experienced <em>Python developer</em>..."
         },
         "score": 0.98
       }
     ],
     "total_count": 42,
     "processing_time": 0.012
   }
```

##  Monitoring & Alerting Flow

### Scenario: High API Latency Detected

```
1. Prometheus (every 10s)
   ├─ Scrapes http://fastapi-app:9091/metrics
   ├─ Stores: http_request_duration_seconds_bucket{le="1.0"} 1523
   └─ Evaluates alert rules

2. Alert Rule Triggered
   alert: HighLatency
   expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1.0
   for: 10m
   └─ P95 latency = 1.2s (threshold: 1.0s) for 10 minutes

3. Alertmanager
   ├─ Receives alert from Prometheus
   ├─ Groups by: alertname="HighLatency", severity="warning"
   ├─ Waits 30s for more alerts (batching)
   └─ Routes to receiver: "slack" (based on severity)

4. Notification
   └─ POST https://hooks.slack.com/services/...
       {
         "text": "️ Alert: HighLatency",
         "attachments": [{
           "title": "API latency is high",
           "text": "P95 latency is 1.2s (threshold: 1s)",
           "color": "warning"
         }]
       }

5. Engineer Investigation
   ├─ Open Grafana dashboard
   │   ├─ Request rate: normal (~50/sec)
   │   ├─ Error rate: normal (<1%)
   │   └─ Latency: spiked at 10:15am
   ├─ Check Prometheus for correlations
   │   └─ active_database_connections = 10/10 (pool exhausted!)
   ├─ Drill into Loki logs
   │   {job="fastapi"} |= "10:15" |= "ERROR"
   │   └─ "psycopg2.pool.PoolError: connection pool exhausted"
   └─ Root cause identified: DB connection pool too small

6. Resolution
   ├─ Immediate: Restart fastapi-app (frees stuck connections)
   │   └─ docker-compose restart fastapi-app
   ├─ Short-term: Increase pool size
   │   └─ maxconn=10 → maxconn=20 in database_service_postgres.py
   └─ Long-term: Add connection timeout, optimize slow queries

7. Post-Incident
   ├─ Document in docs/status-reports/latency-spike-2025-01-01.md
   ├─ Update runbook with troubleshooting steps
   └─ Tune alert threshold (maybe 1.5s to reduce noise)
```

##  Deployment & Rollback Flow

### Successful Deployment

```
1. Developer
   ├─ Commit code changes
   ├─ Push to git main branch
   └─ Trigger deployment: ./scripts/deploy-opensource.sh EC2_IP

2. Deployment Script
   ├─ Build Docker image locally
   │   └─ docker build -t pretamane-app:latest docker/api
   ├─ Tag previous version
   │   └─ docker tag pretamane-app:latest pretamane-app:rollback
   ├─ Save & compress image
   │   └─ docker save pretamane-app:latest | gzip > /tmp/app.tar.gz
   └─ Upload to EC2
       └─ scp app.tar.gz ubuntu@EC2_IP:/tmp/

3. EC2 Instance
   ├─ Load new image
   │   └─ docker load < /tmp/app.tar.gz
   ├─ Pull latest code
   │   └─ git pull origin main
   ├─ Update services
   │   └─ docker-compose up -d --no-deps fastapi-app
   └─ Old container stops, new container starts

4. Health Check (Automated)
   ├─ Wait 10s for startup
   ├─ curl http://localhost:8080/health
   │   └─ {"status": "healthy", "components": {...}}
   ├─ Check metrics endpoint
   │   └─ curl http://localhost:8080/metrics | grep http_requests_total
   └─ All checks pass 

5. Monitoring
   ├─ Grafana dashboard shows brief dip (restart)
   ├─ Request rate returns to normal in 30s
   └─ Error rate remains low

6. Notification
   └─ Slack: " Deployment successful to production"
```

### Rollback Scenario

```
1. Deployment Fails
   └─ Health check returns 500 Internal Server Error

2. Automated Rollback
   ├─ Tag failed version
   │   └─ docker tag pretamane-app:latest pretamane-app:failed
   ├─ Restore previous version
   │   └─ docker tag pretamane-app:rollback pretamane-app:latest
   ├─ Restart service
   │   └─ docker-compose up -d --no-deps fastapi-app
   └─ Verify health
       └─ curl http://localhost:8080/health → 200 OK 

3. Investigation
   ├─ Check failed container logs
   │   └─ docker logs fastapi-app-failed
   ├─ Find error: "ModuleNotFoundError: No module named 'new_dependency'"
   └─ Root cause: Missing requirement in requirements.txt

4. Fix
   ├─ Add missing dependency to requirements.txt
   ├─ Test locally
   │   └─ docker-compose up --build
   └─ Redeploy when verified
```

##  Incident Troubleshooting: Database Connection Issue

### Symptoms
- All API endpoints returning 500 errors
- Grafana shows 100% error rate
- Loki logs filled with "connection refused" errors

### Investigation Flow

```
1. Initial Triage (Grafana)
   ├─ When: Started 10:30am
   ├─ What: All endpoints affected
   ├─ Severity: Complete outage
   └─ Duration: Ongoing (5 minutes)

2. Check Service Health
   docker-compose ps
   └─ postgresql: Exit 1 ← Container crashed!

3. Check Logs
   docker logs postgresql --tail=50
   └─ "FATAL: data directory '/var/lib/postgresql/data' has wrong ownership"

4. Root Cause Analysis
   ├─ Recent change: Updated docker-compose.yml
   ├─ Volume mapping changed: ./data/postgres → postgres-data (named volume)
   ├─ Old data still in ./data/postgres with wrong permissions
   └─ PostgreSQL failed to start with new volume

5. Resolution
   ├─ Stop all services
   │   └─ docker-compose down
   ├─ Restore old volume mapping temporarily
   │   └─ volumes: - ./data/postgres:/var/lib/postgresql/data
   ├─ Start PostgreSQL
   │   └─ docker-compose up -d postgresql
   ├─ Dump data
   │   └─ docker exec postgresql pg_dumpall -U postgres > backup.sql
   ├─ Switch to named volume
   │   └─ volumes: - postgres-data:/var/lib/postgresql/data
   ├─ Start PostgreSQL (creates new volume)
   │   └─ docker-compose up -d postgresql
   ├─ Restore data
   │   └─ docker exec -i postgresql psql -U postgres < backup.sql
   └─ Start all services
       └─ docker-compose up -d

6. Verification
   ├─ Health check
   │   └─ curl http://localhost:8080/health → 200 OK 
   ├─ Test database
   │   └─ curl http://localhost:8080/analytics/insights → Data returned 
   └─ Monitor for 15 minutes → Stable

7. Post-Incident
   ├─ RTO: 20 minutes
   ├─ Data loss: None (backup restored)
   ├─ Document incident report
   ├─ Add runbook: "PostgreSQL won't start - volume issues"
   └─ Prevent: Always test volume changes in staging first
```

##  Backup & Restore Flow

### Regular Backup (Automated Daily)

```
1. Cron Job (3am UTC)
   └─ /usr/local/bin/backup-data.sh

2. Backup Script
   ├─ PostgreSQL
   │   └─ docker exec postgresql pg_dump -U pretamane pretamane_db > postgres-20250101.sql
   ├─ MinIO
   │   └─ docker exec minio mc mirror myminio/pretamane-data /backup/minio/
   ├─ Prometheus
   │   └─ docker exec prometheus tar -czf - /prometheus > prometheus-20250101.tar.gz
   ├─ Grafana
   │   └─ docker exec grafana tar -czf - /var/lib/grafana > grafana-20250101.tar.gz
   └─ Create archive
       └─ tar -czf backup-20250101.tar.gz postgres-* minio/ prometheus-* grafana-*

3. Upload to S3 (Optional)
   └─ aws s3 cp backup-20250101.tar.gz s3://backups/

4. Cleanup Old Backups
   └─ find /backup -name "backup-*.tar.gz" -mtime +7 -delete  # Keep 7 days

5. Notification
   └─ Slack: " Daily backup completed: backup-20250101.tar.gz (2.3GB)"
```

### Disaster Recovery (Complete Restore)

```
1. Scenario: EC2 instance terminated accidentally

2. Restore Infrastructure (10 min)
   cd terraform-ec2
   terraform apply
   └─ New EC2 instance created with user-data bootstrap

3. Wait for Bootstrap (5 min)
   └─ User-data installs Docker, clones repo, starts services

4. Stop Services
   ssh ubuntu@NEW_IP
   cd app/docker-compose
   docker-compose down

5. Restore Backup
   ├─ Download from S3
   │   └─ aws s3 cp s3://backups/backup-20250101.tar.gz /tmp/
   ├─ Extract
   │   └─ tar -xzf /tmp/backup-20250101.tar.gz -C /tmp/restore/
   ├─ Restore PostgreSQL
   │   └─ docker-compose up -d postgresql
   │   └─ docker exec -i postgresql psql -U postgres < /tmp/restore/postgres-20250101.sql
   ├─ Restore MinIO
   │   └─ docker-compose up -d minio
   │   └─ docker cp /tmp/restore/minio/. minio:/data/
   ├─ Restore Prometheus
   │   └─ docker-compose up -d prometheus
   │   └─ docker exec prometheus tar -xzf - -C / < /tmp/restore/prometheus-20250101.tar.gz
   └─ Restore Grafana
       └─ docker-compose up -d grafana
       └─ docker exec grafana tar -xzf - -C / < /tmp/restore/grafana-20250101.tar.gz

6. Start All Services
   └─ docker-compose up -d

7. Verify
   ├─ Health check → 200 OK
   ├─ Check data → contacts, documents present
   ├─ Check metrics → historical data restored
   └─ Check dashboards → Grafana configs restored

8. Update DNS/Load Balancer
   └─ Point to NEW_IP

Total Recovery Time: ~25 minutes
Data Loss: <24 hours (last backup)
```

## Interview Talking Points

**"Walk me through a user request end-to-end"**
> [Use Contact Submission Flow above, emphasizing: edge security, async processing, observability instrumentation, graceful degradation]

**"How do you debug production incidents?"**
> "Start with Grafana to identify when and what. Check Prometheus for correlated metrics. Drill into Loki logs filtered by timeframe. Verify infrastructure with `docker-compose ps`. Use correlation IDs to trace requests. Document findings and update runbooks."

**"Explain your backup and disaster recovery strategy"**
> "Automated daily backups of PostgreSQL, MinIO, Prometheus, and Grafana to S3 with 7-day retention. Terraform recreates infrastructure in 10 minutes. Backups restore in 15 minutes. RTO: 25 minutes. RPO: 24 hours. For stricter RPO, I'd enable WAL shipping for PostgreSQL and MinIO replication."

**"What happens if PostgreSQL crashes?"**
> "Docker restart policy (`unless-stopped`) automatically restarts it. FastAPI connection pool retries connections. Prometheus alert fires after 2 minutes of downtime. If restart fails, I restore from backup. The system gracefully degrades—read-only mode with cached data while DB recovers."

