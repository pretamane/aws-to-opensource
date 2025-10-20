# Quick Access Guide - Live System

## Frontend Pages

### Portfolio & Information
- **Homepage**: http://54.179.230.219/
- **About**: http://54.179.230.219/pages/about.html
- **Services**: http://54.179.230.219/pages/services.html
- **Contact**: http://54.179.230.219/pages/contact.html

### API-Driven Management Pages
- **Analytics Dashboard**: http://54.179.230.219/pages/analytics.html
  - View business metrics, contact trends, document statistics
  - Real-time charts and visualizations
  
- **Document Upload**: http://54.179.230.219/pages/upload.html
  - Upload files with drag-and-drop
  - Associate documents with contacts
  - Track upload progress
  
- **Search Interface**: http://54.179.230.219/pages/search.html
  - Full-text search across all documents
  - Advanced filtering by type, date, contact
  - Powered by Meilisearch
  
- **System Health**: http://54.179.230.219/pages/health.html
  - Monitor all backend services
  - View database statistics
  - Check system metrics

## Backend Services

### API Documentation
- **Swagger UI**: http://54.179.230.219/docs
- **ReDoc**: http://54.179.230.219/redoc
- **OpenAPI JSON**: http://54.179.230.219/openapi.json

### Monitoring Stack
- **Grafana**: http://54.179.230.219/grafana/
  - Username: `admin`
  - Password: `admin123`
  - Dashboards for metrics and logs

- **Prometheus**: http://54.179.230.219/prometheus/
  - Metrics collection and querying
  - Service targets: http://54.179.230.219/prometheus/targets

### Data Services
- **Meilisearch**: http://54.179.230.219/meilisearch/
  - Search engine admin interface
  
- **MinIO Console**: http://54.179.230.219:9001/
  - S3-compatible object storage
  - Username: `minioadmin`
  - Password: `minioadmin`

- **pgAdmin**: http://54.179.230.219/pgadmin/
  - PostgreSQL database administration
  - Email: `admin@admin.com`
  - Password: `admin123`

## Key API Endpoints

### Contact Management
```bash
# Submit contact form
POST http://54.179.230.219/contact

# Get stats
GET http://54.179.230.219/stats
```

### Document Management
```bash
# Upload document
POST http://54.179.230.219/documents/upload

# Search documents
POST http://54.179.230.219/documents/search

# Get contact documents
GET http://54.179.230.219/contacts/{contact_id}/documents
```

### Analytics
```bash
# Get insights
GET http://54.179.230.219/analytics/insights

# System health
GET http://54.179.230.219/health

# Prometheus metrics
GET http://54.179.230.219/metrics
```

## Quick Tests

### Test Contact Form
```bash
curl -X POST http://54.179.230.219/contact \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "email": "test@example.com",
    "message": "Testing the system",
    "company": "Test Corp",
    "service": "Cloud Engineering",
    "budget": "$5000-$10000"
  }'
```

### Test Health Check
```bash
curl http://54.179.230.219/health | jq
```

### Test Search (after uploading documents)
```bash
curl -X POST http://54.179.230.219/documents/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "test",
    "limit": 10
  }' | jq
```

## CLI Access

### PostgreSQL
```bash
# Connect to database
~/stack-cli/psql-connect.sh

# Or manually
psql -h 54.179.230.219 -p 5432 -U app_user -d pretamane_db
```

### MinIO
```bash
# List buckets
mc ls pretamane

# Upload file
mc cp myfile.txt pretamane/pretamane-data/
```

### Meilisearch
```bash
# Get stats
~/stack-cli/meilisearch-info.sh
```

### Prometheus
```bash
# Query metrics
~/stack-cli/prometheus-query.sh 'up'
```

## Deployment Commands

### Deploy Frontend Changes
```bash
cd /home/ubuntu/app/pretamane-website
git pull origin main
```

### Restart Services
```bash
cd /home/ubuntu/app/docker-compose
docker-compose restart [service-name]

# Restart specific services
docker-compose restart fastapi-app
docker-compose restart caddy
docker-compose restart grafana
```

### View Logs
```bash
cd /home/ubuntu/app/docker-compose

# All services
docker-compose logs -f

# Specific service
docker-compose logs -f fastapi-app
docker-compose logs -f postgresql
docker-compose logs -f meilisearch
```

### Check Service Status
```bash
cd /home/ubuntu/app/docker-compose
docker-compose ps
```

## EC2 Instance Access

### SSH (if key available)
```bash
ssh -i your-key.pem ubuntu@54.179.230.219
```

### AWS SSM Session Manager
```bash
aws ssm start-session \
  --target i-0c151e9556e3d35e8 \
  --region ap-southeast-1
```

### Execute Remote Commands
```bash
aws ssm send-command \
  --instance-id i-0c151e9556e3d35e8 \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["your-command-here"]' \
  --region ap-southeast-1
```

## Troubleshooting

### Check Container Logs
```bash
# Via SSM
aws ssm send-command \
  --instance-id i-0c151e9556e3d35e8 \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["cd /home/ubuntu/app/docker-compose && docker-compose logs --tail=50 fastapi-app"]' \
  --region ap-southeast-1
```

### Restart All Services
```bash
aws ssm send-command \
  --instance-id i-0c151e9556e3d35e8 \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["cd /home/ubuntu/app/docker-compose && docker-compose restart"]' \
  --region ap-southeast-1
```

### Check Disk Space
```bash
aws ssm send-command \
  --instance-id i-0c151e9556e3d35e8 \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["df -h"]' \
  --region ap-southeast-1
```

## System Information

- **Instance ID**: i-0c151e9556e3d35e8
- **Region**: ap-southeast-1 (Singapore)
- **Instance Type**: t3.medium
- **Public IP**: 54.179.230.219
- **Operating System**: Ubuntu 22.04 LTS
- **Docker Compose Version**: Latest
- **Architecture**: Open-Source Stack (PostgreSQL, Meilisearch, MinIO)

## Cost Estimate

- **EC2 Instance**: ~$30/month (t3.medium on-demand)
- **EBS Storage**: ~$2/month (30GB gp3)
- **Data Transfer**: First 100GB free
- **Total**: ~$32/month

Compare to original AWS EKS stack: ~$330/month (90% cost savings)

