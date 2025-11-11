# Credentials Update Report

## Date
October 21, 2025

## Summary
All default credentials across the open-source stack have been updated to use consistent username and password.

## New Credentials

**Username:** `pretamane`  
**Password:** `#ThawZin2k77!`

## Services Updated

### 1. PostgreSQL Database
- **Username:** `pretamane`
- **Password:** `#ThawZin2k77!`
- **Database:** `pretamane_db`
- **Access:** Via pgAdmin or psql client
- **URL:** `postgresql://pretamane:#ThawZin2k77!@postgresql:5432/pretamane_db`

### 2. pgAdmin Web Interface
- **Email:** `pretamane@localhost.com`
- **Password:** `#ThawZin2k77!`
- **URL:** `https://54-179-230-219.sslip.io/pgadmin`

### 3. Grafana Monitoring
- **Username:** `pretamane`
- **Password:** `#ThawZin2k77!`
- **URL:** `https://54-179-230-219.sslip.io/grafana`

### 4. MinIO Object Storage
- **Username (Access Key):** `pretamane`
- **Password (Secret Key):** `#ThawZin2k77!`
- **Console URL:** `http://54.179.230.219:9001`
- **S3 API Endpoint:** `http://54.179.230.219:9000`

### 5. Meilisearch
- **API Key:** `pretamane_2k77_master_key_secure`
- **URL:** `https://54-179-230-219.sslip.io/meilisearch`

## Files Modified

1. **`.env` file created** - `/home/guest/aws-to-opensource/docker-compose/.env`
   - Contains all environment variables
   - Not committed to git (in .gitignore)
   - Stores credentials securely

2. **PostgreSQL Init Script** - `docker-compose/init-scripts/postgres/01-init-schema.sql`
   - Updated database user from `app_user` to `pretamane`
   - Granted all necessary permissions

## Deployment Steps

### Local Development/Testing

```bash
cd /home/guest/aws-to-opensource/docker-compose

# Pull latest images
docker-compose pull

# Recreate services with new credentials
docker-compose down -v  # WARNING: This deletes all data
docker-compose up -d

# Verify services are running
docker-compose ps

# Check logs
docker-compose logs -f
```

### EC2 Production Deployment

```bash
# Connect to EC2 instance
EC2_IP="54.179.230.219"
INSTANCE_ID="i-0c151e9556e3d35e8"

# Via SSH (if you have the key)
ssh -i your-key.pem ubuntu@$EC2_IP

# Or via SSM
aws ssm start-session --target $INSTANCE_ID --region ap-southeast-1

# On the EC2 instance:
cd /home/ubuntu/app/docker-compose

# Copy the new .env file (you'll need to transfer it)
# Option 1: Use scp
# scp -i your-key.pem /home/guest/aws-to-opensource/docker-compose/.env ubuntu@$EC2_IP:/home/ubuntu/app/docker-compose/

# Option 2: Recreate it on EC2
nano .env
# Paste the content from the local .env file

# Update the init script
nano init-scripts/postgres/01-init-schema.sql
# Change app_user to pretamane on lines 226-228

# Recreate services with new credentials
sudo docker-compose down -v  # WARNING: This deletes all data
sudo docker-compose up -d

# Verify
sudo docker-compose ps
sudo docker-compose logs -f
```

## Access URLs (After Deployment)

### HTTPS (Recommended)
- **Homepage:** `https://54-179-230-219.sslip.io`
- **API Docs:** `https://54-179-230-219.sslip.io/docs`
- **Grafana:** `https://54-179-230-219.sslip.io/grafana`
- **pgAdmin:** `https://54-179-230-219.sslip.io/pgadmin`
- **Prometheus:** `https://54-179-230-219.sslip.io/prometheus`
- **Meilisearch:** `https://54-179-230-219.sslip.io/meilisearch`

### HTTP (Direct Ports)
- **MinIO Console:** `http://54.179.230.219:9001`
- **Prometheus:** `http://54.179.230.219:9090`
- **Alertmanager:** `http://54.179.230.219:9093`

## CLI Access Examples

### PostgreSQL
```bash
# From within Docker network
docker-compose exec postgresql psql -U pretamane -d pretamane_db

# From host with password prompt
psql -h localhost -U pretamane -d pretamane_db

# Connection string
postgresql://pretamane:#ThawZin2k77!@localhost:5432/pretamane_db
```

