# Phase 1 - Ready for Execution

**Date:** October 23, 2025  
**Status:** ⏸ Awaiting SSH Access  
**Phase:** 1 - Deploy Exporters & Verify Targets

---

## Current Situation

 **Phase 0 Complete** - All configs corrected and validated locally  
⏸ **Phase 1 Prepared** - Deployment scripts ready, waiting for SSH access  
 **SSH Access** - Cannot connect to EC2 instance (SSH key not available)

---

## What's Been Prepared

### 1. Deployment Scripts Created

**Location:** `/home/guest/aws-to-opensource/scripts/monitoring/`

- `deploy-phase1.sh` - Fully automated deployment script
- `phase1-commands.sh` - Step-by-step command reference

### 2. Documentation Created

**Location:** `/home/guest/aws-to-opensource/`

- `PHASE1_DEPLOYMENT_GUIDE.md` - Comprehensive deployment guide with 3 options
- `PHASE1_READY.md` - This file (status summary)

### 3. Configs Ready for Upload

All Phase 0 corrected configs are ready to upload:

-  `docker-compose/config/prometheus/prometheus.yml` - Scrape jobs fixed
-  `docker-compose/config/prometheus/alert-rules.yml` - Alerts aligned
-  `docker-compose/config/alertmanager/config.yml` - Emoji removed
-  `docker-compose/config/alertmanager/default.tmpl` - Emoji removed
-  `docker-compose/config/promtail/promtail-config.yml` - Host logs commented
-  `docker-compose/docker-compose.yml` - Healthchecks fixed

---

## What You Need to Do

### Option A: Quick Deployment (5 minutes)

If you have SSH access configured:

```bash
# 1. Load your EC2 SSH key
ssh-add ~/.ssh/your-ec2-key.pem

# 2. Test SSH connectivity
ssh ubuntu@54.179.230.219 "echo 'SSH OK'"

# 3. Run automated deployment
cd /home/guest/aws-to-opensource
./scripts/monitoring/deploy-phase1.sh
```

### Option B: Step-by-Step (10 minutes)

If you prefer manual control:

```bash
# 1. Load your EC2 SSH key
ssh-add ~/.ssh/your-ec2-key.pem

# 2. Run step-by-step commands
cd /home/guest/aws-to-opensource
./scripts/monitoring/phase1-commands.sh
```

### Option C: Manual Deployment

Follow the detailed guide:

```bash
cat /home/guest/aws-to-opensource/PHASE1_DEPLOYMENT_GUIDE.md
```

---

## SSH Key Setup

If you don't have SSH access, you need to:

### 1. Locate Your EC2 Key

The key was created when you launched the EC2 instance. It's typically:

- **Name:** Something like `pretamane-key`, `aws-key`, or `ec2-key`
- **Location:** `~/.ssh/` or `~/Downloads/`
- **Format:** `.pem` file

### 2. Load the Key

```bash
# Find the key
find ~ -name "*.pem" -type f 2>/dev/null | grep -v ".local/share"

# Load it
ssh-add ~/.ssh/your-key-name.pem

# Or specify it directly in SSH
ssh -i ~/.ssh/your-key-name.pem ubuntu@54.179.230.219 "echo 'SSH OK'"
```

### 3. Alternative: AWS Systems Manager

If you can't find the SSH key, use AWS SSM:

```bash
# Connect via SSM (no SSH key needed)
aws ssm start-session --target i-0c151e9556e3d35e8 --region ap-southeast-1

# Then run commands manually on the instance
```

---

## What Phase 1 Will Do

When you run the deployment:

1. **Upload Configs** - All Phase 0 corrected configs to EC2
2. **Start Services** - node-exporter, cAdvisor, blackbox-exporter, Prometheus
3. **Verify Targets** - Check all Prometheus scrape targets are UP
4. **Test Endpoints** - Validate exporter metrics are accessible
5. **Test Probes** - Confirm blackbox probes are working

