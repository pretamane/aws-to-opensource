# Failure Modes & Runbooks

## System-Wide Failures

### 1. Complete Outage (All Services Down)

**Symptoms**:
- Website unreachable
- All API endpoints return connection refused
- Grafana dashboard inaccessible

**Likely Causes**:
- EC2 instance terminated/stopped
- Docker daemon crashed
- Out of memory (OOM killer)

**Runbook**:
```bash
# 1. Check EC2 instance status
aws ec2 describe-instance-status --instance-ids i-xxx

# 2. If stopped, start it
aws ec2 start-instances --instance-ids i-xxx

# 3. If running, SSH and check Docker
ssh ubuntu@EC2_IP
sudo systemctl status docker

# 4. If Docker down, restart
sudo systemctl restart docker

# 5. Start services
cd ~/app/docker-compose
docker-compose up -d

# 6. Verify health
curl http://localhost:8080/health
```

---

### 2. High Memory Usage (OOM Risk)

**Symptoms**:
- Services randomly restarting
- Kernel logs show OOM killer
- `docker stats` shows memory limits hit

**Detection**:
```promql
# Prometheus alert
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.10
```

**Runbook**:
```bash
# 1. Identify memory hogs
docker stats --no-stream | sort -k4 -h

# 2. Check for memory leaks
docker logs fastapi-app | grep -i "memory"

# 3. Restart leaking service
docker-compose restart <service>

# 4. If persistent, scale instance
# Via Terraform: instance_type = "t3.large"
terraform apply

# 5. Or add swap (temporary)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

---

### 3. Disk Full

**Symptoms**:
- Services failing to write logs
- Database writes fail
- Docker can't pull images

**Detection**:
```promql
node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes < 0.10
```

**Runbook**:
```bash
# 1. Check disk usage
df -h
du -sh /var/lib/docker/* | sort -h

# 2. Clean Docker resources
docker system prune -a --volumes -f

# 3. Clean logs
sudo journalctl --vacuum-time=7d
find /var/log -name "*.log" -mtime +30 -delete

# 4. If persistent, increase EBS volume
aws ec2 modify-volume --volume-id vol-xxx --size 50
# Then: sudo growpart /dev/xvda 1 && sudo resize2fs /dev/xvda1

# 5. Enable log rotation
cat > /etc/logrotate.d/docker-compose <<EOF
/var/lib/docker/containers/*/*.log {
  rotate 7
  daily
  compress
  size=10M
  missingok
  delaycompress
  copytruncate
}
EOF
```

---

## Service-Specific Failures

### 4. PostgreSQL Down

**Symptoms**:
- All API endpoints return 500
- Logs show "connection refused" or "FATAL: the database system is starting up"

**Detection**:
```promql
up{job="postgresql"} == 0
```

**Runbook**:
```bash
# 1. Check container status
docker ps -a | grep postgresql

# 2. Check logs
docker logs postgresql --tail=100

# 3. Common issues:

# a) Volume permission error
docker-compose down
sudo chown -R 999:999 /data/postgres  # Postgres UID
docker-compose up -d postgresql

# b) Corrupted data directory
docker-compose down
docker volume rm docker-compose_postgres-data
# Restore from backup
docker-compose up -d postgresql
docker exec -i postgresql psql -U postgres < /backup/postgres.sql

# c) Configuration error
docker exec postgresql cat /var/lib/postgresql/data/postgresql.conf
# Fix config, restart
docker-compose restart postgresql

# 4. Verify
docker exec postgresql pg_isready -U pretamane
curl http://localhost:8080/health | jq .components.database
```

---

### 5. MinIO Storage Issues

**Symptoms**:
- Document uploads fail
- Downloads return 404
- Console UI inaccessible

**Detection**:
```promql
minio_disk_storage_available / minio_disk_storage_total < 0.10
```

**Runbook**:
```bash
# 1. Check MinIO status
docker ps | grep minio
docker logs minio --tail=50

# 2. Check bucket exists
docker exec minio mc ls myminio/

# 3. Recreate buckets if missing
docker exec minio mc mb myminio/pretamane-data --ignore-existing

# 4. Check disk space
docker exec minio df -h /data

# 5. Verify access via API
aws s3 ls s3://pretamane-data --endpoint-url http://localhost:9000

# 6. Console not loading? Check Caddy routing
curl -I http://localhost:8080/minio/
# Should return 200, not 404

# 7. Restart if needed
docker-compose restart minio
```

---

### 6. Meilisearch Not Returning Results

**Symptoms**:
- Search endpoint returns empty results
- Known documents not found
- Console shows no documents

**Detection**:
```bash
curl http://localhost:7700/indexes/documents/stats | jq .numberOfDocuments
# Returns 0 or much less than expected
```

**Runbook**:
```bash
# 1. Check Meilisearch health
curl http://localhost:7700/health

