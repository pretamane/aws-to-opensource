#!/bin/bash
# Complete CLI Setup for All Services
# Sets up command-line access to Prometheus, Grafana, MinIO, PostgreSQL, and Meilisearch

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
EC2_IP="54.179.230.219"
INSTANCE_ID="i-0c151e9556e3d35e8"
AWS_REGION="ap-southeast-1"

echo -e "${GREEN}=== Setting Up CLI Tools for Open-Source Stack ===${NC}\n"

# ============================================================================
# 1. MinIO Client (mc)
# ============================================================================
echo -e "${YELLOW}[1/5] Installing MinIO Client (mc)...${NC}"

if ! command -v mc &> /dev/null; then
    echo "Downloading MinIO Client..."
    curl -sL https://dl.min.io/client/mc/release/linux-amd64/mc -o mc
    chmod +x mc
    
    # Try to install system-wide, fallback to user bin
    if sudo mv mc /usr/local/bin/ 2>/dev/null; then
        echo "✓ Installed to /usr/local/bin/mc"
    else
        mkdir -p ~/bin
        mv mc ~/bin/
        export PATH="$HOME/bin:$PATH"
        echo "✓ Installed to ~/bin/mc"
        echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
    fi
else
    echo "✓ MinIO Client already installed"
fi

# Configure MinIO alias
echo "Configuring MinIO connection..."
mc alias set pretamane http://${EC2_IP}:9000 minioadmin minioadmin --api S3v4
echo -e "${GREEN}✓ MinIO Client configured${NC}\n"

# Test MinIO connection
echo "Testing MinIO connection..."
mc admin info pretamane || echo "Warning: Could not connect to MinIO"

# ============================================================================
# 2. AWS CLI for MinIO (S3-compatible)
# ============================================================================
echo -e "\n${YELLOW}[2/5] Configuring AWS CLI for MinIO...${NC}"

if ! command -v aws &> /dev/null; then
    echo -e "${RED}AWS CLI not found. Install with: sudo apt-get install awscli${NC}"
else
    # Create separate profile for MinIO
    aws configure set aws_access_key_id minioadmin --profile minio
    aws configure set aws_secret_access_key minioadmin --profile minio
    aws configure set region us-east-1 --profile minio
    aws configure set output json --profile minio
    
    echo -e "${GREEN}✓ AWS CLI configured for MinIO (use --profile minio --endpoint-url http://${EC2_IP}:9000)${NC}\n"
fi

# ============================================================================
# 3. PostgreSQL Client (psql)
# ============================================================================
echo -e "${YELLOW}[3/5] Setting up PostgreSQL Client...${NC}"

if ! command -v psql &> /dev/null; then
    echo "Installing PostgreSQL Client..."
    sudo apt-get update -qq
    sudo apt-get install -y postgresql-client
    echo -e "${GREEN}✓ PostgreSQL Client installed${NC}"
else
    echo "✓ PostgreSQL Client already installed"
fi