### MinIO (S3 API)
```bash
# Configure MinIO client
mc alias set pretamane-minio http://54.179.230.219:9000 pretamane '#ThawZin2k77!'

# List buckets
mc ls pretamane-minio

# AWS CLI (S3-compatible)
aws s3 --endpoint-url http://54.179.230.219:9000 \
  --profile pretamane \
  ls s3://pretamane-data/
```

### Meilisearch
```bash
# Search documents
curl -X POST 'https://54-179-230-219.sslip.io/meilisearch/indexes/documents/search' \
  -H 'Authorization: Bearer pretamane_2k77_master_key_secure' \
  -H 'Content-Type: application/json' \
  --data-binary '{"q": "test"}'
```

### Grafana API
```bash
# Get dashboards
curl -u pretamane:'#ThawZin2k77!' \
  https://54-179-230-219.sslip.io/grafana/api/dashboards/home
```

## Security Notes

### Important Warnings
1. **Special Characters in Password:** The password contains `#` and `!` which are special shell characters. Always:
   - Use single quotes in shell commands: `'#ThawZin2k77!'`
   - URL-encode for connection strings: `%23ThawZin2k77%21`
   - Escape properly in configuration files

2. **Data Loss Warning:** Running `docker-compose down -v` will delete all data including:
   - PostgreSQL database contents
   - Meilisearch indexes
   - MinIO stored objects
   - Grafana dashboards
   - All persistent volumes

3. **Backup Before Recreating:**
   ```bash
   # Backup PostgreSQL
   docker-compose exec postgresql pg_dump -U pretamane pretamane_db > backup.sql
   
   # Backup MinIO data
   mc mirror pretamane-minio/pretamane-data ./minio-backup/
   ```

### Best Practices
1. **Store .env Securely:**
   - Never commit to git (already in .gitignore)
   - Restrict file permissions: `chmod 600 .env`
   - Use AWS Secrets Manager for production

2. **Rotate Credentials Regularly:**
   - Change passwords every 90 days
   - Update API keys monthly
   - Monitor access logs

3. **Use IAM Roles on EC2:**
   - For AWS SES, use EC2 instance profile instead of access keys
   - Avoid storing AWS credentials in .env file

## Testing Checklist

After deploying with new credentials, verify:

- [ ] PostgreSQL login works: `psql -U pretamane -d pretamane_db`
- [ ] pgAdmin login works at `/pgadmin`
- [ ] Grafana login works at `/grafana`
- [ ] MinIO Console login works on port 9001
- [ ] Meilisearch API key works for searches
- [ ] FastAPI can connect to all services
- [ ] `/health` endpoint shows all services connected
- [ ] File uploads work (tests MinIO + PostgreSQL)
- [ ] Search works (tests Meilisearch)
- [ ] Contact form works (tests PostgreSQL + SES)

## Troubleshooting

### If Services Don't Start

```bash
# Check logs for authentication errors
docker-compose logs postgresql
docker-compose logs minio
docker-compose logs grafana

# Common issues:
# 1. Old volumes with old credentials - run: docker-compose down -v
# 2. .env file not loaded - check: docker-compose config
# 3. Special characters in password - use single quotes
```

### If PostgreSQL Connection Fails

```bash
# Test connection from host
docker-compose exec postgresql psql -U pretamane -d pretamane_db -c "SELECT 1;"

# Check user exists
docker-compose exec postgresql psql -U postgres -c "\du"

# Recreate user if needed
docker-compose exec postgresql psql -U postgres -c "ALTER USER pretamane WITH PASSWORD '#ThawZin2k77!';"
```

### If MinIO Login Fails

```bash
# Check MinIO logs
docker-compose logs minio

# Verify credentials
docker-compose exec minio mc admin info local

# Reset admin credentials (nuclear option)
docker-compose down
docker volume rm docker-compose_minio-data
docker-compose up -d minio
```

## Next Steps

1. **Deploy to EC2:**
   - Transfer `.env` file to EC2
   - Update init script on EC2
   - Recreate services with new credentials

2. **Update Documentation:**
   - Update README with new credential info
   - Update deployment guides
   - Update troubleshooting docs

3. **Test All Services:**
   - Run through testing checklist
   - Verify CLI access
   - Test API endpoints

4. **Security Hardening:**
   - Set up AWS Secrets Manager
   - Enable audit logging
   - Configure backup automation

## References

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [MinIO Documentation](https://min.io/docs/)
- [Grafana Security](https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/)
- [Meilisearch API Keys](https://www.meilisearch.com/docs/learn/security/master_api_keys)
