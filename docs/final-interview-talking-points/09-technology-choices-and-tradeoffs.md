# Technology Choices & Trade-offs

## Overall Migration Philosophy

**Goal**: Reduce costs by 90% while maintaining feature parity and demonstrating technical breadth.

**Strategy**: Replace AWS managed services with open-source alternatives that preserve APIs and semantics.

---

## Edge Layer: Caddy vs Alternatives

### Decision: Caddy

#### Considered Alternatives
- **Nginx**: Industry standard, huge community
- **Traefik**: Cloud-native, auto-discovery
- **HAProxy**: High performance, TCP/HTTP

#### Why Caddy Won
- Auto-HTTPS with Let's Encrypt (would use in production)
- Simpler config syntax (easier to maintain)
- Security by default (good headers out of box)
- JSON API for dynamic config
- Built-in Prometheus metrics

#### Trade-offs Accepted
- Smaller community than Nginx
- Fewer third-party modules
- Less battle-tested at extreme scale (but sufficient for our needs)

**Interview Point**: "I chose Caddy for developer experience and security defaults. While Nginx has a larger ecosystem, Caddy's simplicity reduces operational overhead. For >10K req/sec, I'd benchmark both."

---

## Orchestration: Docker Compose vs Kubernetes

### Decision: Docker Compose

#### Considered Alternatives
- **Kubernetes (K8s)**: Industry standard, auto-scaling, self-healing
- **Docker Swarm**: Native Docker orchestration
- **Nomad**: HashiCorp, simpler than K8s

#### Why Docker Compose Won
- **Current scale**: <1K req/sec fits single host
- **Cost**: No control plane overhead ($75/mo for EKS)
- **Simplicity**: One YAML file vs dozens of manifests
- **Local dev**: Same stack runs on laptop
- **Portability**: Container images work unchanged in K8s later

#### Trade-offs Accepted
- No auto-scaling (manual vertical/horizontal scaling)
- No built-in HA (single point of failure)
- No service mesh (manual networking)
- Limited to single host (until we outgrow it)

**Interview Point**: "Docker Compose is appropriate for our scale (<1K req/sec, single host). It's simpler to operate and costs $270/mo less than EKS. When we need auto-scaling or multi-host, the same containers migrate to Kubernetes with minimal changes."

---

## Database: PostgreSQL vs DynamoDB

### Decision: PostgreSQL

#### Considered Alternatives
- **DynamoDB**: Serverless, unlimited scale, managed
- **MongoDB**: Document store, flexible schema
- **MySQL**: Similar to Postgres, larger community

#### Why PostgreSQL Won
- **Consistency**: ACID transactions (audit trail, banking)
- **Query power**: JOINs, aggregations, window functions
- **Cost**: Fixed vs $1.25/million writes
- **Relationships**: Foreign keys, constraints
- **Flexibility**: JSONB for schema evolution
- **Extensions**: Full-text search, PostGIS, timescale

