# Sample Interview Q&A

## Architecture & Design Questions

### Q: "Walk me through your system architecture"

**A**: "I built a microservices platform with Caddy as a single edge proxy providing security and routing to specialized services. The application layer uses FastAPI with background tasks for document processing. PostgreSQL stores transactional data with JSONB columns for flexibility. MinIO provides S3-compatible object storage. Meilisearch handles full-text search with typo tolerance. Everything's monitored via Prometheus for metrics, Loki for logs, and Grafana for visualization. The entire stack orchestrated with Docker Compose and provisioned via Terraform on a single EC2 instance."

**Follow-up details**:
- Data flow: User → Caddy → FastAPI → PostgreSQL/MinIO/Meilisearch → Background processing
- Observability: Prometheus scrapes metrics every 10s, Promtail ships logs to Loki, Grafana queries both
- Networking: All services on internal Docker network, only Caddy exposed externally

---

### Q: "Why did you choose this architecture over Kubernetes?"

**A**: "Trade-off between cost and complexity for the current scale. Our workload is <1K req/sec, which fits comfortably on a single host. Docker Compose saves us $270/month versus EKS ($75 control plane + $80 nodes + $30 NAT Gateway). It's also simpler to operate—one YAML file versus dozens of K8s manifests. The container images are portable, so when we need auto-scaling or multi-host, they work unchanged in Kubernetes. It's about right-sizing the solution to current needs with a clear scaling path."

---

### Q: "How do services communicate with each other?"

**A**: "Internal Docker network (bridge mode) with service discovery via container names. For example, FastAPI connects to PostgreSQL via `postgresql:5432`, not localhost. Caddy routes external traffic via path-based rules (`/api/*` → fastapi-app:8000). This keeps backends unexposed while enabling clean routing. Health checks ensure dependencies are ready before dependent services start—PostgreSQL must be healthy before FastAPI starts."

---

### Q: "Explain your database design philosophy"

**A**: "Hybrid approach: core fields as typed columns for type safety and fast lookups; variable metadata as JSONB for schema flexibility. For example, `name` and `email` are VARCHAR columns with indexes, but `document_insights` is JSONB for evolving metadata like keywords, confidence scores, and analysis results. GIN indexes on JSONB make queries fast. This gives us SQL reliability with NoSQL flexibility—best of both worlds."

---

## Technology Choice Questions

### Q: "Why PostgreSQL over DynamoDB?"

**A**: "We value strong consistency, complex queries, and predictable costs over DynamoDB's unlimited scale. Our workload is <1K ops/sec where PostgreSQL excels. We need joins for analytics (contacts → documents → search results), which DynamoDB can't do efficiently. Cost-wise, DynamoDB would be $1.25/million writes versus fixed $30/mo for our EC2 instance. I also replicated DynamoDB semantics like atomic counters using PL/pgSQL functions, so the application migration was straightforward."

**When I'd choose DynamoDB**:
- Workload >100K writes/sec
- Need global tables (multi-region)
- Variable traffic with idle periods (serverless cost model wins)

---

### Q: "Why MinIO instead of AWS S3?"

**A**: "Cost savings and portability. No egress fees ($0.09/GB savings), faster local access (<5ms vs internet latency), and S3 API compatibility means the same boto3 code works with both. This prevents vendor lock-in—if we need S3's unlimited scale later, we change one endpoint URL. For current storage needs (<500GB), MinIO is perfect. For petabytes, S3's economics make more sense."

---

### Q: "What made you choose Meilisearch for search?"

**A**: "Speed, typo tolerance, and cost. Meilisearch delivers <20ms searches with excellent Levenshtein-based typo correction out of the box, while OpenSearch costs $60/month and requires complex shard configuration. Our index size (<100K documents) fits Meilisearch's sweet spot. The ranking algorithm (words, typo, proximity, exactness) gives great relevance without manual tuning. For billions of documents or ML-powered ranking, I'd revisit OpenSearch."

---

### Q: "Why Python/FastAPI specifically?"

**A**: "Productivity and ecosystem. FastAPI gives us Pydantic validation, auto-generated docs, async/await for concurrency, and high performance via Starlette. Python's huge library ecosystem (boto3, PyPDF2, pandas) accelerates development. Type hints provide safety without compilation overhead. Performance is 'fast enough'—P50 latency is 50ms, P95 is 150ms. For >10K req/sec or CPU-bound tasks, I'd profile and consider Go microservices for hot paths."

