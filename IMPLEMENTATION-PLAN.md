# Implementation Plan — Cloud-Native E-Commerce Platform (AWS)

> Turns the target-state design in [`ARCHITECTURE.md`](./ARCHITECTURE.md) into a buildable
> implementation. Scope covers four tracks: **A) Infrastructure as Code**, **B) Advanced
> Security**, **C) Cost Optimization**, and **D) Product Management API**. Primary cloud is
> **AWS**; everything is provisioned via **Terraform** and structured into **reusable modules**.

---

## 0. Guiding principles & repo layout

- **Everything is Terraform.** No click-ops. State in a locked, versioned **S3 backend + DynamoDB lock table**, one state key per environment.
- **Reusable modules** under `modules/`; thin **environment roots** under `envs/{dev,staging,prod}` that only wire modules together with env-specific variables.
- **Multi-AZ by default, warm-standby DR** (us-east-1 primary, us-west-2 DR) — matches ARCHITECTURE.md §4.1.3 / §5 M1.
- **Least privilege everywhere**; secrets never in code, state, or images.

```
infra/
  backend.tf                # S3 + DynamoDB remote state
  modules/
    network/               # VPC, subnets, NAT, route tables, endpoints
    eks/                   # cluster, managed + Spot node groups, IRSA, Karpenter
    database/              # Aurora PostgreSQL Global (multi-AZ writer + replicas)
    loadbalancer/          # ALB, target groups, listeners, ACM
    security/              # IAM roles/policies, WAF, KMS, Secrets Manager
    eventing/              # MSK (Kafka)
    cache-search/          # ElastiCache Redis, OpenSearch
    observability/         # OTel collector, CloudWatch, Prometheus/Grafana addons
  envs/
    dev/  staging/  prod/  # main.tf + terraform.tfvars per env
api/
  product-service/         # Track D — FastAPI product CRUD + auth + rate-limit + tests
```

---

## A. Infrastructure Implementation (IaC)

### A.1 Networking module (`modules/network`)
Implements ARCHITECTURE.md §4.1.2 Edge/Ingress + §4.1.3 multi-AZ.
- **VPC** (`10.0.0.0/16`) spanning **3 AZs**.
- **Public subnets** (3) — ALB + NAT gateways only.
- **Private app subnets** (3) — EKS worker nodes.
- **Private data subnets** (3) — Aurora, Redis, MSK, OpenSearch (no route to internet).
- **NAT gateway per AZ** (prod) / single NAT (dev, cost saving — see Track C).
- **VPC endpoints** (S3, ECR, Secrets Manager, STS) so pods reach AWS services without egressing the NAT.
- Outputs: `vpc_id`, `private_app_subnet_ids`, `private_data_subnet_ids`, `public_subnet_ids`.

### A.2 Compute module (`modules/eks`)
Managed Kubernetes = the portability anchor (ARCHITECTURE.md §4.2).
- **EKS cluster** (control plane across 3 AZs), private API endpoint.
- **Managed node group** (On-Demand) for critical/stateful workloads (checkout, order, payment).
- **Spot node group** + **Karpenter** for stateless/burst workloads (catalog, real-time consumers).
- **IRSA** enabled (OIDC provider) so each service account gets a scoped IAM role (Track B).
- Cluster addons: VPC-CNI, CoreDNS, kube-proxy, EBS-CSI, metrics-server, Prometheus adapter (for HPA on custom RPS — §4.3.4).
- Optional variant: an **ECS Fargate** module for teams that don't want to run EKS (documented alternative; EKS is the default).

### A.3 Database module (`modules/database`) — multi-zone
Strong consistency for orders/payments (ARCHITECTURE.md §4.3.1).
- **Aurora PostgreSQL** cluster: **1 writer + 2 read replicas across 3 AZs**.
- **Aurora Global Database** → us-west-2 replica for DR (RPO < 1 min under normal replication lag — worst case = lag at failure; promote on failover; monitor/alert on lag).
- Automated backups + PITR (35-day retention); snapshots copied cross-region.
- **RDS Proxy** in front for connection pooling (survives writer failover, §4.4).
- Credentials generated and stored in **Secrets Manager** with rotation (Track B) — never in tfvars.
- Multi-AZ ElastiCache Redis + OpenSearch live in sibling modules (`cache-search`).

### A.4 Load balancer module (`modules/loadbalancer`)
- **Application Load Balancer** (multi-AZ) in public subnets → EKS ingress.
- HTTPS listener with **ACM** certificate; HTTP→HTTPS redirect.
- Target groups with health checks that eject unhealthy pods/nodes.
- **CloudFront** distribution in front (CDN + edge cache for the SPA and cacheable GETs), origin = ALB / S3.
- WAF association handled in the security module (Track B).

### A.5 Reusability & environments
- Every module: `variables.tf`, `outputs.tf`, `main.tf`, `versions.tf`, `README.md` with example usage.
- `envs/prod/main.tf` composes modules and passes prod sizing; `dev` uses smaller instances, single NAT, no cross-region DR (cost).
- Pin provider + module versions; run `terraform fmt`, `validate`, `tflint`, and **`checkov`/`tfsec`** in CI.

---

## B. Advanced Security Implementation

