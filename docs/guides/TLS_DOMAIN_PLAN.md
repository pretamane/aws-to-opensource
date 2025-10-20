# TLS/Domain Setup Plan for Caddy

## Overview
This document outlines the plan for adding TLS/HTTPS support with automatic certificate management using Caddy and Let's Encrypt ACME.

## Current State
- **Status**: HTTP only (port 80)
- **Access**: Direct IP address (http://54.179.230.219)
- **Security**: No encryption for data in transit
- **Certificates**: None

## Prerequisites

### 1. Domain Name
**Required**: A registered domain name pointing to the EC2 instance

**Options**:
- Purchase a domain from a registrar (Namecheap, Google Domains, AWS Route 53, etc.)
- Use a free subdomain service (e.g., afraid.org, no-ip.com)
- Use AWS Route 53 for domain management

**DNS Configuration**:
```
Type: A Record
Name: @ (or your subdomain)
Value: 54.179.230.219 (EC2 public IP)
TTL: 300 (5 minutes)
```

**Example**:
```
pretamane.com        A    54.179.230.219
www.pretamane.com    A    54.179.230.219
```

### 2. Firewall Rules
**Current**: Port 80 (HTTP) is open
**Required**: Port 443 (HTTPS) must be open

**Security Group Update** (terraform-ec2/main.tf):
```hcl
# Add HTTPS ingress rule
ingress {
  description = "HTTPS"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

## Implementation Plan

### Phase 1: Basic HTTPS with Let's Encrypt

**Step 1**: Update Caddyfile for automatic HTTPS
```caddyfile
# Replace IP-based config with domain-based config
pretamane.com, www.pretamane.com {
    # Caddy automatically enables HTTPS with Let's Encrypt
    
    # Email for Let's Encrypt notifications
    tls admin@pretamane.com
    
    # Existing reverse proxy configuration
    # ... (keep all current routes)
}
```

**Step 2**: Update docker-compose.yml to expose port 443
```yaml
caddy:
  ports:
    - "80:80"
    - "443:443"    # Add HTTPS port
    - "443:443/udp" # HTTP/3 support (optional)
  volumes:
    - caddy-data:/data        # Stores certificates
    - caddy-config:/config    # Stores Caddy config
```

**Step 3**: Deploy and verify
```bash
# Apply Terraform changes for port 443
cd terraform-ec2
terraform apply

# Update Caddyfile on EC2
# Restart Caddy
docker-compose restart caddy

# Verify certificate
curl -I https://pretamane.com
```

### Phase 2: Security Hardening

**Step 1**: Enable HSTS (HTTP Strict Transport Security)
```caddyfile
pretamane.com {
    header {
        # Enable HSTS with 1-year max-age
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        
        # Additional security headers
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
}
```

**Step 2**: Force HTTPS redirect
```caddyfile
# Automatic HTTP -> HTTPS redirect (Caddy does this by default)
# But can be explicit:
http://pretamane.com {
    redir https://pretamane.com{uri} permanent
}
```

**Step 3**: Configure TLS versions and ciphers
```caddyfile
pretamane.com {
    tls admin@pretamane.com {
        protocols tls1.2 tls1.3
        ciphers TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
    }
}
```

### Phase 3: Certificate Management

**Automatic Renewal**:
- Caddy automatically renews certificates before expiration
- No cron jobs or manual intervention needed
- Certificates stored in `/data/caddy/certificates/`

**Monitoring**:
```bash
# Check certificate expiration
docker exec caddy caddy list-certificates

# View Caddy logs
docker logs caddy --tail 100
```

**Backup Certificates**:
```bash
# Include in backup script
tar czf /backup/caddy-certs-$(date +%Y%m%d).tar.gz \
  /home/ubuntu/app/docker-compose/caddy-data/
```

## Alternative: Staging Environment

For testing, use Let's Encrypt staging server:
```caddyfile
pretamane.com {
    tls admin@pretamane.com {
        ca https://acme-staging-v02.api.letsencrypt.org/directory
    }
}
```

## Rollback Plan

If issues occur:
1. Revert Caddyfile to IP-based HTTP configuration
2. Restart Caddy: `docker-compose restart caddy`
3. Remove port 443 from security group if needed
4. Investigate logs: `docker logs caddy`

## Testing Checklist

After deployment:
- [ ] HTTPS accessible: https://pretamane.com
- [ ] HTTP redirects to HTTPS
- [ ] Certificate valid (check in browser)
- [ ] No mixed content warnings
- [ ] HSTS header present: `curl -I https://pretamane.com | grep Strict`
- [ ] SSL Labs test: https://www.ssllabs.com/ssltest/
- [ ] All services accessible via HTTPS
- [ ] Grafana: https://pretamane.com/grafana
- [ ] Prometheus: https://pretamane.com/prometheus
- [ ] API: https://pretamane.com/docs

## Cost Considerations

- **Let's Encrypt**: FREE (certificates)
- **Domain Name**: $10-15/year (varies by registrar)
- **AWS Route 53** (optional): $0.50/month per hosted zone + $0.40 per million queries
- **No additional EC2 costs**: Same instance handles HTTPS

## Timeline

- **Domain Setup**: 1-24 hours (DNS propagation)
- **Implementation**: 30 minutes
- **Testing**: 15 minutes
- **Total**: 2-25 hours (mostly waiting for DNS)

## Next Steps

1. **Acquire domain name**
2. **Configure DNS** to point to EC2 IP
3. **Wait for DNS propagation** (check with `nslookup pretamane.com`)
4. **Update Terraform** to open port 443
5. **Update Caddyfile** with domain configuration
6. **Deploy and test**

## References

- Caddy Automatic HTTPS: https://caddyserver.com/docs/automatic-https
- Let's Encrypt: https://letsencrypt.org/
- HSTS Preload: https://hstspreload.org/
- SSL Labs Testing: https://www.ssllabs.com/ssltest/

