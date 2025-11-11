# Phase 1 Deployment Guide - Exporters & Target Verification

**Date:** October 23, 2025  
**Status:** Ready for Execution  
**Prerequisites:** Phase 0 Complete 

---

## Overview

Phase 1 deploys the monitoring exporters (node-exporter, cAdvisor, blackbox-exporter) and verifies that Prometheus can scrape all configured targets successfully.

---

## Prerequisites Check

Before starting, ensure you have:

- [x] Phase 0 corrections complete (configs fixed locally)
- [ ] SSH access to EC2 instance (54.179.230.219)
- [ ] SSH key loaded: `ssh-add ~/.ssh/your-ec2-key.pem`
- [ ] AWS CLI configured (for alternative SSM access)

**Test SSH connectivity:**
```bash
ssh ubuntu@54.179.230.219 "echo 'SSH OK'"
```

---

## Option 1: Automated Deployment (Recommended)

If you have SSH access configured:

```bash
cd /home/guest/aws-to-opensource
./scripts/monitoring/deploy-phase1.sh i-0c151e9556e3d35e8 54.179.230.219 ap-southeast-1
```

This script will:
1. Check SSH connectivity
2. Upload Phase 0 corrected configs
3. Start exporters and Prometheus
4. Verify all targets are up
5. Test exporter endpoints

---

## Option 2: Manual Deployment (Step-by-Step)

If automated script fails or you prefer manual control:

### Step 1: Upload Corrected Configs

```bash
# Set variables
INSTANCE_IP="54.179.230.219"

# Create directories on EC2
ssh ubuntu@$INSTANCE_IP "mkdir -p ~/app/docker-compose/config/{prometheus,alertmanager,promtail,blackbox}"

# Upload Prometheus configs
scp /home/guest/aws-to-opensource/docker-compose/config/prometheus/prometheus.yml \
    ubuntu@$INSTANCE_IP:~/app/docker-compose/config/prometheus/

scp /home/guest/aws-to-opensource/docker-compose/config/prometheus/alert-rules.yml \
    ubuntu@$INSTANCE_IP:~/app/docker-compose/config/prometheus/

# Upload Alertmanager configs
scp /home/guest/aws-to-opensource/docker-compose/config/alertmanager/config.yml \
    ubuntu@$INSTANCE_IP:~/app/docker-compose/config/alertmanager/

scp /home/guest/aws-to-opensource/docker-compose/config/alertmanager/default.tmpl \
    ubuntu@$INSTANCE_IP:~/app/docker-compose/config/alertmanager/

# Upload Promtail config
scp /home/guest/aws-to-opensource/docker-compose/config/promtail/promtail-config.yml \
    ubuntu@$INSTANCE_IP:~/app/docker-compose/config/promtail/

# Upload docker-compose.yml (with healthcheck fixes)
scp /home/guest/aws-to-opensource/docker-compose/docker-compose.yml \
    ubuntu@$INSTANCE_IP:~/app/docker-compose/
```

### Step 2: Start Exporters and Prometheus

```bash
# SSH into EC2
ssh ubuntu@$INSTANCE_IP

# Navigate to docker-compose directory
cd ~/app/docker-compose

# Start/restart monitoring services
docker-compose up -d node-exporter cadvisor blackbox-exporter prometheus

# Wait for services to initialize
sleep 15

# Check services are running
docker-compose ps node-exporter cadvisor blackbox-exporter prometheus
```

### Step 3: Verify Prometheus Targets

```bash
# Still on EC2 instance

# Check all targets via API
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health, url: .scrapeUrl}'

# Check for any DOWN targets
curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.health != "up") | " DOWN: " + .labels.job + " (" + .scrapeUrl + ")"'

# If empty output = all targets UP 
```

**Expected targets (all should be UP):**
- `prometheus` - Self-monitoring
- `fastapi-app` - Application metrics
- `minio` - Object storage metrics
- `grafana` - Dashboard metrics
- `loki` - Log aggregation metrics
- `alertmanager` - Alert routing metrics
- `node-exporter` - System metrics
- `cadvisor` - Container metrics
- `blackbox-exporter` - Exporter self-metrics
- `blackbox-http-public` - HTTP probes (Caddy endpoints)
- `blackbox-http-internal` - Internal service probes
- `blackbox-http-admin` - Auth verification probes (expects 401)
- `blackbox-tcp` - TCP connectivity probes

### Step 4: Test Exporter Endpoints

```bash
# Test node-exporter (system metrics)
curl -s http://localhost:9100/metrics | head -n 10

# Should see metrics like:
# node_cpu_seconds_total
# node_memory_MemAvailable_bytes
# node_filesystem_avail_bytes

# Test cAdvisor (container metrics)
curl -s http://localhost:8080/metrics | head -n 10

# Should see metrics like:
# container_cpu_usage_seconds_total
# container_memory_usage_bytes

# Test blackbox-exporter (probe to Caddy)
curl -s 'http://localhost:9115/probe?target=http://caddy:80&module=http_2xx' | grep probe_success

# Should see:
# probe_success 1
```

### Step 5: Verify Blackbox Probes

