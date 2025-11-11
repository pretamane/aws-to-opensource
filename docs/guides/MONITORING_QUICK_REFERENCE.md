# Monitoring Stack - Quick Reference Guide

This is a quick reference for common monitoring operations, queries, and troubleshooting.

---

##  Quick Start

### Start Monitoring Stack
```bash
cd docker-compose
docker-compose up -d
```

### Check All Services
```bash
docker-compose ps
```

### View Logs
```bash
# All monitoring services
docker-compose logs -f prometheus grafana loki alertmanager promtail

# Specific service
docker-compose logs -f prometheus
```

### Stop Monitoring Stack
```bash
docker-compose down
# Keep data:
docker-compose down --volumes=false
```

---

##  Access Points

| Service | URL | Credentials |
|---------|-----|-------------|
| **Grafana** | http://localhost:3000/grafana | Check `.env` for GF_SECURITY_ADMIN_USER/PASSWORD |
| **Prometheus** | http://localhost:9090/prometheus | No auth by default |
| **Alertmanager** | http://localhost:9093/alertmanager | No auth by default |
| **Node Exporter** | http://localhost:9100/metrics | Metrics endpoint |
| **cAdvisor** | http://localhost:8080 | Container metrics UI |
| **Blackbox** | http://localhost:9115 | Probe metrics |
| **Promtail** | http://localhost:9080/targets | Log targets status |

---

##  Common Prometheus Queries

### System Metrics

```promql
# CPU Usage (%)
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory Usage (%)
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk Usage (%)
100 - ((node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100)

# System Load (5min average)
node_load5

# Disk I/O Read Rate
rate(node_disk_read_bytes_total[5m])

# Disk I/O Write Rate
rate(node_disk_written_bytes_total[5m])

# Network Receive Rate (bytes/sec)
rate(node_network_receive_bytes_total[5m])

# Network Transmit Rate (bytes/sec)
rate(node_network_transmit_bytes_total[5m])
```

### Container Metrics

```promql
# Container CPU Usage
rate(container_cpu_usage_seconds_total{name!=""}[5m])

# Container Memory Usage (bytes)
container_memory_usage_bytes{name!=""}

# Container Memory Usage (%)
(container_memory_usage_bytes{name!=""} / container_spec_memory_limit_bytes{name!=""}) * 100

# Container Network Receive
rate(container_network_receive_bytes_total{name!=""}[5m])

# Container Network Transmit
rate(container_network_transmit_bytes_total{name!=""}[5m])

# Container Restart Count
container_restart_count{name!=""}

# Containers by State
container_last_seen{name!=""}
```

### Application Metrics

```promql
# HTTP Request Rate
rate(http_requests_total[5m])

# HTTP Error Rate (5xx)
rate(http_requests_total{status=~"5.."}[5m])

# HTTP 4xx Rate
rate(http_requests_total{status=~"4.."}[5m])

# HTTP Success Rate (%)
(sum(rate(http_requests_total{status=~"2.."}[5m])) / sum(rate(http_requests_total[5m]))) * 100

# Request Duration (95th percentile)
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Request Duration (99th percentile)
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))
```

### Service Health

```promql
# Service Up/Down (1=up, 0=down)
up

# Service Up Count
count(up == 1)

# Service Down Count
count(up == 0)

# Endpoint Probe Success
probe_success{job=~"blackbox.*"}

# Endpoint Response Time
probe_duration_seconds{job=~"blackbox.*"}

# Failed Probes
probe_success == 0
```

### Database Metrics

```promql
# PostgreSQL Active Connections
pg_stat_database_numbackends

# PostgreSQL Transaction Rate
rate(pg_stat_database_xact_commit[5m])

# PostgreSQL Cache Hit Ratio
pg_stat_database_blks_hit / (pg_stat_database_blks_hit + pg_stat_database_blks_read)
```

---

##  Common Loki Queries

### Application Logs

```logql
# All logs from FastAPI
{job="fastapi"}

# Error logs only
{job="fastapi"} |= "ERROR"

# Logs with specific keyword
{job="fastapi"} |= "database connection"

# Exclude debug logs
{job="fastapi"} != "DEBUG"

# Pattern matching
{job="fastapi"} |~ "error|exception|fail"

# JSON parsing
{job="fastapi"} | json | level="error"
```

### Security Logs

```logql
# All security events
{component="security"}

# CrowdSec ban events
{job="crowdsec"} |= "ban"

# Fail2ban actions
{job="fail2ban"} |~ "Ban|Unban"

# Failed SSH attempts
{job="auth"} |~ "Failed password|authentication failure"

# Successful SSH logins
{job="auth"} |= "Accepted password"

# Sudo commands
{job="auth"} |= "sudo"

# All failed authentication
{job="auth"} |~ "Failed|Failure|Invalid"
```