---

## Problem-Solving Questions

### Q: "Tell me about a challenging technical problem you solved"

**A**: "MinIO Console was loading but completely unstyled—just plain HTML with no CSS. I debugged systematically: browser console showed 404 errors for CSS files, network tab revealed requests going to wrong paths (`/static/css/main.css` instead of `/minio/static/css/main.css`), and Caddy logs showed routing to the wrong backend. Root cause was using `handle_path` which stripped the path too early. I fixed it by changing to `handle` + `uri strip_prefix /minio` with correct directive order, plus configuring MinIO's `MINIO_BROWSER_REDIRECT_URL`. Verified by checking Content-Type headers returned correctly (text/css, not text/html). This demonstrates understanding of reverse proxy routing and systematic debugging."

---

### Q: "How do you approach debugging a production incident?"

**A**: "Systematic methodology:

1. **Triage**: Grafana dashboards—when did it start? What's affected? Severity?
2. **Correlate**: Prometheus metrics—latency spike? Error rate? Resource exhaustion?
3. **Investigate**: Loki logs—filter by timeframe and correlation ID for stack traces
4. **Verify**: Check infrastructure—`docker-compose ps`, health checks, resource usage
5. **Fix**: Apply runbook solution or implement custom fix
6. **Verify**: Confirm metrics return to normal, no new errors
7. **Document**: Update runbook, postmortem, prevent recurrence

Example: High latency alert → Grafana shows spike at 10:15am → Prometheus reveals DB connections at 10/10 (pool exhausted) → Loki shows PoolError messages → Immediate fix: restart fastapi-app → Permanent fix: increase pool size, add timeout → Document in runbook."

---

### Q: "What if PostgreSQL crashes?"

**A**: "Multiple recovery layers:

1. **Auto-restart**: Docker restart policy (`unless-stopped`) immediately restarts the container
2. **Retry logic**: FastAPI connection pool retries connections automatically
3. **Monitoring**: Prometheus alert fires after 2 minutes of downtime
4. **Investigation**: Check logs (`docker logs postgresql`), verify volume permissions, check for corruption
5. **Recovery**: If restart fails, restore from backup (pg_dump taken daily at 3am)
6. **Degradation**: Application returns cached data or degraded service while DB recovers

Total recovery time typically <5 minutes (restart), worst case <20 minutes (restore from backup). Data loss <24 hours (last backup)."

---

## Scaling & Performance Questions

### Q: "How would you scale this system?"

**A**: "Multiple approaches depending on bottleneck:

**Vertical scaling** (easiest first):
- t3.medium → t3.large → t3.xlarge
- Increase PostgreSQL connection pool and tune config
- Works until single-host limits (~10K req/sec)

**Horizontal scaling**:
- Add ALB for load balancing
- Run 2+ FastAPI instances (stateless, easy to replicate)
- PostgreSQL streaming replication (primary + read replicas)
- MinIO distributed mode (4+ nodes with erasure coding)
- Meilisearch replicas behind load balancer

**Managed migration** (if ops overhead too high):
- RDS Aurora for database
- ElastiCache for caching layer
- S3 for storage (same boto3 code)
- ECS or EKS for container orchestration

I'd choose based on which resource is bottlenecked—CPU, memory, I/O, or network."

---

### Q: "What are the current system's limitations?"

**A**: "Honest assessment:

**Capacity limits**:
- ~1K req/sec on single host (CPU bound)
- ~10 concurrent DB connections (pool size)
- ~500GB storage (disk size)
- No auto-scaling for traffic spikes

**Availability limits**:
- Single point of failure (no HA)
- ~5 min recovery time (restart)
- Manual failover required

**Operational limits**:
- Self-hosted requires maintenance
- Manual scaling (not automatic)
- Single-region only

**Documented trade-offs**:
- Current scale doesn't justify complexity/cost of HA
- Clear triggers for when to scale (CPU >80%, latency >1s)
- Migration paths documented (vertical → horizontal → managed)"

---

### Q: "At what point would you migrate back to AWS managed services?"

**A**: "When total cost of ownership (money + time) favors managed:

