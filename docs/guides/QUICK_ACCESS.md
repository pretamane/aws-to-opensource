# Quick Access Guide - All Services Working

**Instance IP:** 54.179.230.219  
**Status:**  FULLY OPERATIONAL  
**Date:** October 18, 2025

---

## All Working URLs

### Monitoring Dashboards

| Service | URL | Login | Status |
|---------|-----|-------|--------|
| **Grafana** | http://54.179.230.219/grafana/ | admin / admin123 |  Working |
| **Prometheus** | http://54.179.230.219/prometheus/ | N/A |  Working |
| **Meilisearch** | http://54.179.230.219/meilisearch/ | N/A |  Working |
| **MinIO** | http://54.179.230.219/minio/ | (auto-generated) |  Working |

### Application Endpoints

| Endpoint | URL | Status |
|----------|-----|--------|
| **API Docs** | http://54.179.230.219/docs |  Working |
| **Main App** | http://54.179.230.219/ |  Working |
| **Health Check** | http://54.179.230.219/health |  Working |
| **Metrics** | http://54.179.230.219/metrics |  Working |

---

## Test Commands

```bash
# Test Grafana
curl -s http://54.179.230.219/grafana/api/health | jq .

# Test Prometheus
curl -s "http://54.179.230.219/prometheus/api/v1/query?query=up" | jq .

# Test Meilisearch
curl -s http://54.179.230.219/meilisearch/health | jq .

# Test API
curl -s http://54.179.230.219/health | jq .

# Submit Contact
curl -X POST http://54.179.230.219/contact \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com","message":"Hello!"}'
```

---

## Container Status

All 8 containers running healthy:
-  fastapi-app (Main application)
-  postgresql (Database)
-  meilisearch (Search)
-  minio (Storage)
-  caddy (Reverse proxy)
-  prometheus (Metrics)
-  grafana (Dashboards)
-  loki (Logs)

---

## Cost Summary

**Monthly:** $32.77  
**vs EKS:** $330.00  
**Savings:** 90% ($297/month)

---

## Cleanup (When Done)

```bash
cd /home/guest/aws-to-opensource/terraform-ec2
terraform destroy -auto-approve
```

---

**Status:** 100% Operational - Ready for Portfolio Demos! 