# 2. Check index exists
curl http://localhost:7700/indexes | jq .

# 3. Check document count
curl -H "Authorization: Bearer MASTER_KEY" \
  http://localhost:7700/indexes/documents/stats | jq .

# 4. Re-index if empty
# Via API endpoint (if implemented)
curl -X POST http://localhost:8080/admin/reindex

# 5. Or manually
docker exec fastapi-app python3 -c "
from search_service_meilisearch import MeilisearchService
from database_service_postgres import PostgreSQLService
search = MeilisearchService()
db = PostgreSQLService()
docs = db.get_all_documents()
for doc in docs:
    search.index_document(doc)
"

# 6. Verify
curl http://localhost:7700/indexes/documents/search?q=test
```

---

### 7. Prometheus Not Scraping Metrics

**Symptoms**:
- Grafana shows "No data"
- Prometheus targets down
- Alerts not firing

**Detection**:
- Visit http://localhost:8080/prometheus/targets
- Targets show "DOWN" or "UNKNOWN"

**Runbook**:
```bash
# 1. Check Prometheus health
curl http://localhost:9090/-/healthy

# 2. Check targets
curl http://localhost:9090/api/v1/targets | jq .data.activeTargets

# 3. Verify endpoint accessibility
curl http://fastapi-app:9091/metrics  # From Prometheus container
docker exec prometheus curl http://fastapi-app:9091/metrics

# 4. Common issues:

# a) Wrong port/path in prometheus.yml
docker exec prometheus cat /etc/prometheus/prometheus.yml | grep -A5 fastapi

# b) Network issue
docker network inspect docker-compose_app-network | grep fastapi-app

# c) Firewall/security group
# Check if internal ports are open

# 5. Restart Prometheus
docker-compose restart prometheus

# 6. Force reload config
curl -X POST http://localhost:9090/-/reload
```

---

### 8. Caddy Reverse Proxy Misconfiguration

**Symptoms**:
- 404 errors on known endpoints
- CSS/JS not loading (blank page)
- Basic Auth not working

**Detection**:
- Browser shows 404 or 502
- Caddy logs show routing errors

**Runbook**:
```bash
# 1. Check Caddy logs
docker logs caddy --tail=100 | grep ERROR

# 2. Test Caddy config
docker exec caddy caddy validate --config /etc/caddy/Caddyfile

# 3. Common issues:

# a) Wrong backend port
# Check: reverse_proxy fastapi-app:8000
# Verify FastAPI is on 8000:
docker port fastapi-app

# b) Subpath routing broken
# For MinIO: need both `uri strip_prefix /minio` and `MINIO_BROWSER_REDIRECT_URL`

# c) Basic Auth hash wrong
# Regenerate:
docker exec caddy caddy hash-password --plaintext 'your-password'

# 4. Reload Caddy config
docker exec caddy caddy reload --config /etc/Caddy/Caddyfile

# 5. Or restart
docker-compose restart caddy

# 6. Test specific routes
curl -I http://localhost:8080/api/health
curl -I http://localhost:8080/grafana/
curl -I http://localhost:8080/minio/
```

---

### 9. Loki Logs Not Showing

**Symptoms**:
- Grafana "Explore" shows no logs
- Loki returns empty results

**Detection**:
```bash
curl http://localhost:3100/ready
# Should return 200 OK
```

**Runbook**:
```bash
# 1. Check Loki health
docker logs loki --tail=50

# 2. Check Promtail is shipping
docker logs promtail --tail=50 | grep "POST"

# 3. Verify log files exist
docker exec fastapi-app ls -lh /mnt/logs/

# 4. Test Loki query
curl 'http://localhost:3100/loki/api/v1/query_range?query={job="fastapi"}'

# 5. Common issues:

# a) Log path wrong in promtail-config.yml
docker exec promtail cat /etc/promtail/config.yml | grep __path__

# b) Logs not in JSON format
docker exec fastapi-app head /mnt/logs/app.log
# Should be JSON lines

# c) Loki storage full
docker exec loki df -h /loki

# 6. Restart components
docker-compose restart loki promtail

# 7. Re-check in Grafana
# Grafana > Explore > Loki datasource > {job="fastapi"}
```

---

### 10. High API Latency

**Symptoms**:
- Requests taking >1s
- Timeouts
- Users complaining of slow app

**Detection**:
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1.0
```

