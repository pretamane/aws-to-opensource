# CLI Tools Setup - Complete 

## Overview
All CLI tools are now installed and configured for direct command-line access to your stack services.

---

##  What's Been Set Up

### 1. **MinIO Client (mc)** - S3-Compatible Storage CLI
- **Installed**: `/usr/local/bin/mc`
- **Configured**: Alias `pretamane` points to your MinIO server
- **Usage**: `mc ls pretamane`, `mc cp file.txt pretamane/pretamane-data/`

### 2. **AWS CLI** - Alternative MinIO Access
- **Configured**: Profile `minio` with credentials
- **Usage**: `aws s3 ls --endpoint-url http://54.179.230.219:9000 --profile minio`

### 3. **PostgreSQL Client (psql)** - Database CLI
- **Installed**: System `psql` command
- **Connection**: Direct access to `pretamane_db` on EC2
- **Usage**: `psql -h 54.179.230.219 -p 5432 -U app_user -d pretamane_db`

### 4. **Prometheus API** - HTTP Queries
- **Access**: Direct HTTP API calls via `curl`
- **Usage**: `curl "http://54.179.230.219/prometheus/api/v1/query?query=up"`

### 5. **Grafana API** - Dashboard Management
- **Access**: HTTP API with authentication
- **Usage**: `curl -H "Authorization: Bearer $API_KEY" "http://54.179.230.219/grafana/api/dashboards/home"`

### 6. **Meilisearch API** - Search Engine CLI
- **Access**: HTTP API with API key
- **Usage**: `curl -H "Authorization: Bearer $MEILI_KEY" "http://54.179.230.219/meilisearch/stats"`

---

##  Helper Scripts Location: `~/stack-cli/`

### Quick Access Scripts:
1. **`psql-connect.sh`** - One-command PostgreSQL connection
2. **`minio-info.sh`** - Display MinIO server info and buckets
3. **`prometheus-query.sh`** - Query Prometheus metrics easily
4. **`grafana-dashboards.sh`** - List all Grafana dashboards
5. **`meilisearch-info.sh`** - Get Meilisearch stats and indexes
6. **`check-all.sh`** - Check status of all services at once

### Documentation:
- **`~/stack-cli/README.md`** - Complete reference guide with examples
- **`/home/guest/aws-to-opensource/scripts/postgres-examples.sh`** - PostgreSQL CLI examples

---

##  Quick Start Commands

### PostgreSQL
```bash
# Quick connect (automatic password retrieval)
~/stack-cli/psql-connect.sh

# Direct connection (manual password)
export PGPASSWORD='your-password'
psql -h 54.179.230.219 -p 5432 -U app_user -d pretamane_db

# List all tables
psql -h 54.179.230.219 -p 5432 -U app_user -d pretamane_db -c '\dt'

# Count all contacts
psql -h 54.179.230.219 -p 5432 -U app_user -d pretamane_db -c 'SELECT COUNT(*) FROM contact_submissions;'

# Export to CSV
psql -h 54.179.230.219 -p 5432 -U app_user -d pretamane_db -c "COPY (SELECT * FROM contact_submissions) TO STDOUT WITH CSV HEADER" > contacts.csv

# Get recent contacts with documents
psql -h 54.179.230.219 -p 5432 -U app_user -d pretamane_db -c "
SELECT 
    c.name, 
    c.email, 
    COUNT(d.id) as docs,
    pg_size_pretty(COALESCE(SUM(d.size), 0)::bigint) as size
FROM contact_submissions c
LEFT JOIN documents d ON c.id = d.contact_id
GROUP BY c.name, c.email
ORDER BY COUNT(d.id) DESC
LIMIT 10;"
```

### MinIO
```bash
# List all buckets
mc ls pretamane

# List files in bucket
mc ls pretamane/pretamane-data

# Upload file
mc cp myfile.txt pretamane/pretamane-data/

# Download file
mc cp pretamane/pretamane-data/myfile.txt ./

# Get bucket size
mc du pretamane/pretamane-data

# Server info
~/stack-cli/minio-info.sh

# Using AWS CLI
aws s3 ls --endpoint-url http://54.179.230.219:9000 --profile minio
```

### Prometheus
```bash
# Check which services are up
~/stack-cli/prometheus-query.sh 'up'

# Get HTTP request metrics
curl -s "http://54.179.230.219/prometheus/api/v1/query?query=http_requests_total" | jq .

# Get contact submissions
curl -s "http://54.179.230.219/prometheus/api/v1/query?query=contact_submissions_total" | jq .

# Check all targets
curl -s "http://54.179.230.219/prometheus/api/v1/targets" | jq .
```

### Meilisearch
```bash
# Get stats
~/stack-cli/meilisearch-info.sh

# Search documents
curl -X POST \
  -H "Authorization: Bearer $MEILI_KEY" \
  -H "Content-Type: application/json" \
  "http://54.179.230.219/meilisearch/indexes/documents/search" \
  -d '{"q": "your search"}'
```

### Grafana
```bash
# First, create API key in Grafana UI:
# http://54.179.230.219/grafana > Configuration > API Keys

export GRAFANA_API_KEY="your-key"

# List dashboards
~/stack-cli/grafana-dashboards.sh

# Get datasources
curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
  "http://54.179.230.219/grafana/api/datasources" | jq .
```

---

##  PostgreSQL - Advanced Examples