#### Trade-offs Accepted
- Manual scaling (vertical + read replicas)
- Operational overhead (backups, tuning)
- Less elastic than DynamoDB (can't handle sudden 100x spike)

**Key Insight**: Used JSONB to preserve DynamoDB's schema flexibility while gaining SQL power.

**Interview Point**: "We chose PostgreSQL because we value consistency, complex queries, and predictable costs over DynamoDB's unlimited scale. Our workload (<1K ops/sec) fits Postgres sweet spot. JSONB columns give us NoSQL flexibility when needed."

---

## Search: Meilisearch vs OpenSearch

### Decision: Meilisearch

#### Considered Alternatives
- **OpenSearch/Elasticsearch**: Battle-tested, massive scale
- **Typesense**: Similar to Meilisearch
- **Algolia**: Managed, excellent UX (but $$)

#### Why Meilisearch Won
- **Cost**: $60/mo → $0
- **Speed**: <20ms searches (vs <100ms OpenSearch)
- **Typo tolerance**: Excellent out of box
- **Simplicity**: Single binary, no cluster management
- **API**: RESTful, easy to use

#### Trade-offs Accepted
- Limited to millions of docs (not billions)
- Less mature ecosystem
- Fewer advanced features (ML ranking, anomaly detection)
- No built-in replication (manual setup)

**Interview Point**: "Meilisearch excels at our scale (<100K docs) with sub-20ms searches and great typo tolerance. For billions of documents or ML-powered ranking, I'd revisit OpenSearch. The simplicity-to-power ratio is excellent here."

---

## Storage: MinIO vs S3/EFS

### Decision: MinIO

#### Considered Alternatives
- **AWS S3**: Unlimited scale, 99.999999999% durability
- **AWS EFS**: NFS-compatible, multi-AZ
- **Ceph**: Distributed, open-source

#### Why MinIO Won
- **Cost**: No egress fees ($0.09/GB savings)
- **Speed**: Local access (<5ms vs internet latency)
- **API**: S3-compatible (boto3 works unchanged)
- **Portability**: Switch to S3 later with zero code changes

#### Trade-offs Accepted
- Limited by disk space (not unlimited like S3)
- Single-node = single point of failure
- Manual backup strategy required
- Durability depends on underlying storage

**Mitigation**: Distributed mode (4+ nodes) for production HA.

**Interview Point**: "MinIO preserves S3 API for portability—same boto3 code works with both. This is vendor lock-in prevention. We save on egress costs and get faster local access. For petabyte scale, migrate back to S3 seamlessly."

---

## Observability: Prometheus/Grafana/Loki vs CloudWatch

### Decision: Open-Source Stack

#### Considered Alternatives
- **AWS CloudWatch**: Managed, integrated
- **Datadog**: All-in-one, beautiful UI (but expensive)
- **New Relic**: APM-focused

#### Why Open-Source Won
- **Cost**: $10/mo + $0.30/GB logs → $0
- **Query power**: PromQL/LogQL > CloudWatch Insights
- **Dashboards**: Grafana > CloudWatch UI
- **Portability**: Runs anywhere, no lock-in
- **Community**: Huge ecosystem, plugins

#### Trade-offs Accepted
- Self-hosted (operational overhead)
- No managed backups (manual setup)
- Less polished than paid products
- No built-in APM (need Jaeger/Tempo separately)

**Interview Point**: "Prometheus/Grafana/Loki is industry standard for observable open-source stacks. PromQL is more powerful than CloudWatch Insights, Grafana dashboards are beautiful, and Loki's label-based log indexing is fast and cheap. We pay with operational overhead instead of money."

---

## Language: Python (FastAPI) vs Alternatives

### Decision: Python + FastAPI

#### Considered Alternatives
- **Go**: Faster, compiled, concurrent
- **Node.js (Express)**: JavaScript, large ecosystem
- **Rust (Actix)**: Blazing fast, memory safe

#### Why Python/FastAPI Won
- **Productivity**: Rapid development, readable
- **Ecosystem**: Huge library selection (pandas, boto3, PDFs)
- **Type hints**: Pydantic validation, async/await
- **FastAPI**: Auto-generated docs, high performance
- **Team**: Most devs know Python

#### Trade-offs Accepted
- Slower than Go/Rust (but fast enough)
- GIL limits CPU parallelism
- Higher memory usage

**Performance**: 50ms P50, 150ms P95 latency is acceptable for our workload.

**Interview Point**: "FastAPI gives us productivity (Pydantic, auto-docs) and performance (async, Starlette). It's 'fast enough' for our load. For >10K req/sec or CPU-heavy tasks, I'd profile and consider Go microservices for hot paths."

---

## Authentication: Basic Auth vs OAuth2

### Decision: Basic Auth (MVP), OAuth2 (Roadmap)

#### Why Basic Auth Now
- Simple, works immediately
- Better than nothing
- Sufficient for trusted users
- bcrypt hashing (secure)

#### Why OAuth2 Later
- SSO (single sign-on)
- MFA support
- Centralized user management
- Token expiration/refresh
- Audit trail

**Interview Point**: "Basic Auth is a pragmatic MVP choice—simple and secure enough. For production, I'd migrate to OAuth2/OIDC (Keycloak) for SSO, MFA, and better UX. The migration path is clear, and I document it in the architecture."

---

## CSP: 'unsafe-inline' vs Nonce-Based

### Decision: 'unsafe-inline' (MVP), Nonce-Based (Roadmap)

#### Why 'unsafe-inline' Now
- FastAPI/Swagger UI generates inline scripts
- Framework limitation, not lack of knowledge
- Still blocks most XSS (connect-src limits exfiltration)

#### Why Nonce-Based Later
- Blocks inline XSS completely
- Requires: Generate random nonce per request, inject into all scripts
- Complexity: Middleware + template rewriting

**Interview Point**: "I accept 'unsafe-inline' as a temporary trade-off because our framework requires it. For production, I'd implement nonce-based CSP by externalizing scripts and adding middleware to inject nonces per request. I document this explicitly in security roadmap."

---

## Deployment: EC2 vs ECS vs EKS

### Decision: EC2 + Docker Compose

#### Considered Alternatives
- **ECS**: Managed containers, simpler than EKS
- **EKS**: Full Kubernetes, enterprise-grade
- **Fargate**: Serverless containers

#### Why EC2 Won
- **Cost**: $30/mo (vs $75 EKS control plane + $80 nodes)
- **Simplicity**: One instance, simple ops
- **Sufficient**: <1K req/sec fits single host
- **Portable**: Same images work in ECS/EKS later

#### Trade-offs Accepted
- No auto-scaling
- No built-in HA
- Manual updates
- Single point of failure

**Scaling Path**: ALB + Auto Scaling Group → ECS → EKS as needs grow.

**Interview Point**: "EC2 is right-sized for our current scale. It demonstrates cost-consciousness and pragmatic engineering. When we hit bottlenecks, the migration path to ECS/EKS is clear, and the same container images work unchanged."

---

## Summary: When to Revisit Decisions

### Scale Triggers

| Component | Current Limit | Revisit When | Alternative |
|-----------|--------------|--------------|-------------|
| **Caddy** | ~10K req/sec | >5K req/sec sustained | Nginx (more tuning options) |
| **Docker Compose** | Single host | Need auto-scaling | ECS/EKS |
| **PostgreSQL** | ~1K writes/sec | >500 writes/sec sustained | Read replicas, then DynamoDB |
| **Meilisearch** | ~1M docs | >500K docs | OpenSearch/Elasticsearch |
| **MinIO** | ~500GB | >1TB or need HA | Distributed MinIO or S3 |
| **EC2** | ~1K req/sec | CPU consistently >80% | Vertical scale, then horizontal |

### Cost Triggers

| Scenario | Action |
|----------|--------|
| AWS bill >$100/mo | Audit, optimize, or accept growth |
| Traffic >10x current | Revisit managed services (auto-scaling value) |
| Team >5 people | Consider managed services (ops time costs) |

### Complexity Triggers

| Scenario | Action |
|----------|--------|
| Multi-region needed | Use managed services (RDS, CloudFront, Route53) |
| Compliance requirements | Audit logging, encryption at rest, MFA, RBAC |
| 24/7 SLA required | HA setup, on-call, runbooks, managed services |

---

## Interview Talking Points

**"Why not just use AWS managed services?"**
> "Cost and learning. This project demonstrates both approaches: I have an EKS version showcasing enterprise AWS patterns, and this EC2 version showcasing cost optimization with open-source tools. Real companies need engineers who understand both—when to pay for convenience and when to optimize costs."

**"What's your decision-making framework?"**
> "I evaluate: 1) Current requirements (scale, budget, team size), 2) Growth trajectory (3-6 month horizon), 3) Operational overhead, 4) Portability, 5) Team expertise. I choose the simplest solution that meets requirements and has a clear scaling path."

**"When would you migrate back to AWS managed services?"**
> "When scale or ops complexity makes it cost-effective. Example: If traffic grows 10x, managing PostgreSQL replication might cost more in eng time than RDS. Or if we need multi-region, CloudFront + S3 is cheaper than global MinIO replication. Always evaluate total cost of ownership (money + time)."

**"How do you avoid over-engineering?"**
> "Start simple, measure, scale when needed. This system runs on one host because that's sufficient. I document scaling triggers (CPU >80%, latency >1s) so we know when to act, not prematurely optimize. Every complexity trade-off is documented with rationale."

**"What did you learn from this migration?"**
> "1) Open-source alternatives are production-ready, 2) API compatibility enables portability (S3, Prometheus), 3) Operational simplicity has value, 4) Cost optimization is a valid engineering goal, 5) Both cloud-managed and self-hosted have trade-offs—context matters."