**Triggers**:
- Traffic grows 10x → managing PostgreSQL replication costs more eng time than RDS
- Need multi-region → CloudFront + S3 + Aurora Global cheaper than global MinIO replication
- 24/7 SLA required → paying for managed services + support < on-call team cost
- Team >10 engineers → cost of self-hosting < 1 engineer's salary
- Compliance requirements → managed services have built-in audit/encryption/MFA

**Current context**:
- We're at ~$30/mo with minimal ops overhead
- RDS alone would cost ~$150/mo (5x current total)
- Only justified when scale or compliance demands it

I'd continuously re-evaluate as the business grows."

---

## Operations & Reliability Questions

### Q: "What's your backup and disaster recovery strategy?"

**A**: "Multi-layer approach:

**Automated backups** (daily at 3am):
- PostgreSQL: `pg_dump` to compressed SQL
- MinIO: Mirror all buckets to backup location
- Prometheus/Grafana: Tar configs and data
- Upload to S3 for offsite storage
- 7-day retention policy

**Disaster recovery** (tested quarterly):
- Terraform recreates infrastructure in 10 minutes
- User-data bootstraps Docker and services in 5 minutes
- Restore script loads backups in 10 minutes
- Total RTO: 25 minutes
- RPO: 24 hours (daily backup interval)

**For stricter requirements**:
- PostgreSQL WAL shipping (continuous backup, RPO <1 minute)
- MinIO replication to second cluster
- Multi-region deployment
- But current SLA doesn't justify the cost/complexity."

---

### Q: "How do you monitor system health?"

**A**: "Four golden signals plus business metrics:

**Latency**: P50/P95/P99 via Prometheus histograms
- Alert: P95 >1s for 10 minutes

**Traffic**: Request rate via Prometheus counters
- Alert: Spike >10x baseline (DDoS or viral traffic)

**Errors**: HTTP 4xx/5xx rates
- Alert: Error rate >5% for 5 minutes

**Saturation**: CPU, memory, disk, DB connections
- Alert: Any resource >80% for sustained period

**Business metrics**:
- Contact submissions, document uploads, search queries
- Visitor count trends
- Processing success rates

**Synthetic monitoring**:
- Blackbox Exporter probes endpoints every 10s
- Detects issues users would experience

**Visualization**: Grafana dashboards, Loki for log correlation, Alertmanager for routing notifications by severity."

---

### Q: "What happens if Meilisearch goes down?"

**A**: "Graceful degradation with fallback:

**Immediate impact**:
- Search endpoint returns empty results or error
- Users can't search documents

**Detection**:
- Prometheus alert: `up{job="meilisearch"} == 0`
- Health check endpoint fails

**Fallback strategy**:
- Return PostgreSQL full-text search results (slower but functional)
- Or return recent documents without ranking
- Show user-friendly message: "Search temporarily unavailable"

**Recovery**:
- Docker restart policy attempts automatic restart
- If restart fails, check logs for root cause (volume issues, OOM, corruption)
- Worst case: recreate index from PostgreSQL documents (15-30 minutes)

**Prevention**:
- Health checks detect issues early
- Prometheus alerts on high latency or errors
- Daily backups of index data"

---

## Security & Best Practices Questions

### Q: "How do you handle secrets management?"

**A**: "Current approach and production roadmap:

**Current** (MVP, documented as temporary):
- Environment variables in `.env` file (gitignored)
- Passwords with proper escaping
- IAM role for AWS access (no hardcoded credentials)
- bcrypt-hashed passwords for Basic Auth

**Production migration**:
- AWS Secrets Manager or Parameter Store for all secrets
- Injected at runtime via user-data or ECS task definitions
- Automatic rotation with Lambda triggers
- Audit trail of access
- Encrypted at rest and in transit

**Why not already done**:
- Secrets Manager costs $0.40/secret/month
- Adds operational complexity
- Current solution acceptable for demo/portfolio
- Clear documentation of upgrade path

I'd implement this before any production traffic."

---

### Q: "Explain your security posture"

**A**: "Defense in depth with multiple layers:

**Network security**:
- Security groups restrict ingress (HTTP/HTTPS/SSH only)
- SSH limited to specific IPs
- Internal services unexposed (only Caddy public)