**Time:** 5-10 minutes  
**Risk:** Low (only adds exporters, doesn't change existing services)  
**Downtime:** None

---

## Expected Results

After Phase 1 deployment:

### Services Running

```
node-exporter     Up      System metrics (CPU, memory, disk)
cadvisor          Up      Container metrics
blackbox-exporter Up      Synthetic monitoring probes
prometheus        Up      Metrics collection & storage
```

### Prometheus Targets (All UP)

-  prometheus (self-monitoring)
-  fastapi-app (application)
-  minio (storage)
-  grafana (dashboards)
-  loki (logs)
-  alertmanager (alerts)
-  node-exporter (system)
-  cadvisor (containers)
-  blackbox-exporter (exporter)
-  blackbox-http-public (HTTP probes)
-  blackbox-http-internal (internal probes)
-  blackbox-http-admin (auth probes)
-  blackbox-tcp (TCP probes)

### Access URLs

- **Prometheus UI:** http://54.179.230.219:9090/targets
- **Prometheus Graph:** http://54.179.230.219:9090/graph
- **Node Exporter:** http://54.179.230.219:9100/metrics
- **cAdvisor:** http://54.179.230.219:8080

---

## Validation Commands

After deployment, verify with:

```bash
# Check all targets
ssh ubuntu@54.179.230.219 "curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'"

# Check for DOWN targets (should be empty)
ssh ubuntu@54.179.230.219 "curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.health != \"up\")'"

# Test exporters
ssh ubuntu@54.179.230.219 "curl -s http://localhost:9100/metrics | head -n 5"
ssh ubuntu@54.179.230.219 "curl -s http://localhost:8080/metrics | head -n 5"
ssh ubuntu@54.179.230.219 "curl -s 'http://localhost:9115/probe?target=http://caddy:80&module=http_2xx' | grep probe_success"
```

---

## Troubleshooting

### Can't Find SSH Key?

1. Check AWS EC2 console → Key Pairs
2. Check `~/.ssh/` directory: `ls -la ~/.ssh/`
3. Check Downloads: `ls -la ~/Downloads/*.pem`
4. Use AWS SSM instead (see Option C in deployment guide)

### SSH Permission Denied?

```bash
# Fix permissions
chmod 400 ~/.ssh/your-key.pem

# Load key
ssh-add ~/.ssh/your-key.pem

# Test
ssh ubuntu@54.179.230.219 "echo 'SSH OK'"
```

### Services Won't Start?

```bash
# Check logs
ssh ubuntu@54.179.230.219 "cd ~/app/docker-compose && docker-compose logs prometheus"

# Restart services
ssh ubuntu@54.179.230.219 "cd ~/app/docker-compose && docker-compose restart prometheus"
```

---

## Next Steps

After Phase 1 completes successfully:

1.  Review Prometheus targets UI: http://54.179.230.219:9090/targets
2.  Explore metrics: http://54.179.230.219:9090/graph
3.  **Proceed to Phase 2:** Enable baseline alerts (no notifications yet)

---

## Files Reference

### Deployment Scripts

- `/home/guest/aws-to-opensource/scripts/monitoring/deploy-phase1.sh`
- `/home/guest/aws-to-opensource/scripts/monitoring/phase1-commands.sh`

### Documentation

- `/home/guest/aws-to-opensource/PHASE1_DEPLOYMENT_GUIDE.md` (detailed guide)
- `/home/guest/aws-to-opensource/PHASE1_READY.md` (this file)
- `/home/guest/aws-to-opensource/PHASE0_COMPLETE.md` (Phase 0 summary)
- `/home/guest/aws-to-opensource/c.plan.md` (full plan)

### Configs to Upload

- `docker-compose/config/prometheus/prometheus.yml`
- `docker-compose/config/prometheus/alert-rules.yml`
- `docker-compose/config/alertmanager/config.yml`
- `docker-compose/config/alertmanager/default.tmpl`
- `docker-compose/config/promtail/promtail-config.yml`
- `docker-compose/docker-compose.yml`

---

## Summary

 **Phase 0:** Complete - Configs corrected and validated  
⏸ **Phase 1:** Ready - Waiting for SSH access to deploy  
 **Documentation:** Complete - 3 deployment options provided  
 **Scripts:** Ready - Automated and manual options available

**Action Required:** Load SSH key and run deployment script

**Estimated Time:** 5-10 minutes once SSH access is available

---

**Status:** Ready for deployment  
**Blocker:** SSH key not available locally  
**Resolution:** User needs to load EC2 SSH key or use AWS SSM

**Last Updated:** October 23, 2025