### Web Server Logs

```logql
# Caddy access logs
{job="caddy",log_type="access"}

# HTTP 5xx errors
{job="caddy"} | json | status >= 500

# HTTP 4xx errors
{job="caddy"} | json | status >= 400 and status < 500

# Requests from specific IP
{job="caddy"} | json | remote_ip="1.2.3.4"

# Slow requests (>1s duration)
{job="caddy"} | json | duration > 1

# POST requests
{job="caddy"} | json | request_method="POST"
```

### Container Logs

```logql
# All Docker container logs
{job="docker"}

# Specific container
{job="docker",container_name="fastapi-app"}

# Multiple containers
{job="docker",container_name=~"fastapi.*|postgresql"}

# Errors across all containers
{job="docker"} |~ "(?i)(error|exception|fatal)"
```

### System Logs

```logql
# System logs
{job="system"}

# Kernel logs
{job="kernel"}

# PostgreSQL logs
{job="postgresql"}

# All logs with rate counting
rate({job=~".+"} [5m])
```

---

##  Alert Management

### View Active Alerts (Prometheus)
```bash
# Via CLI
curl http://localhost:9090/api/v1/alerts

# Via Browser
open http://localhost:9090/prometheus/alerts
```

### View Alertmanager Status
```bash
# Check status
curl http://localhost:9093/api/v2/status

# List active alerts
curl http://localhost:9093/api/v2/alerts

# Silence an alert
curl -X POST http://localhost:9093/api/v2/silences \
  -H "Content-Type: application/json" \
  -d '{
    "matchers": [{"name": "alertname", "value": "HighCPUUsage"}],
    "startsAt": "2024-01-01T00:00:00Z",
    "endsAt": "2024-01-01T01:00:00Z",
    "createdBy": "admin",
    "comment": "Maintenance window"
  }'
```

### Test Alert Firing
```bash
# Add test alert
docker exec alertmanager amtool alert add test severity=warning

# Check alert
docker exec alertmanager amtool alert query
```

### Validate Configurations
```bash
# Check Prometheus config
docker exec prometheus promtool check config /etc/prometheus/prometheus.yml

# Check alert rules
docker exec prometheus promtool check rules /etc/prometheus/alert-rules.yml

# Check Alertmanager config
docker exec alertmanager amtool check-config /etc/alertmanager/config.yml
```

---

##  Troubleshooting

### Service Not Scraping

**Check Prometheus Targets:**
```bash
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health != "up")'
```

**Check service is accessible:**
```bash
docker exec prometheus wget -O- http://node-exporter:9100/metrics
```

**Restart Prometheus:**
```bash
docker-compose restart prometheus
```

### Alerts Not Firing

**Check alert rules:**
```bash
# Validate syntax
docker exec prometheus promtool check rules /etc/prometheus/alert-rules.yml

# View active alerts in Prometheus
curl http://localhost:9090/api/v1/alerts | jq
```

**Check Alertmanager connection:**
```bash
curl http://localhost:9090/api/v1/alertmanagers
```

### Logs Not Appearing in Grafana

**Check Promtail targets:**
```bash
curl http://localhost:9080/targets
```

**Check Promtail logs:**
```bash
docker-compose logs promtail
```

**Test Loki API:**
```bash
# Check ready status
curl http://localhost:3100/ready

# Query recent logs
curl -G http://localhost:3100/loki/api/v1/query \
  --data-urlencode 'query={job="docker"}' \
  --data-urlencode 'limit=10'
```

**Check file permissions:**
```bash
# Verify Promtail can read log files
docker exec promtail ls -la /var/log
```

### High Memory Usage

**Check Prometheus storage:**
```bash
docker exec prometheus du -sh /prometheus
```

**Reduce retention time:**
Edit `docker-compose.yml`:
```yaml
command:
  - '--storage.tsdb.retention.time=15d'  # Reduce from 30d
```

**Check container memory:**
```bash
docker stats --no-stream
```

### Blackbox Probes Failing

**Manual probe test:**
```bash
# Test HTTP probe
curl "http://localhost:9115/probe?target=http://caddy:80&module=http_2xx"

# Check probe config
docker exec blackbox-exporter cat /etc/blackbox_exporter/config.yml
```

**Check target accessibility:**
```bash
docker exec blackbox-exporter wget -O- http://caddy:80
```

### Grafana Dashboards Not Loading

**Check datasources:**
```bash
curl http://localhost:3000/api/datasources | jq
```

**Restart Grafana:**
```bash
docker-compose restart grafana
```

