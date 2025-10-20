# MinIO Behind Caddy Proxy Plan

## Overview
This document outlines the plan for proxying MinIO through Caddy, addressing the challenges of subpath vs. subdomain approaches.

## Current State
- **Access Method**: Direct port access (http://54.179.230.219:9001)
- **Security Group**: Port 9001 open to internet
- **Configuration**: `MINIO_BROWSER_REDIRECT_URL` removed for direct access
- **Status**: Working but not ideal for production

## Problem Analysis

### Why MinIO Subpath is Difficult

MinIO's web console (built with React) has several challenges with subpath deployment:

1. **Hardcoded Asset Paths**: Frontend assets use absolute paths (`/static/...`)
2. **API Endpoints**: Console expects API at root path
3. **WebSocket Connections**: Real-time updates use WebSocket at specific paths
4. **Base URL Handling**: Limited support for `<base href>` tag
5. **JavaScript Routing**: Client-side routing assumes root path

### Previous Attempts
We tried:
- `handle_path /minio/*` with `uri strip_prefix /minio`
- `handle_response` with HTML rewriting
- `MINIO_BROWSER_REDIRECT_URL=/minio`

**Result**: Console loaded but assets 404'd, functionality broken.

## Recommended Solution: Subdomain

### Why Subdomain is Better

1. **Clean Separation**: MinIO console at `minio.pretamane.com`
2. **No Path Rewriting**: Assets load from root path
3. **Full Functionality**: All features work as designed
4. **Better Security**: Can apply different security policies
5. **Easier Maintenance**: No complex Caddy rewriting rules

### Implementation Plan

#### Phase 1: DNS Configuration

**Add DNS Records**:
```
Type: A Record
Name: minio
Value: 54.179.230.219
TTL: 300

Type: A Record
Name: s3
Value: 54.179.230.219
TTL: 300
```

**Result**:
- Console: `https://minio.pretamane.com`
- API: `https://s3.pretamane.com` (optional, for S3-compatible clients)

#### Phase 2: Update docker-compose.yml

```yaml
minio:
  image: minio/minio:latest
  container_name: minio
  restart: unless-stopped
  ports:
    # Remove public port exposure
    # - "9001:9001"
  environment:
    MINIO_ROOT_USER: ${S3_ACCESS_KEY}
    MINIO_ROOT_PASSWORD: ${S3_SECRET_KEY}
    # Set console address for internal access
    MINIO_BROWSER_REDIRECT_URL: https://minio.pretamane.com
    MINIO_SERVER_URL: https://s3.pretamane.com
  networks:
    - app-network
  volumes:
    - minio-data:/data
  command: server /data --console-address ":9001"
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
    interval: 30s
    timeout: 10s
    retries: 3
```

#### Phase 3: Update Caddyfile

```caddyfile
# MinIO Console (Web UI)
minio.pretamane.com {
    reverse_proxy minio:9001
    
    # Security headers
    header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
    }
    
    # Optional: Restrict access by IP
    # @allowed {
    #     remote_ip 1.2.3.4 5.6.7.8
    # }
    # handle @allowed {
    #     reverse_proxy minio:9001
    # }
    # handle {
    #     abort
    # }
}

# MinIO API (S3-compatible)
s3.pretamane.com {
    reverse_proxy minio:9000
    
    # Longer timeouts for large uploads
    reverse_proxy {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
        
        # Increase timeouts for large file operations
        transport http {
            dial_timeout 30s
            response_header_timeout 300s
        }
    }
}
```

#### Phase 4: Update Terraform Security Group

```hcl
# Remove public access to MinIO console port
# Delete or comment out:
# ingress {
#   description = "MinIO Console"
#   from_port   = 9001
#   to_port     = 9001
#   protocol    = "tcp"
#   cidr_blocks = ["0.0.0.0/0"]
# }

# MinIO now only accessible via Caddy (port 443)
```

#### Phase 5: Update Application Configuration

**For FastAPI app** (docker/api/shared/storage_service_minio.py):
```python
# Update MinIO client configuration
self.endpoint_url = os.environ.get('S3_ENDPOINT_URL', 'http://minio:9000')
# Internal Docker network communication - no change needed

# For external S3-compatible clients, use:
# endpoint_url = 'https://s3.pretamane.com'
```

**Environment Variables** (.env):
```bash
# Internal Docker network (for FastAPI)
S3_ENDPOINT_URL=http://minio:9000

# External access (for documentation)
MINIO_CONSOLE_URL=https://minio.pretamane.com
MINIO_API_URL=https://s3.pretamane.com
```

## Alternative: Keep Direct Port Access (Current Approach)

If subdomain is not feasible, keep current setup:

**Pros**:
- Works now
- No DNS configuration needed
- Simple setup

**Cons**:
- Less secure (additional open port)
- Not production-best-practice
- Requires firewall rule
- No HTTPS (unless using Elastic IP + domain)

**Improvements for Current Approach**:
```hcl
# Restrict MinIO console to specific IPs
ingress {
  description = "MinIO Console - Restricted"
  from_port   = 9001
  to_port     = 9001
  protocol    = "tcp"
  cidr_blocks = ["YOUR_IP/32"]  # Your office/home IP only
}
```

## Comparison: Subdomain vs. Subpath vs. Direct Port

| Aspect | Subdomain | Subpath | Direct Port |
|--------|-----------|---------|-------------|
| **Complexity** | Medium | High | Low |
| **Security** | Best | Good | Fair |
| **Functionality** | Full | Limited | Full |
| **HTTPS** | Yes | Yes | No* |
| **Maintenance** | Easy | Hard | Easy |
| **DNS Required** | Yes | No | No |
| **Port Exposure** | No | No | Yes |
| **Recommended** | YES | No | Development Only |

*Can add HTTPS with direct port, but requires additional configuration

## Migration Steps

### From Direct Port to Subdomain

1. **Set up DNS** (can do in parallel with testing)
2. **Test subdomain config locally** with docker-compose
3. **Update Terraform** to remove port 9001 ingress
4. **Deploy Caddyfile** with subdomain configuration
5. **Update MinIO environment variables**
6. **Restart services**: `docker-compose up -d`
7. **Test access**: https://minio.pretamane.com
8. **Update documentation** with new URLs

### Rollback Plan

If issues occur:
```bash
# 1. Revert Caddyfile
# 2. Revert docker-compose.yml (re-expose port 9001)
# 3. Revert Terraform (re-add port 9001 ingress)
# 4. Restart: docker-compose up -d
```

## Testing Checklist

- [ ] Console accessible: https://minio.pretamane.com
- [ ] Login works with credentials
- [ ] Bucket list loads
- [ ] File upload works
- [ ] File download works
- [ ] API accessible: https://s3.pretamane.com
- [ ] FastAPI can upload/download files
- [ ] No port 9001 publicly accessible
- [ ] HTTPS certificate valid
- [ ] WebSocket connections work (real-time updates)

## Security Considerations

### Subdomain Approach
- MinIO console only accessible via HTTPS
- No direct port exposure
- Can add IP restrictions in Caddy
- Can add authentication middleware
- Separate subdomain allows different security policies

### Additional Security Measures
```caddyfile
minio.pretamane.com {
    # Basic auth (optional additional layer)
    basicauth {
        admin $2a$14$...hashed_password...
    }
    
    # Rate limiting
    rate_limit {
        zone minio {
            key {remote_host}
            events 100
            window 1m
        }
    }
    
    reverse_proxy minio:9001
}
```

## Performance Considerations

- **Latency**: Minimal overhead from Caddy proxy (<1ms)
- **Throughput**: Caddy handles large file uploads efficiently
- **Caching**: Can add caching for static assets
- **HTTP/2**: Enabled by default with Caddy HTTPS

## Cost Impact

- **No additional costs**: Same EC2 instance, same resources
- **DNS**: Already covered if using domain for main site
- **Bandwidth**: No change (same data transfer)

## Timeline

- **DNS Setup**: 1-24 hours (propagation)
- **Configuration**: 30 minutes
- **Testing**: 30 minutes
- **Total**: 2-25 hours

## Recommendation

**Use Subdomain Approach** when domain is available:
1. More secure
2. Better user experience
3. Full MinIO functionality
4. Production-ready
5. Easier to maintain

**Keep Direct Port** only for:
- Development/testing
- No domain available
- Temporary deployment

## Next Steps

1. **Wait for domain** (from TLS/Domain plan)
2. **Configure DNS** for minio subdomain
3. **Update Terraform** to close port 9001
4. **Update Caddyfile** with subdomain config
5. **Update docker-compose.yml** with environment variables
6. **Deploy and test**

## References

- MinIO Console Configuration: https://min.io/docs/minio/linux/reference/minio-server/minio-server.html#minio-console
- Caddy Reverse Proxy: https://caddyserver.com/docs/caddyfile/directives/reverse_proxy
- S3 API Documentation: https://docs.aws.amazon.com/AmazonS3/latest/API/Welcome.html