# Create connection alias for easier access
cat > ~/.pgpass << EOF
${EC2_IP}:5432:pretamane_db:app_user:$(aws ssm send-command \
    --instance-id ${INSTANCE_ID} \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["grep DB_PASSWORD /home/ubuntu/app/docker-compose/.env | cut -d= -f2"]' \
    --region ${AWS_REGION} \
    --query 'Command.CommandId' \
    --output text 2>/dev/null || echo "GET_PASSWORD_MANUALLY")
EOF
chmod 600 ~/.pgpass

echo -e "${GREEN}✓ PostgreSQL connection configured${NC}\n"

# ============================================================================
# 4. Create Helper Scripts
# ============================================================================
echo -e "${YELLOW}[4/5] Creating helper scripts...${NC}"

# Create quick access scripts directory
mkdir -p ~/stack-cli

# PostgreSQL helper
cat > ~/stack-cli/psql-connect.sh << 'PSQL_EOF'
#!/bin/bash
# Quick PostgreSQL connection
EC2_IP="54.179.230.219"

echo "Connecting to PostgreSQL on EC2..."
echo "Database: pretamane_db | User: app_user"
echo ""

# Get password from EC2 if not provided
if [ -z "$PGPASSWORD" ]; then
    echo "Getting password from EC2..."
    export PGPASSWORD=$(aws ssm send-command \
        --instance-id i-0c151e9556e3d35e8 \
        --document-name "AWS-RunShellScript" \
        --parameters 'commands=["grep DB_PASSWORD /home/ubuntu/app/docker-compose/.env | cut -d= -f2"]' \
        --region ap-southeast-1 \
        --output text \
        --query 'Command.CommandId' | xargs -I {} aws ssm get-command-invocation \
        --command-id {} \
        --instance-id i-0c151e9556e3d35e8 \
        --region ap-southeast-1 \
        --query 'StandardOutputContent' \
        --output text)
fi

psql -h ${EC2_IP} -p 5432 -U app_user -d pretamane_db
PSQL_EOF
chmod +x ~/stack-cli/psql-connect.sh

# MinIO helper
cat > ~/stack-cli/minio-info.sh << 'MINIO_EOF'
#!/bin/bash
# MinIO Quick Info Script

echo "=== MinIO Server Info ==="
mc admin info pretamane

echo -e "\n=== Buckets ==="
mc ls pretamane

echo -e "\n=== Bucket Sizes ==="
mc du pretamane/pretamane-data
mc du pretamane/pretamane-backup
MINIO_EOF
chmod +x ~/stack-cli/minio-info.sh

# Prometheus helper
cat > ~/stack-cli/prometheus-query.sh << 'PROM_EOF'
#!/bin/bash
# Prometheus Query Helper
EC2_IP="54.179.230.219"

if [ -z "$1" ]; then
    echo "Usage: $0 'query'"
    echo "Example: $0 'up'"
    echo "Example: $0 'http_requests_total'"
    exit 1
fi

QUERY="$1"
curl -s "http://${EC2_IP}/prometheus/api/v1/query?query=${QUERY}" | jq .
PROM_EOF
chmod +x ~/stack-cli/prometheus-query.sh

# Grafana helper
cat > ~/stack-cli/grafana-dashboards.sh << 'GRAFANA_EOF'
#!/bin/bash
# Grafana Dashboard Lister
EC2_IP="54.179.230.219"

echo "Note: You need to create an API key first:"
echo "  1. Go to http://${EC2_IP}/grafana"
echo "  2. Login (admin/admin123)"
echo "  3. Go to Configuration > API Keys"
echo "  4. Create a key and set it: export GRAFANA_API_KEY='your-key'"
echo ""

if [ -z "$GRAFANA_API_KEY" ]; then
    echo "Error: GRAFANA_API_KEY not set"
    exit 1
fi

echo "=== Grafana Dashboards ==="
curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
    "http://${EC2_IP}/grafana/api/search?type=dash-db" | jq .
GRAFANA_EOF
chmod +x ~/stack-cli/grafana-dashboards.sh

# Meilisearch helper
cat > ~/stack-cli/meilisearch-info.sh << 'MEILI_EOF'
#!/bin/bash
# Meilisearch Info Script
EC2_IP="54.179.230.219"

# Get API key from EC2
echo "Getting Meilisearch API key..."
MEILI_KEY=$(aws ssm send-command \
    --instance-id i-0c151e9556e3d35e8 \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["grep MEILISEARCH_API_KEY /home/ubuntu/app/docker-compose/.env | cut -d= -f2"]' \
    --region ap-southeast-1 \
    --output text \
    --query 'Command.CommandId' | xargs -I {} aws ssm get-command-invocation \
    --command-id {} \
    --instance-id i-0c151e9556e3d35e8 \
    --region ap-southeast-1 \
    --query 'StandardOutputContent' \
    --output text)

echo "=== Meilisearch Health ==="
curl -s "http://${EC2_IP}/meilisearch/health" | jq .

echo -e "\n=== Meilisearch Stats ==="
curl -s -H "Authorization: Bearer ${MEILI_KEY}" \
    "http://${EC2_IP}/meilisearch/stats" | jq .

echo -e "\n=== Indexes ==="
curl -s -H "Authorization: Bearer ${MEILI_KEY}" \
    "http://${EC2_IP}/meilisearch/indexes" | jq .
MEILI_EOF
chmod +x ~/stack-cli/meilisearch-info.sh

echo -e "${GREEN}✓ Helper scripts created in ~/stack-cli/${NC}\n"

# ============================================================================
# 5. Create Quick Reference Guide
# ============================================================================
echo -e "${YELLOW}[5/5] Creating Quick Reference Guide...${NC}"

cat > ~/stack-cli/README.md << 'README_EOF'
# Stack CLI Tools - Quick Reference

## MinIO (S3-Compatible Storage)

### Using MinIO Client (mc)
```bash
# Server info
mc admin info pretamane

# List buckets
mc ls pretamane

# List objects in bucket
mc ls pretamane/pretamane-data

# Copy file to MinIO
mc cp myfile.txt pretamane/pretamane-data/

# Copy file from MinIO
mc cp pretamane/pretamane-data/myfile.txt ./

# Remove file
mc rm pretamane/pretamane-data/myfile.txt

# Get bucket size
mc du pretamane/pretamane-data

# Watch for events
mc watch pretamane/pretamane-data

# Mirror directory
mc mirror ./local-folder pretamane/pretamane-data/folder

# Helper script
~/stack-cli/minio-info.sh
```

### Using AWS CLI
```bash
# List buckets
aws s3 ls --endpoint-url http://54.179.230.219:9000 --profile minio

# List objects
aws s3 ls s3://pretamane-data/ --endpoint-url http://54.179.230.219:9000 --profile minio

# Copy file
aws s3 cp file.txt s3://pretamane-data/ --endpoint-url http://54.179.230.219:9000 --profile minio

# Sync directory
aws s3 sync ./dir s3://pretamane-data/dir --endpoint-url http://54.179.230.219:9000 --profile minio
```

## PostgreSQL

### Using psql
```bash
# Quick connect (uses helper script)
~/stack-cli/psql-connect.sh

# Direct connection (replace PASSWORD)
psql -h 54.179.230.219 -p 5432 -U app_user -d pretamane_db

# Execute query from command line
PGPASSWORD='your-password' psql -h 54.179.230.219 -p 5432 -U app_user -d pretamane_db -c "SELECT * FROM contact_submissions LIMIT 5;"

# Execute SQL file
PGPASSWORD='your-password' psql -h 54.179.230.219 -p 5432 -U app_user -d pretamane_db -f query.sql

# Export to CSV
PGPASSWORD='your-password' psql -h 54.179.230.219 -p 5432 -U app_user -d pretamane_db -c "COPY (SELECT * FROM contact_submissions) TO STDOUT WITH CSV HEADER" > contacts.csv
```

### Common PostgreSQL Commands
```sql
-- Inside psql session

-- List all tables
\dt

-- Describe table structure
\d contact_submissions
\d documents
\d website_visitors

-- List all databases
\l

-- List all schemas
\dn

-- View table data
SELECT * FROM contact_submissions LIMIT 10;
SELECT * FROM documents WHERE contact_id = 'your-id';
SELECT COUNT(*) FROM contact_submissions;

-- Get database size
SELECT pg_size_pretty(pg_database_size('pretamane_db'));

-- Get table sizes
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Recent contacts
SELECT id, name, email, timestamp 
FROM contact_submissions 
ORDER BY timestamp DESC 
LIMIT 10;

-- Document upload statistics
SELECT 
    document_type,
    COUNT(*) as count,
    SUM(size) as total_size,
    AVG(size) as avg_size
FROM documents
GROUP BY document_type;

-- Exit psql
\q
```

## Prometheus

### Using HTTP API
```bash
# Query current metric
curl "http://54.179.230.219/prometheus/api/v1/query?query=up" | jq .

# Query with time range
curl "http://54.179.230.219/prometheus/api/v1/query_range?query=http_requests_total&start=2024-01-01T00:00:00Z&end=2024-01-01T23:59:59Z&step=1h" | jq .

# Get all metric names
curl "http://54.179.230.219/prometheus/api/v1/label/__name__/values" | jq .

# Check targets
curl "http://54.179.230.219/prometheus/api/v1/targets" | jq .

# Get alerts
curl "http://54.179.230.219/prometheus/api/v1/alerts" | jq .

# Helper script
~/stack-cli/prometheus-query.sh 'up'
~/stack-cli/prometheus-query.sh 'http_requests_total'
```

### Common Prometheus Queries
```bash
# All services up
curl -s "http://54.179.230.219/prometheus/api/v1/query?query=up" | jq '.data.result[] | {job: .metric.job, status: .value[1]}'

# HTTP request rate
curl -s "http://54.179.230.219/prometheus/api/v1/query?query=rate(http_requests_total[5m])" | jq .

# Contact submissions
curl -s "http://54.179.230.219/prometheus/api/v1/query?query=contact_submissions_total" | jq .

# Document uploads
curl -s "http://54.179.230.219/prometheus/api/v1/query?query=document_uploads_total" | jq .
```

## Grafana

### Using HTTP API
```bash
# First, create API key in Grafana UI
export GRAFANA_API_KEY="your-api-key"

# List dashboards
curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
    "http://54.179.230.219/grafana/api/dashboards/home" | jq .

# Get dashboard by UID
curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
    "http://54.179.230.219/grafana/api/dashboards/uid/dashboard-uid" | jq .

# List datasources
curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
    "http://54.179.230.219/grafana/api/datasources" | jq .

# Get org details
curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
    "http://54.179.230.219/grafana/api/org" | jq .

# Helper script
~/stack-cli/grafana-dashboards.sh
```

## Meilisearch

### Using HTTP API
```bash
# Get API key first
MEILI_KEY=$(aws ssm send-command \
    --instance-id i-0c151e9556e3d35e8 \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["grep MEILISEARCH_API_KEY /home/ubuntu/app/docker-compose/.env | cut -d= -f2"]' \
    --region ap-southeast-1 \
    --output text \
    --query 'Command.CommandId')

# Health check
curl "http://54.179.230.219/meilisearch/health"

# Get stats
curl -s -H "Authorization: Bearer $MEILI_KEY" \
    "http://54.179.230.219/meilisearch/stats" | jq .

# List indexes
curl -s -H "Authorization: Bearer $MEILI_KEY" \
    "http://54.179.230.219/meilisearch/indexes" | jq .

# Search documents
curl -s -X POST \
    -H "Authorization: Bearer $MEILI_KEY" \
    -H "Content-Type: application/json" \
    "http://54.179.230.219/meilisearch/indexes/documents/search" \
    -d '{"q": "your search query"}' | jq .

# Helper script
~/stack-cli/meilisearch-info.sh
```

## All-in-One Status Check
```bash
# Create a status check script
cat > ~/stack-cli/check-all.sh << 'STATUS_EOF'
#!/bin/bash
echo "=== Stack Services Status ==="
echo ""
echo "PostgreSQL:"
pg_isready -h 54.179.230.219 -p 5432 -U app_user && echo "✓ UP" || echo "✗ DOWN"
echo ""
echo "MinIO:"
mc admin info pretamane > /dev/null 2>&1 && echo "✓ UP" || echo "✗ DOWN"
echo ""
echo "Prometheus:"
curl -sf "http://54.179.230.219/prometheus/-/healthy" > /dev/null && echo "✓ UP" || echo "✗ DOWN"
echo ""
echo "Grafana:"
curl -sf "http://54.179.230.219/grafana/api/health" > /dev/null && echo "✓ UP" || echo "✗ DOWN"
echo ""
echo "Meilisearch:"
curl -sf "http://54.179.230.219/meilisearch/health" > /dev/null && echo "✓ UP" || echo "✗ DOWN"
STATUS_EOF

chmod +x ~/stack-cli/check-all.sh
```

## Tips

1. **Add to PATH**: Add helper scripts to your PATH
   ```bash
   echo 'export PATH="$HOME/stack-cli:$PATH"' >> ~/.bashrc
   source ~/.bashrc
   ```

2. **Aliases**: Create convenient aliases
   ```bash
   alias pg='~/stack-cli/psql-connect.sh'
   alias minioi='~/stack-cli/minio-info.sh'
   alias promq='~/stack-cli/prometheus-query.sh'
   alias checkstack='~/stack-cli/check-all.sh'
   ```

3. **Get Passwords**: All passwords are in `/home/ubuntu/app/docker-compose/.env` on EC2

4. **SSH Access**: Direct SSH if needed
   ```bash
   aws ssm start-session --target i-0c151e9556e3d35e8 --region ap-southeast-1
   ```
README_EOF

echo -e "${GREEN}✓ Quick reference guide created${NC}\n"

# ============================================================================
# Summary
# ============================================================================
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        CLI Tools Setup Complete! ✓            ║${NC}"
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo ""
echo "Tools Installed:"
echo "  ✓ MinIO Client (mc) - Object storage management"
echo "  ✓ AWS CLI - S3-compatible MinIO access"
echo "  ✓ PostgreSQL Client (psql) - Database access"
echo "  ✓ Helper Scripts - Quick access utilities"
echo ""
echo "Helper Scripts Location: ~/stack-cli/"
echo "  • psql-connect.sh       - Quick PostgreSQL connection"
echo "  • minio-info.sh         - MinIO status and buckets"
echo "  • prometheus-query.sh   - Query Prometheus metrics"
echo "  • grafana-dashboards.sh - List Grafana dashboards"
echo "  • meilisearch-info.sh   - Meilisearch stats"
echo ""
echo "Quick Start Commands:"
echo ""
echo "  PostgreSQL:"
echo "    ~/stack-cli/psql-connect.sh"
echo ""
echo "  MinIO:"
echo "    mc ls pretamane"
echo "    ~/stack-cli/minio-info.sh"
echo ""
echo "  Prometheus:"
echo "    ~/stack-cli/prometheus-query.sh 'up'"
echo ""
echo "  Meilisearch:"
echo "    ~/stack-cli/meilisearch-info.sh"
echo ""
echo "Documentation: ~/stack-cli/README.md"
echo ""
echo -e "${YELLOW}Note: Run 'source ~/.bashrc' to update your PATH${NC}"