**Runbook**:
```bash
# 1. Check current latency
curl -w "@curl-format.txt" http://localhost:8080/api/health
# curl-format.txt contains: time_total: %{time_total}

# 2. Identify slow component
# Check Grafana dashboard for bottlenecks

# 3. Common causes:

# a) Database connection pool exhausted
# Prometheus: active_database_connections == 10/10
# Fix: Increase pool size in database_service_postgres.py
# Or: Restart FastAPI to clear stuck connections
docker-compose restart fastapi-app

# b) Slow query
# Check PostgreSQL logs
docker exec postgresql psql -U pretamane -c "
SELECT pid, now() - query_start AS duration, query
FROM pg_stat_activity
WHERE state = 'active' AND now() - query_start > interval '1 second'
ORDER BY duration DESC;
"
# Optimize or kill slow query:
# SELECT pg_terminate_backend(pid);

# c) MinIO slow uploads
# Check disk I/O:
iostat -x 5

# d) Meilisearch slow searches
# Check index size:
curl http://localhost:7700/indexes/documents/stats | jq .
# If too large, consider splitting or optimizing

# 4. Scale resources
# CPU bound? Upgrade instance:
# terraform: instance_type = "t3.large"

# 5. Enable caching
# Add Redis for frequently accessed data
```

---

## Network & Connectivity Issues

### 11. Cannot SSH to EC2

**Symptoms**:
- `ssh` hangs or times out
- Permission denied

**Runbook**:
```bash
# 1. Check security group
aws ec2 describe-security-groups --group-ids sg-xxx | grep -A10 IpPermissions

# 2. Verify your IP is allowed
curl ifconfig.me  # Your current IP
# Should be in SSH allowed list

# 3. Check instance is running
aws ec2 describe-instances --instance-ids i-xxx | grep State

# 4. Use SSM Session Manager (no SSH needed)
aws ssm start-session --target i-xxx --region ap-southeast-1

# 5. Check key permissions
chmod 400 ~/.ssh/aws-key.pem
ssh -i ~/.ssh/aws-key.pem -v ubuntu@EC2_IP  # Verbose mode
```

---

### 12. External API Calls Failing (AWS SES)

**Symptoms**:
- Email notifications not sent
- Logs show "connection timeout" or "access denied"

**Runbook**:
```bash
# 1. Check IAM role permissions
aws iam get-role-policy --role-name pretamane-ec2-app-role --policy-name ses-send-policy

# 2. Test SES from instance
ssh ubuntu@EC2_IP
aws ses send-email \
  --from noreply@example.com \
  --to test@example.com \
  --subject "Test" \
  --text "Test message"

# 3. Check SES sending limits
aws ses get-send-quota

# 4. Verify email verified in SES
aws ses list-identities
aws ses get-identity-verification-attributes --identities noreply@example.com

# 5. Check application logs
docker logs fastapi-app | grep -i "email\|ses"
```

---

## Preventive Measures

### Monitoring Checklist
- [ ] Prometheus scraping all targets
- [ ] Grafana dashboards loading
- [ ] Alerts configured and firing test
- [ ] Loki receiving logs
- [ ] Health checks passing
- [ ] Backup cron job running
- [ ] Disk usage <70%
- [ ] Memory usage <80%
- [ ] CPU usage <70% sustained

### Weekly Maintenance
- [ ] Review Grafana dashboards
- [ ] Check for failed backups
- [ ] Update Docker images (`docker-compose pull`)
- [ ] Review error logs
- [ ] Test restore procedure
- [ ] Rotate credentials
- [ ] Review AWS bill

### Monthly Review
- [ ] Audit IAM permissions
- [ ] Review security group rules
- [ ] Test disaster recovery
- [ ] Update documentation
- [ ] Review and tune alert thresholds

---

## Emergency Contacts & Escalation

```
Level 1: Automated Alerts
  └─ Prometheus → Alertmanager → Slack #alerts

Level 2: On-Call Engineer
  └─ PagerDuty (for critical alerts)

Level 3: Team Lead / Manager
  └─ Prolonged outages (>1 hour)

Level 4: External Support
  └─ AWS Support (for infrastructure issues)
```

---

## Interview Talking Points

**"How do you handle production incidents?"**
> "Systematic approach: Check Grafana for when/what, Prometheus for correlations, Loki for error logs, then consult runbooks. I document every incident and update runbooks so the next person (or me in 6 months) can resolve faster. Runbooks include symptoms, detection, likely causes, and step-by-step fixes with verification."

**"What's your runbook philosophy?"**
> "Runbooks should be executable by someone unfamiliar with the system. I include symptoms, Prometheus queries for detection, common causes ranked by likelihood, and complete commands with expected outputs. Every incident that takes >30 minutes to resolve gets a new runbook."

**"How do you prevent recurring issues?"**
> "After each incident: 1) Fix immediate issue, 2) Update runbook, 3) Add monitoring/alert if missing, 4) Identify root cause, 5) Implement permanent fix, 6) Document in postmortem. Example: DB pool exhaustion → immediate restart → add metric/alert → increase pool size → add connection timeout."

**"What metrics do you monitor?"**
> "Four golden signals: Latency (P50/P95/P99), Traffic (req/sec), Errors (rate/count), Saturation (CPU/memory/disk/connections). Plus business metrics (contact submissions, document uploads) and synthetic checks (Blackbox Exporter). Alerts on symptoms, not causes."