**Application security**:
- Caddy security headers (HSTS, CSP, XFO, nosniff)
- Basic Auth on admin UIs (Grafana, Prometheus, MinIO)
- Input validation via Pydantic
- SQL injection prevention (parameterized queries)

**Data security**:
- Encrypted EBS volumes
- PostgreSQL password authentication
- Meilisearch API key required
- MinIO access keys

**Operational security**:
- IAM role (least privilege, no hardcoded AWS keys)
- SSM Session Manager (SSH-less access)
- Docker non-root users
- Automated security updates

**Future improvements**:
- OAuth2/OIDC (Keycloak) for SSO and MFA
- Nonce-based CSP (remove 'unsafe-inline')
- Rate limiting at edge
- WAF rules
- Secrets in Vault"

---

### Q: "Why do you use 'unsafe-inline' in CSP?"

**A**: "Honest trade-off with documented mitigation:

**Current reality**:
- FastAPI/Swagger UI generates inline scripts that I can't easily control
- Framework limitation, not lack of understanding
- `'unsafe-inline'` weakens CSP but doesn't eliminate all protection

**Remaining protections**:
- `connect-src 'self'` prevents data exfiltration to external domains
- Other headers (HSTS, XFO, nosniff) still active
- Whitelisted specific CDNs only

**Production migration**:
- Implement nonce-based CSP: `script-src 'nonce-RANDOM'`
- Middleware generates random nonce per request
- Inject nonce into every script tag
- External scripts unchanged

**Timeline**:
- Estimate: 2-3 days engineering work
- Priority: Before first production user
- Documented in security roadmap

This shows I understand the limitation, accept the trade-off for MVP, and have a clear path to fix it."

---

## Cultural Fit & Soft Skills Questions

### Q: "Why did you build two versions (EKS and EC2)?"

**A**: "To demonstrate versatility and breadth:

**EKS version** shows:
- I can build enterprise-grade AWS infrastructure
- Understand Kubernetes, Helm, service meshes
- Know when managed services are worth the cost

**EC2 version** shows:
- I can optimize costs by 90%
- Comfortable with open-source tools
- Understand trade-offs and make pragmatic decisions

**Real-world value**:
- Companies need engineers who know both
- Startups need cost optimization (EC2 approach)
- Enterprises need scalability (EKS approach)
- Skill is knowing which to use when

Having both in my portfolio proves I can adapt to the company's needs and constraints."

---

### Q: "What did you learn from this project?"

**A**: "Five key insights:

1. **Open-source is production-ready**: PostgreSQL, Prometheus, Grafana are industry standards, not toy tools
2. **API compatibility enables portability**: S3 API, Prometheus metrics format—switching vendors is easy
3. **Operational simplicity has value**: One instance is easier to debug than distributed systems
4. **Cost optimization is a valid goal**: Not every project needs unlimited scale
5. **Document trade-offs**: Future you (or teammates) need to understand why decisions were made

Also learned specific tools deeply: PromQL, LogQL, Docker Compose orchestration, Terraform best practices, Caddy reverse proxy, PostgreSQL JSONB + GIN indexes."

---

### Q: "How do you stay current with technology?"

**A**: "Multi-pronged approach:

**Building**: This project—hands-on with Docker, Prometheus, Grafana, Meilisearch, etc.
**Reading**: Tech blogs (AWS, Cloudflare, Netflix), Hacker News, Reddit r/sysadmin
**Community**: Tech meetups, online forums, Discord/Slack communities
**Documentation**: Read official docs, not just tutorials
**Experimenting**: Spin up new tools in Docker, test drive, evaluate

**Recent examples**:
- Learned Meilisearch by migrating from OpenSearch
- Learned PromQL by writing custom queries
- Learned Caddy by debugging reverse proxy issues

I believe in learning by doing, then documenting what I learned."

---

## Final Closing Questions

### Q: "Do you have any questions for me?"

**A**: Consider asking:
1. "What's the team's approach to balancing new features versus technical debt?"
2. "How does the team handle on-call and incident response?"
3. "What's the split between cloud-managed services and self-hosted infrastructure?"
4. "What would success look like for this role in the first 3-6 months?"
5. "What are the biggest technical challenges the team is currently facing?"

---

**Remember**: These are templates. Adapt based on your actual experience and the specific role!