```bash
# Test HTTP probe to Caddy
curl -s 'http://localhost:9115/probe?target=http://caddy:80&module=http_2xx' | grep -E 'probe_(success|duration_seconds|http_status_code)'

# Expected output:
# probe_success 1
# probe_http_status_code 200
# probe_duration_seconds 0.xxx

# Test TCP probe to PostgreSQL
curl -s 'http://localhost:9115/probe?target=postgresql:5432&module=tcp_connect' | grep probe_success

# Expected output:
# probe_success 1
```

---

## Option 3: Via AWS Systems Manager (No SSH Key Required)

If you don't have SSH access but have AWS CLI configured:

```bash
# Upload configs via S3 (temporary)
aws s3 cp /home/guest/aws-to-opensource/docker-compose/config/ \
    s3://temp-bucket/phase1-configs/ --recursive

# Run commands via SSM
aws ssm send-command \
    --instance-ids i-0c151e9556e3d35e8 \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=[
        "aws s3 cp s3://temp-bucket/phase1-configs/ ~/app/docker-compose/config/ --recursive",
        "cd ~/app/docker-compose",
        "docker-compose up -d node-exporter cadvisor blackbox-exporter prometheus",
        "sleep 15",
        "curl -s http://localhost:9090/api/v1/targets | jq"
    ]' \
    --region ap-southeast-1
```

---

## Validation Checklist

After deployment, verify:

- [ ] All 4 exporter services running: `docker-compose ps | grep -E 'node-exporter|cadvisor|blackbox|prometheus'`
- [ ] Prometheus accessible: `curl http://localhost:9090/-/healthy`
- [ ] All targets UP: `curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health != "up")'` (should be empty)
- [ ] Node exporter metrics: `curl http://localhost:9100/metrics | grep node_cpu`
- [ ] cAdvisor metrics: `curl http://localhost:8080/metrics | grep container_cpu`
- [ ] Blackbox probes working: `curl 'http://localhost:9115/probe?target=http://caddy:80&module=http_2xx' | grep 'probe_success 1'`

---

## Troubleshooting

### Services Won't Start

```bash
# Check logs
docker-compose logs node-exporter
docker-compose logs cadvisor
docker-compose logs blackbox-exporter
docker-compose logs prometheus

# Common issues:
# 1. Port conflicts - check: netstat -tulpn | grep -E '9090|9100|8080|9115'
# 2. Config errors - validate: docker exec prometheus promtool check config /etc/prometheus/prometheus.yml
```

### Targets Showing DOWN

```bash
# Check which targets are down
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health != "up")'

# Test connectivity manually
curl http://node-exporter:9100/metrics
curl http://cadvisor:8080/metrics
curl http://blackbox-exporter:9115/metrics

# Check Docker network
docker network inspect docker-compose_default
```

### Blackbox Probes Failing

```bash
# Test probe manually
curl -v 'http://localhost:9115/probe?target=http://caddy:80&module=http_2xx'

# Check blackbox config
docker exec blackbox-exporter cat /etc/blackbox_exporter/config.yml

# Test target directly
docker exec blackbox-exporter wget -O- http://caddy:80
```

---

## Success Criteria

Phase 1 is complete when:

1.  All 4 services running (node-exporter, cadvisor, blackbox-exporter, prometheus)
2.  All Prometheus targets showing `health: "up"`
3.  Exporter metrics endpoints responding
4.  Blackbox probes returning `probe_success 1`
5.  No errors in service logs

---

## Next Steps

After Phase 1 completion:

1. **Access Prometheus UI:** http://54.179.230.219:9090/targets
2. **Review metrics:** http://54.179.230.219:9090/graph
3. **Proceed to Phase 2:** Enable baseline alerts (no notifications yet)

---

## CLI Quick Reference

```bash
# Check all targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Check specific exporter
curl http://localhost:9100/metrics | head
curl http://localhost:8080/metrics | head
curl http://localhost:9115/metrics | head

# Test blackbox probe
curl 'http://localhost:9115/probe?target=http://caddy:80&module=http_2xx' | grep probe_success

# Reload Prometheus config (if needed)
curl -X POST http://localhost:9090/-/reload

# Restart services
docker-compose restart prometheus
docker-compose restart node-exporter cadvisor blackbox-exporter
```

---

## Files Modified/Uploaded

From Phase 0 (already corrected locally):

1. `docker-compose/config/prometheus/prometheus.yml` - Scrape jobs configured
2. `docker-compose/config/prometheus/alert-rules.yml` - Alerts aligned with active jobs
3. `docker-compose/config/alertmanager/config.yml` - Emoji removed
4. `docker-compose/config/alertmanager/default.tmpl` - Emoji removed
5. `docker-compose/config/promtail/promtail-config.yml` - Host logs commented
6. `docker-compose/docker-compose.yml` - Healthchecks fixed

All configs validated locally 

---

**Status:** Ready for deployment  
**Risk Level:** Low (only adds exporters, no changes to existing services)  
**Rollback:** `docker-compose stop node-exporter cadvisor blackbox-exporter`

**Estimated Time:** 5-10 minutes  
**Downtime:** None (existing services unaffected)

