# Zero-Budget IP-Hiding Security Implementation Guide

**Status:** Phase 1 - Quick Tunnel Implementation  
**Cost:** $0/month  
**Security Level:** Moderate → High (after Phase 2)

---

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Phase 1: Quick Tunnel (Current)](#phase-1-quick-tunnel-current)
4. [Phase 2: Managed Tunnel with Domain (Future)](#phase-2-managed-tunnel-with-domain-future)
5. [Security Features](#security-features)
6. [Access Credentials](#access-credentials)
7. [Deployment Steps](#deployment-steps)
8. [Troubleshooting](#troubleshooting)
9. [Rotation & Maintenance](#rotation--maintenance)

---

## Overview

This implementation **completely hides your EC2 IP address** behind Cloudflare's infrastructure using **Cloudflare Tunnel** (formerly Argo Tunnel). No direct public access to ports 80/443 - all traffic flows through Cloudflare's edge network.

### What Changed

**BEFORE:**
```
Internet → EC2 Public IP (54.179.230.219) → Caddy → Services
            IP EXPOSED
```

**AFTER (Phase 1 - Quick Tunnel):**
```
Internet → Cloudflare Edge → Cloudflare Tunnel → Caddy → Services
            IP HIDDEN      (xyz.trycloudflare.com)
                              EC2 ports 80/443 CLOSED
```

**AFTER (Phase 2 - With Domain):**
```
Internet → Cloudflare Edge → Cloudflare Tunnel → Caddy → Services
            IP HIDDEN      (your-domain.com)
            WAF enabled     EC2 ports 80/443 CLOSED
            Access rules
            Geo-blocking
```

---

## Architecture

### Components

1. **Cloudflare Tunnel (`cloudflared`)**
   - Docker container running in app-network
   - Establishes outbound-only connection to Cloudflare
   - Generates random public hostname (*.trycloudflare.com)
   - No inbound ports required

2. **Caddy (Reverse Proxy)**
   - Listens on `:80` (HTTP only, internal)
   - Security headers (HSTS, CSP, X-Frame-Options, etc.)
   - Basic Auth for admin paths
   - JSON access logs for CrowdSec

3. **EC2 Security Group**
   - **Removed:** Inbound 80, 443 from 0.0.0.0/0
   - **Kept:** AWS SSM (managed by AWS)
   - **Optional:** SSH from your IP only

4. **Host Hardening**
   - CrowdSec: Parses Caddy logs, auto-bans malicious IPs
   - fail2ban: SSH brute-force protection
   - Unattended security updates

### Network Flow

```
                                    
                                      Cloudflare Edge    
                                      (DDoS Protection)  
                                    
                                               
                                                Encrypted Tunnel
                                                (Outbound from EC2)
                                               

  EC2 Instance (Your IP Hidden)                                    
                                                                   
                                                
    cloudflared      Random hostname: xyz.trycloudflare.com 
                                                
                                                                  
                                                                  
                                                
    Caddy :80                                                    
    + Basic Auth                                                 
    + Sec Headers                                                
                                                
                                                                  
            /grafana     → Grafana (auth required)            
            /prometheus  → Prometheus (auth required)         
            /pgadmin     → pgAdmin (auth required)            
            /meilisearch → Meilisearch (auth required)        
            /             → Portfolio Website (public)         
            /api/*        → FastAPI (public)                  
                                                                   
                                                
    CrowdSec         Parses Caddy logs                     
    + nftables       Auto-bans bad IPs                     
                                                
                                                                   
  Security Group: NO public 80/443                               

```

---

## Phase 1: Quick Tunnel (Current)

### Features
 **Complete IP hiding** - Origin server IP not exposed  
 **Zero cost** - Free Cloudflare Quick Tunnel  
 **Instant deployment** - No domain required  
 **Basic Auth** - Admin paths protected  
 **Security headers** - HSTS, CSP, X-Frame-Options  
 **CrowdSec integration** - Auto-ban malicious IPs  
 **fail2ban** - SSH protection  

 **Limitations:**
- Random hostname (changes on tunnel restart)
- No custom domain
- No Cloudflare WAF rules
- No geo-blocking via Cloudflare
- No Cloudflare Access (zero-trust)

### Quick Tunnel URL
After deployment, check the logs to get your random public URL:

```bash
docker logs cloudflared
```

Look for a line like:
```
2025-10-21T10:30:15Z INF +--------------------------------------------------------------------------------------------+
2025-10-21T10:30:15Z INF |  Your quick Tunnel has been created! Visit it at (it may take some time to be reachable):  |
2025-10-21T10:30:15Z INF |  https://abc-def-ghi-jkl.trycloudflare.com                                                |
2025-10-21T10:30:15Z INF +--------------------------------------------------------------------------------------------+
```

** This URL is temporary and will change if the container restarts.**

---

## Phase 2: Managed Tunnel with Domain (Future)

When you get a domain (can be free via Freenom, or $0.99/year from Namecheap), you can upgrade to a **managed Cloudflare Tunnel** with full security features:

### Additional Features in Phase 2
 **Custom domain** - your-site.com (stable)  
 **Cloudflare WAF** - Web Application Firewall rules  
 **Geo-blocking** - Block countries at edge  
 **Rate limiting** - DDoS protection rules  
 **Cloudflare Access** - Zero-trust access for admin paths  
 **Analytics** - Cloudflare dashboard insights  

### Steps for Phase 2 (When Ready)
1. Get a domain (free or paid)
2. Add domain to Cloudflare (free plan)
3. Create a named Cloudflare Tunnel in dashboard
4. Update `cloudflared` command with tunnel token
5. Remove Basic Auth (replace with Cloudflare Access)
6. Enable WAF + geo rules in Cloudflare dashboard

---

## Security Features

### 1. IP Hiding
-  EC2 public IP **never exposed** to internet
-  All HTTP/HTTPS traffic via Cloudflare edge
-  No direct access to origin server
-  DDoS protection at Cloudflare layer

### 2. Access Control

#### Public Endpoints (No Auth)
- `/` - Portfolio website
- `/api/*` - REST API endpoints
- `/docs` - API documentation
- `/health` - Health checks

#### Protected Endpoints (Basic Auth Required)
Username: `pretamane`  
Password: `#ThawZin2k77!`

- `/grafana` - Monitoring dashboards
- `/prometheus` - Metrics
- `/pgadmin` - Database admin
- `/meilisearch` - Search admin
- `/alertmanager` - Alert management

**Note:** MinIO console on port 9001 is currently direct-port access. To protect it, either:
- Add Caddy proxy with Basic Auth
- Use SSH tunnel: `ssh -L 9001:localhost:9001 ubuntu@ec2`
- Wait for Phase 2 and use Cloudflare Access

### 3. Security Headers (Applied to All Responses)
```
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
X-Content-Type-Options: nosniff
X-Frame-Options: SAMEORIGIN
Referrer-Policy: strict-origin-when-cross-origin
Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; ...
```

### 4. Host-Level Protection

#### CrowdSec
- Parses Caddy JSON logs
- Detects attack patterns (SQLi, XSS, scanners, brute-force)
- Auto-bans via nftables firewall
- Shares threat intel with community

Commands:
```bash
# View banned IPs
sudo cscli decisions list

# View recent alerts
sudo cscli alerts list

# Manually ban IP
sudo cscli decisions add --ip 1.2.3.4 --duration 4h --reason "manual ban"

# Unban IP
sudo cscli decisions delete --ip 1.2.3.4
```

#### fail2ban
- Monitors SSH login attempts
- Bans after 3 failed attempts
- 1-hour ban duration

Commands:
```bash
# Check status
sudo fail2ban-client status sshd

# Unban IP
sudo fail2ban-client set sshd unbanip 1.2.3.4
```

### 5. Prometheus Security Alerts
- High 4xx rate (scanning)
- High 5xx rate (DoS)
- Request rate spikes
- CPU/mem/disk exhaustion

---

## Access Credentials

### Admin Endpoints (Basic Auth)
- **Username:** `pretamane`
- **Password:** `#ThawZin2k77!`

### Service Credentials
| Service | Username | Password |
|---------|----------|----------|
| **Grafana** | pretamane | #ThawZin2k77! |
| **pgAdmin** | admin@pretamane.local | #ThawZin2k77! |
| **PostgreSQL** | pretamane | #ThawZin2k77! |
| **MinIO** | pretamane | #ThawZin2k77! |
| **Meilisearch** | API Key | pretamane_master_key_#ThawZin2k77! |

** Change these credentials in production!**

See: `docker-compose/.env` to update passwords.

---

## Deployment Steps

### Prerequisites
- EC2 instance running Ubuntu 22.04+
- Docker + Docker Compose installed
- AWS CLI configured

### Step 1: Deploy Updated Stack

```bash
# On your local machine, push changes to EC2
cd /home/guest/aws-to-opensource

# Deploy via SSM or git pull on EC2
# Option A: Via SSM (if you have aws-cli)
./scripts/security/deploy-security-updates.sh

# Option B: SSH to EC2 and pull
ssh ubuntu@54.179.230.219
cd /home/ubuntu/app
git pull origin main
```

### Step 2: Start Cloudflare Tunnel

```bash
# On EC2
cd /home/ubuntu/app/docker-compose

# Start services (including cloudflared)
docker-compose up -d

# Check cloudflared logs to get public URL
docker logs cloudflared

# Look for: https://xyz-abc-def.trycloudflare.com
```

**Save this URL** - this is your new public access point!

### Step 3: Lock Down Security Group

```bash
# On your local machine (replace with your home IP)
cd /home/guest/aws-to-opensource
./scripts/security/lockdown-ec2-security-group.sh i-0c151e9556e3d35e8 ap-southeast-1 YOUR_HOME_IP
```

This will:
-  Remove inbound 80/443 from 0.0.0.0/0
-  Keep AWS SSM access
-  Restrict SSH to YOUR_HOME_IP (if provided)

** After this step, your EC2 IP will NO LONGER respond to HTTP/HTTPS!**

### Step 4: Install Host Security (CrowdSec + fail2ban)

```bash
# SSH to EC2
ssh ubuntu@54.179.230.219

# Install CrowdSec
cd /home/ubuntu/app
sudo ./scripts/security/install-crowdsec.sh

# Install fail2ban
sudo ./scripts/security/install-fail2ban.sh
```

### Step 5: Verify Setup

```bash
# Test from local machine

# This should FAIL (good - IP is hidden):
curl -I http://54.179.230.219

# This should WORK (via Cloudflare Tunnel):
curl -I https://your-random-tunnel-url.trycloudflare.com

# Test protected endpoint (should require auth):
curl https://your-random-tunnel-url.trycloudflare.com/grafana

# Test with credentials:
curl -u pretamane:'#ThawZin2k77!' https://your-random-tunnel-url.trycloudflare.com/grafana
```

---

## Troubleshooting

### Tunnel Not Starting
```bash
# Check logs
docker logs cloudflared

# Common issues:
# - Cloudflare connectivity (check firewall)
# - Caddy not responding on :80
# - Container networking issue

# Restart tunnel
docker-compose restart cloudflared
```

### Can't Access via Tunnel URL
```bash
# 1. Verify cloudflared is running
docker ps | grep cloudflared

# 2. Check Caddy is responding internally
docker exec caddy wget -O- http://localhost:80

# 3. Verify tunnel URL in logs
docker logs cloudflared | grep trycloudflare.com

# 4. Test from EC2 itself
curl -H "Host: your-tunnel-url.trycloudflare.com" http://localhost:80
```

### Basic Auth Not Working
```bash
# Regenerate password hash
docker run --rm caddy:2-alpine caddy hash-password --plaintext '#ThawZin2k77!'

# Update Caddyfile with new hash
# Restart Caddy
docker-compose restart caddy
```

### CrowdSec Not Banning IPs
```bash
# Check CrowdSec is parsing logs
sudo cscli metrics

# Verify log file access
sudo ls -la /var/lib/docker/volumes/docker-compose_caddy-logs/_data/access.log

# Manual test ban
sudo cscli decisions add --ip 1.2.3.4 --duration 1h --reason "test"

# Verify ban in nftables
sudo nft list ruleset | grep 1.2.3.4
```

---

## Rotation & Maintenance

### Rotating Basic Auth Password

```bash
# 1. Generate new password hash
docker run --rm caddy:2-alpine caddy hash-password --plaintext 'NEW_PASSWORD'

# 2. Update Caddyfile with new hash
# 3. Update .env file
# 4. Restart services
docker-compose down
docker-compose up -d
```

### Rotating Cloudflare Tunnel URL (Phase 1)

The Quick Tunnel URL changes when the container restarts. To get a new URL:

```bash
docker-compose restart cloudflared
docker logs cloudflared | grep trycloudflare.com
```

**In Phase 2 (with domain), the tunnel is persistent** - URL never changes.

### Updating Security Rules

```bash
# Update Prometheus alerts
nano docker-compose/config/prometheus/alert-rules.yml

# Restart Prometheus
docker-compose restart prometheus

# Update CrowdSec scenarios
sudo cscli scenarios upgrade crowdsecurity/http-bad-user-agent

# Restart CrowdSec
sudo systemctl restart crowdsec
```

### Regular Maintenance Tasks

**Weekly:**
- [ ] Check Prometheus alerts for anomalies
- [ ] Review CrowdSec decisions: `sudo cscli decisions list`
- [ ] Check fail2ban bans: `sudo fail2ban-client status sshd`

**Monthly:**
- [ ] Update CrowdSec collections: `sudo cscli hub update && sudo cscli hub upgrade`
- [ ] Review Grafana dashboards for patterns
- [ ] Test backup restoration
- [ ] Rotate admin passwords

---

## Summary

### What You Have Now (Phase 1)
 EC2 IP completely hidden behind Cloudflare  
 Zero-budget solution  
 Basic Auth for admin tools  
 CrowdSec auto-banning malicious IPs  
 fail2ban SSH protection  
 Security headers enforced  
 Prometheus security alerts  
 No public ports 80/443 on EC2  

### Next Steps (Phase 2 - When You Get a Domain)
 Custom domain (stable URL)  
 Cloudflare WAF + geo-blocking  
 Cloudflare Access (zero-trust auth)  
 Advanced rate limiting  
 Full analytics dashboard  

---

**Questions?** Review the plan in `/c.plan.md` or check Phase 2 migration guide (when ready).

**Status:**  Your EC2 IP is now **hidden and protected**.