### B.1 Least-privilege IAM (`modules/security`)
- **IRSA per service** — each microservice's Kubernetes service account maps to an IAM role scoped to *only* the resources it needs (e.g. Order svc: `rds-db:connect` to the orders DB + read its specific secret; Real-time svc: read MSK + write its S3 prefix).
- No wildcards in resource ARNs; deny-by-default. Human access via **SSO + MFA**, no long-lived keys.
- Terraform CI role itself scoped and assumed via OIDC (GitHub Actions → AWS), not static keys.
- Policy tests: run **IAM Access Analyzer** + `checkov` to catch over-broad grants.

### B.2 Secrets management
- **AWS Secrets Manager** for DB credentials, API signing keys, third-party payment provider tokens.
- **Automatic rotation** enabled (Lambda rotation for Aurora).
- **KMS** CMKs for encryption at rest (Aurora, S3, EBS, ElastiCache, MSK) — one key per data domain, key policies least-privilege.
- Pods read secrets at runtime via IRSA + the Secrets Store CSI driver — secrets never baked into images, env files, or Terraform state.

### B.3 Web Application Firewall (WAF)
- **AWS WAFv2 web ACL** attached to CloudFront (and/or ALB).
- Managed rule groups: **AWS Core rule set (OWASP top 10)**, **Known Bad Inputs**, **SQL injection**, **Linux/POSIX**, **IP reputation**, **Anonymous IP**.
- **Rate-based rule** (e.g. 2,000 req/5-min/IP) to blunt volumetric abuse at the edge — complements the API-level rate limit in Track D.
- Bot control + geo-block rules as needed; **AWS Shield** for DDoS. Logging to CloudWatch/S3 for audit.

---

## C. Cost Optimization

| Strategy | Where | Expected saving |
|----------|-------|-----------------|
| **Spot instances** for stateless/stream workers via Karpenter | EKS (A.2) | 60–90% on burst compute |
| **Right-sizing** driven by VPA recommendations + CloudWatch/Compute Optimizer | EKS, RDS, cache | avoid over-provisioning |
| **S3 lifecycle policies** — transition data-lake/backups to IA → Glacier; expire old logs | S3 (data lake, logs) | large on cold storage |
| **Single NAT gateway in dev**, NAT-per-AZ only in prod | network (A.1) | ~$32/mo × 2 in dev |
| **Aurora auto-scaling replicas** + scale DR EKS to *minimum* until failover | database, DR | pay for warm standby, not full |
| **Savings Plans / Reserved** for the always-on On-Demand baseline | EKS On-Demand group | ~30–50% vs on-demand |
| **CloudFront caching** offloads origin traffic (fewer EKS/DB calls) | edge | reduces compute + egress |
| **Scheduled scale-down** of non-prod out of hours | dev/staging | ~65% on idle time |
| **Cost visibility** — tags on every resource (`env`, `service`, `owner`) + AWS Budgets alerts + per-service Cost Explorer dashboards | all modules | governance |

---

## D. Product Management API (`api/product-service`)

A basic but complete **product CRUD** service — FastAPI (Python), containerized to run as the Catalog microservice on EKS.

### D.1 Endpoints
| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/products` | List products (paginated, filterable) |
| `GET` | `/products/{id}` | Get one product |
| `POST` | `/products` | Create product (auth required) |
| `PUT` | `/products/{id}` | Update product (auth required) |
| `DELETE` | `/products/{id}` | Delete product (auth required) |
| `GET` | `/healthz` | Liveness/readiness probe |

### D.2 Stack & structure
- **FastAPI + Pydantic** (validation), **SQLAlchemy** → Aurora PostgreSQL (async driver).
- **Auth**: OAuth2 **JWT Bearer**, verified against Cognito JWKS (matches ARCHITECTURE.md §4.3.2). Write endpoints require a valid token + `products:write` scope; reads are public/cacheable.
- **Rate limiting**: `slowapi` (token-bucket per client/IP) as app-level defense; WAF rate rule (Track B) is the edge layer.
- **Config** via env/Secrets Manager; **structured logging**; OpenTelemetry instrumentation.
- Layout: `app/{main.py,models.py,schemas.py,crud.py,auth.py,deps.py,ratelimit.py}`, `tests/`, `Dockerfile`, `pyproject.toml`.

### D.3 Unit tests
- **pytest** with an in-memory/SQLite or testcontainers Postgres fixture.
- Cover: each CRUD path (happy + 404 + validation error), auth (valid/expired/missing JWT → 401/403), rate-limit (429 after threshold), pagination.
- Target ≥ 80% coverage; runs in CI before image build.

### D.4 Delivery
- Multi-stage Dockerfile → ECR (scanned); Helm chart deploys to EKS behind the ALB/API Gateway.
- HPA on CPU + custom RPS metric (ARCHITECTURE.md §4.3.4).

---

## Execution order & milestones

1. **Foundation** — remote state backend, `network` module, `security` (KMS + base IAM).
2. **Data + compute** — `database` (Aurora multi-AZ), `eks`, `cache-search`, `eventing`.
3. **Edge** — `loadbalancer` (ALB + CloudFront) + WAF association + Cognito.
4. **API** — build/test `product-service`, containerize, deploy via Helm.
5. **Cost + ops** — tagging, budgets, Spot/Karpenter, lifecycle policies, observability addons.
6. **DR + hardening** — Aurora Global DB to us-west-2, warm-standby EKS, game-day validation.

Each track maps directly back to ARCHITECTURE.md sections; verify runtime behavior against the design as each module lands (§4.4 documented-vs-actual discipline).
