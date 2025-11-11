# Edge & Reverse Proxy: Caddy

## Role
Single entry point providing path-based routing, security headers, Basic Auth for admin UIs, and static site delivery.

## Where Defined
- `docker-compose/docker-compose.yml` → `caddy` service
- `docker-compose/config/caddy/Caddyfile` → routes, headers, auth

## How It Works
- Listens on :80 (or :8080 locally). Cloudflared can terminate TLS and forward to Caddy.
- Applies global headers:
  - HSTS (HTTPS-only), X-Content-Type-Options (no sniff), X-Frame-Options (SAMEORIGIN), Referrer-Policy, CSP
- Routes:
  - `/api/*, /docs, /health, /metrics` → `fastapi-app:8000`
  - `/grafana, /prometheus, /pgadmin, /meilisearch/*, /minio/*, /alertmanager/*, /loki/*` → respective services
- Subpath apps (MinIO, Meilisearch): `handle` + `uri strip_prefix` keeps assets under subpaths

## Security Controls
- Basic Auth with bcrypt hashes for admin UIs
- CSP with curated CDNs; plan: nonce-based CSP
- Future: OAuth2/OIDC at edge (Keycloak), rate limiting

## Observability
- JSON access logs written to `/var/log/caddy/access.log`, tailed by Promtail

## Failure Modes & Mitigation
- Misrouted subpath → verify `handle` ordering, `uri strip_prefix`
- CSP blocking assets → browser console violations; whitelist minimal CDNs
- High 4xx/5xx → Prometheus alerts + Loki log drill-down

## Interview Notes
- “Edge consolidation reduced attack surface, centralized security, and simplified ops.”