**Check provisioning:**
```bash
docker exec grafana ls -la /etc/grafana/provisioning/datasources
docker exec grafana ls -la /var/lib/grafana/dashboards
```

---

##  Performance Optimization

### Reduce Scrape Frequency
Edit `prometheus.yml`:
```yaml
scrape_configs:
  - job_name: 'less-critical-service'
    scrape_interval: 60s  # Instead of 15s
```

### Use Recording Rules
For frequently-used complex queries, use recording rules in `alert-rules.yml`:
```yaml
- record: node:cpu_usage:percent
  expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

Then query: `node:cpu_usage:percent`

### Filter High-Volume Logs
Edit `promtail-config.yml`:
```yaml
pipeline_stages:
  - match:
      selector: '{job="high-volume-app"}'
      stages:
        - drop:
            expression: ".*DEBUG.*"
```

### Enable Prometheus Query Logging
```yaml
command:
  - '--query.log-file=/prometheus/queries.log'
```

---

##  Backup & Restore

### Backup Prometheus Data
```bash
# Stop Prometheus
docker-compose stop prometheus

# Backup data
tar czf prometheus-backup-$(date +%Y%m%d).tar.gz -C docker-compose prometheus-data/

# Start Prometheus
docker-compose start prometheus
```

### Backup Grafana Dashboards
```bash
# Export all dashboards
curl -H "Authorization: Bearer YOUR_API_KEY" \
  http://localhost:3000/api/search | jq

# Backup Grafana data
tar czf grafana-backup-$(date +%Y%m%d).tar.gz -C docker-compose grafana-data/
```

### Backup Loki Data
```bash
tar czf loki-backup-$(date +%Y%m%d).tar.gz -C docker-compose loki-data/
```

### Restore from Backup
```bash
# Stop services
docker-compose stop prometheus grafana loki

# Restore data
tar xzf prometheus-backup-YYYYMMDD.tar.gz -C docker-compose/

# Start services
docker-compose start prometheus grafana loki
```

---

##  Security Checklist

- [ ] Change default Grafana admin password
- [ ] Enable authentication on Prometheus (use reverse proxy)
- [ ] Configure Alertmanager webhook secrets
- [ ] Rotate AWS SES SMTP credentials regularly
- [ ] Use HTTPS for all external access (via Cloudflare Tunnel)
- [ ] Restrict Prometheus/Grafana to internal network
- [ ] Enable audit logging in Grafana
- [ ] Review alert routing rules
- [ ] Implement log redaction for sensitive data
- [ ] Set up monitoring for monitoring (meta-monitoring)

---

##  Emergency Commands

### Restart All Monitoring
```bash
docker-compose restart prometheus grafana loki alertmanager promtail
```

### Clear All Alerts
```bash
docker exec alertmanager amtool silence add alertname=~".*" --duration=1h --comment="Emergency silence"
```

### Free Up Disk Space
```bash
# Check disk usage
df -h

# Clear old Prometheus data
docker exec prometheus rm -rf /prometheus/wal

# Prune Docker
docker system prune -af --volumes
```

### Export Metrics for Analysis
```bash
# Export current metrics
curl http://localhost:9090/api/v1/query?query=up > metrics-snapshot.json

# Export time series data
curl 'http://localhost:9090/api/v1/query_range?query=up&start=2024-01-01T00:00:00Z&end=2024-01-02T00:00:00Z&step=15s' > timeseries.json
```

---

##  Useful Links

- **Prometheus Query Examples**: https://prometheus.io/docs/prometheus/latest/querying/examples/
- **PromQL Basics**: https://prometheus.io/docs/prometheus/latest/querying/basics/
- **LogQL Documentation**: https://grafana.com/docs/loki/latest/logql/
- **Grafana Dashboard Library**: https://grafana.com/grafana/dashboards/
- **Alertmanager Configuration**: https://prometheus.io/docs/alerting/latest/configuration/

---

##  Pro Tips

1. **Use Variables in Grafana**: Create template variables for dynamic dashboards
2. **Set Up Favorites**: Bookmark commonly-used queries in Prometheus
3. **Create Alert Runbooks**: Add annotation URLs to alerts linking to documentation
4. **Use Labels Consistently**: Standardize label names across exporters
5. **Monitor the Monitors**: Set up alerts for monitoring stack health
6. **Regular Maintenance**: Schedule cleanup of old data and logs
7. **Test Alert Routes**: Regularly test notification channels
8. **Document Custom Queries**: Keep a team wiki of useful queries
9. **Review Alerts Weekly**: Tune thresholds based on actual usage patterns
10. **Learn Regex**: Essential for both PromQL and LogQL pattern matching

---

**Last Updated**: 2024  
**Version**: 1.0  
**Maintained By**: AWS-to-OpenSource Project Team