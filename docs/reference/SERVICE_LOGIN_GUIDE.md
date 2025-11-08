# Service Login Guide - Working Credentials

##  All Your Service Credentials

### Edge Authentication (First Layer)
**Applies to ALL admin services**

- **URL Pattern:** `http://localhost:8080/[service]`
- **Username:** `pretamane`
- **Password:** `#ThawZin2k77!`

---

## Service-Specific Logins (Second Layer)

### 1. Grafana Monitoring Dashboard
**URL:** http://localhost:8080/grafana

**Step 1 - Edge Auth (Caddy):**
- Username: `pretamane`
- Password: `#ThawZin2k77!`

**Step 2 - Grafana Login:**
- **Username:** `grafana_admin`
- **Password:** `j1RV*W3kEK*&bvwDv%H7`

**What you'll see:**
1. Browser popup for basic auth (edge layer)
2. Grafana login page (service layer)
3. Grafana dashboard after successful login

---

### 2. pgAdmin (PostgreSQL Admin)
**URL:** http://localhost:8080/pgadmin

**Step 1 - Edge Auth (Caddy):**
- Username: `pretamane`
- Password: `#ThawZin2k77!`

**Step 2 - pgAdmin Login:**
- **Email:** `admin@example.com`
- **Password:** `CwGSo6edbGBmaUXeC6aw`

**Step 3 - Connect to PostgreSQL Server:**
Once inside pgAdmin, add a new server:
- **Host:** `postgresql`
- **Port:** `5432`
- **Database:** `pretamane_db`
- **Username:** `pretamane_admin`
- **Password:** `c3wTt&2j3eOs%N2caMsD3YqI`

---

### 3. MinIO Object Storage Console
**URL:** http://localhost:8080/minio

**Step 1 - Edge Auth (Caddy):**
- Username: `pretamane`
- Password: `#ThawZin2k77!`

**Step 2 - MinIO Login:**
- **Username:** `minio_admin`
- **Password:** `9J*fDV9J&AhYy3q1%TgVz3hG`

**What you'll see:**
- MinIO console with buckets:
  - pretamane-data
  - pretamane-backup
  - pretamane-logs

---

### 4. Meilisearch Search Console
**URL:** http://localhost:8080/meilisearch

**Step 1 - Edge Auth (Caddy):**
- Username: `pretamane`
- Password: `#ThawZin2k77!`

**Step 2 - Meilisearch API Key:**
- **API Key:** `wsG2e18fbIORaimHH80pAqbLZEcl7cAr`

**Note:** Meilisearch console uses API key authentication, not username/password

---

### 5. Prometheus (Metrics)
**URL:** http://localhost:8080/prometheus

**Authentication:**
- **Edge Auth Only** (no additional login required)
- Username: `pretamane`
- Password: `#ThawZin2k77!`

---

### 6. Alertmanager
**URL:** http://localhost:8080/alertmanager

**Authentication:**
- **Edge Auth Only** (no additional login required)
- Username: `pretamane`
- Password: `#ThawZin2k77!`

---

## Quick Credential Reference

| Service | Edge Auth | Service Login |
|---------|-----------|---------------|
| **Grafana** | pretamane / #ThawZin2k77! | grafana_admin / j1RV*W3kEK*&bvwDv%H7 |
| **pgAdmin** | pretamane / #ThawZin2k77! | admin@example.com / CwGSo6edbGBmaUXeC6aw |
| **MinIO** | pretamane / #ThawZin2k77! | minio_admin / 9J*fDV9J&AhYy3q1%TgVz3hG |
| **Meilisearch** | pretamane / #ThawZin2k77! | API Key: wsG2e18fbIORaimHH80pAqbLZEcl7cAr |
| **Prometheus** | pretamane / #ThawZin2k77! | N/A (edge auth only) |
| **Alertmanager** | pretamane / #ThawZin2k77! | N/A (edge auth only) |

---

## Database Credentials (Internal Use)

**PostgreSQL:**
- **Host:** `postgresql` (internal Docker network)
- **Port:** `5432`
- **Database:** `pretamane_db`
- **Username:** `pretamane_admin`
- **Password:** `c3wTt&2j3eOs%N2caMsD3YqI`

---

## Troubleshooting Login Issues

### Grafana Login Issues

**If you see "Invalid username or password":**
```bash
cd docker-compose
docker compose down grafana
docker volume rm docker-compose_grafana-data
docker compose up -d grafana
# Wait 10 seconds, then try again
```

### pgAdmin Login Issues

**If email/password doesn't work:**
```bash
cd docker-compose
docker compose restart pgadmin
# Wait 10 seconds, then try again
```

### MinIO Login Issues

**If credentials don't work:**
```bash
cd docker-compose
docker compose restart minio
# Wait 10 seconds, then try again
```

---

## Testing Login from Command Line

### Test Grafana API
```bash
curl -u grafana_admin:j1RV*W3kEK*&bvwDv%H7 \
  http://localhost:8080/grafana/api/health
```

### Test MinIO
```bash
curl -u minio_admin:9J*fDV9J&AhYy3q1%TgVz3hG \
  http://localhost:8080/minio/
```

---

## Changing Passwords

To change any service password:

1. Edit `docker-compose/.env`
2. Change the relevant variable (GF_SECURITY_ADMIN_PASSWORD, etc.)
3. **Remove the service's data volume** to force re-initialization
4. Restart the service

Example for Grafana:
```bash
cd docker-compose
nano .env  # Change GF_SECURITY_ADMIN_PASSWORD
docker compose down grafana
docker volume rm docker-compose_grafana-data
docker compose up -d grafana
```

---

## Security Notes

 **These are auto-generated passwords for local development**

For production:
1. Change ALL passwords to strong, unique values
2. Store credentials in a password manager
3. Use secrets management (Vault, AWS Secrets Manager)
4. Enable MFA where supported
5. Rotate credentials regularly

---

**All credentials are stored in:** `docker-compose/.env`  
**To view all passwords:** `cat docker-compose/.env | grep PASSWORD`