### Get Database Statistics
```sql
-- Inside psql session or via -c flag

-- Database size
SELECT pg_size_pretty(pg_database_size('pretamane_db'));

-- Table sizes
SELECT 
    tablename,
    pg_size_pretty(pg_total_relation_size('public.'||tablename)) as size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size('public.'||tablename) DESC;

-- Index sizes
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;
```

### Query Performance
```sql
-- Enable timing
\timing

-- Analyze query plan
EXPLAIN ANALYZE SELECT * FROM contact_submissions WHERE email LIKE '%@example.com%';

-- View slow queries (if pg_stat_statements enabled)
SELECT query, calls, total_time, mean_time 
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;
```

### Data Management
```sql
-- Vacuum and analyze tables
VACUUM ANALYZE contact_submissions;
VACUUM ANALYZE documents;

-- Check table bloat
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    n_live_tup,
    n_dead_tup
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;
```

---

##  PostgreSQL - Interactive Commands

Once inside `psql` session:
```
\dt                           -- List all tables
\d table_name                 -- Describe table structure
\d+ table_name                -- Detailed table info with size
\di                           -- List all indexes
\dv                           -- List all views
\df                           -- List all functions
\l                            -- List all databases
\dn                           -- List all schemas
\du                           -- List all users/roles
\timing                       -- Toggle query timing
\x                            -- Toggle expanded display (better for wide tables)
\q                            -- Quit psql
\?                            -- Help on psql commands
\h SQL_COMMAND                -- Help on SQL command
\e                            -- Edit query in $EDITOR
\i filename.sql               -- Execute SQL from file
\o filename.txt               -- Send output to file
\! command                    -- Execute shell command
```

---

##  Getting Passwords

All passwords are stored in the EC2 environment file:

```bash
# Via SSM
aws ssm send-command \
  --instance-id i-0c151e9556e3d35e8 \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["cat /home/ubuntu/app/docker-compose/.env"]' \
  --region ap-southeast-1

# Or via SSH
ssh ubuntu@54.179.230.219
cat ~/app/docker-compose/.env
```

### Current Credentials:
- **PostgreSQL**: `DB_PASSWORD` in `.env`
- **Meilisearch**: `MEILISEARCH_API_KEY` in `.env`
- **MinIO**: `minioadmin` / `minioadmin` (default)
- **Grafana**: `admin` / `admin123` (web UI)

---

##  Troubleshooting

### PostgreSQL Connection Issues
```bash
# Test connection
pg_isready -h 54.179.230.219 -p 5432 -U app_user

# Check if PostgreSQL is accessible
telnet 54.179.230.219 5432

# Verify password
grep DB_PASSWORD ~/app/docker-compose/.env  # (on EC2)
```

### MinIO Connection Issues
```bash
# Check if MinIO port is open
curl http://54.179.230.219:9000

# Test connection
mc admin info pretamane

# Reconfigure alias
mc alias set pretamane http://54.179.230.219:9000 minioadmin minioadmin --api S3v4
```

### API Access Issues
```bash
# Test Prometheus
curl -s http://54.179.230.219/prometheus/-/healthy

# Test Grafana
curl -s http://54.179.230.219/grafana/api/health

# Test Meilisearch
curl -s http://54.179.230.219/meilisearch/health
```

---

##  Additional Resources

### Official Documentation:
- **PostgreSQL**: https://www.postgresql.org/docs/current/app-psql.html
- **MinIO Client**: https://min.io/docs/minio/linux/reference/minio-mc.html
- **Prometheus API**: https://prometheus.io/docs/prometheus/latest/querying/api/
- **Grafana API**: https://grafana.com/docs/grafana/latest/http_api/
- **Meilisearch API**: https://docs.meilisearch.com/reference/api/

### Files Created:
- `/usr/local/bin/mc` - MinIO Client binary
- `~/stack-cli/` - Helper scripts directory
- `~/stack-cli/README.md` - Complete reference guide
- `~/.pgpass` - PostgreSQL password file (chmod 600)
- `~/.aws/credentials` - AWS/MinIO credentials (minio profile)
- `/home/guest/aws-to-opensource/scripts/setup-cli-tools.sh` - Setup script
- `/home/guest/aws-to-opensource/scripts/postgres-examples.sh` - PostgreSQL examples

---

##  Next Steps

1. **Set your PostgreSQL password**:
   ```bash
   export PGPASSWORD='get-from-ec2-env-file'
   ```

2. **Test PostgreSQL connection**:
   ```bash
   ~/stack-cli/psql-connect.sh
   ```

3. **Test MinIO**:
   ```bash
   mc ls pretamane
   ```

4. **Query Prometheus**:
   ```bash
   ~/stack-cli/prometheus-query.sh 'up'
   ```

5. **Check all services**:
   ```bash
   ~/stack-cli/check-all.sh
   ```

---

##  Summary

You now have full CLI access to:
-  PostgreSQL database (psql)
-  MinIO object storage (mc + aws s3)
-  Prometheus metrics (HTTP API)
-  Grafana dashboards (HTTP API)
-  Meilisearch (HTTP API)

All commands can be run directly from your terminal, just like you would with AWS CLI or Terraform!

**Documentation**: `~/stack-cli/README.md`  
**Helper Scripts**: `~/stack-cli/`  
**Examples**: `/home/guest/aws-to-opensource/scripts/postgres-examples.sh`

