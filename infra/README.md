# Infrastructure (Terraform) — Cloud-Native E-Commerce Platform

Reusable Terraform modules + per-environment roots that implement the target-state design in
[`../ARCHITECTURE.md`](../ARCHITECTURE.md). Primary cloud is **AWS**. Everything is a
module; environment roots (`envs/{dev,staging,prod}`) only wire modules together with
env-specific sizing.

> **This is a generic, validate-only reference.** No account-specific value or secret is
> committed. Every input is a variable; values that require a real AWS account/credential are
> marked `REQUIRES REAL VALUE` in their `description` so they are greppable
> (`grep -rn "REQUIRES REAL VALUE" .`). Secret *values* never live in Terraform — only
> Secrets Manager secret **definitions** do; the values are populated out-of-band.

## Layout

```
infra/
  versions.tf   backend.tf   .gitignore
  modules/
    network/         VPC, 3-AZ subnets (public/private-app/private-data), NAT, VPC endpoints
    eks/             EKS cluster, On-Demand + Spot node groups, OIDC/IRSA, Karpenter role
    database/        Aurora PostgreSQL (writer + replicas), Global DB (DR), RDS Proxy
    cache-search/    ElastiCache Redis (multi-AZ) + OpenSearch (zone-aware)
    eventing/        MSK (Kafka) + cross-region Replicator (DR)
    loadbalancer/    ALB (HTTPS) + CloudFront + WAF association
    security/        KMS CMKs, IRSA role factory, Secrets Manager, WAFv2
    observability/   CloudWatch log groups, OTel collector IRSA, AWS Budgets
  envs/
    dev/       single NAT, small instances, no DR         (cost-optimized)
    staging/   NAT-per-AZ, moderate instances, no DR       (prod-like)
    prod/      NAT-per-AZ, large instances, DR on, del-protection
```

## Categories of `REQUIRES REAL VALUE` inputs

| Category | Examples | Where supplied |
|----------|----------|----------------|
| **Account / identity** | account id, EKS OIDC provider ARN/URL | derived from the `eks` module at apply time |
| **Region / networking** | `region`, `azs`, ingress CIDRs, EKS public-access CIDRs | env `*.tfvars` |
| **DNS / TLS** | ACM cert ARNs, CloudFront aliases | env `*.tfvars` |
| **Secrets** | Aurora master password, Redis AUTH token, payment tokens | **Secrets Manager only** — TF holds the secret *name/ARN*, never the value |
| **Backend** | state S3 bucket, DynamoDB lock table, state key | `terraform init -backend-config=...` |

## How each track maps here

- **A — IaC:** all of `modules/` + `envs/` (compute, database, networking as reusable modules).
- **B — Security:** `modules/security` (least-privilege IRSA, KMS, Secrets Manager, WAFv2),
  consumed by every other module.
- **C — Cost:** `single_nat_gateway`, Spot node group + Karpenter, `enable_global_db`/`enable_dr`
  toggles, shared `tags`, and AWS Budgets in `observability`. See `../IMPLEMENTATION-PLAN.md` §C
  for the full strategy table.
- **D — API:** application code lives in [`../api/product-service`](../api/product-service).

## Validate locally (no AWS account, no apply)

Terraform is not installed in every environment; install it (>= 1.5) then:

```bash
cd infra
terraform fmt -recursive -check

# Per environment root — backend disabled so no real bucket is needed:
terraform -chdir=envs/dev init -backend=false
terraform -chdir=envs/dev validate

# Optional security scanning:
tfsec .        # or: checkov -d .
tflint --recursive
```

`validate` type-checks module wiring and variable references without contacting AWS.
`init -backend=false` skips remote-state configuration. Supplying a `*.tfvars` is only needed
for `plan`/`apply`, not for `validate`.

## Deploy (requires a real account — out of scope for the reference)

```bash
cd infra/envs/dev
cp dev.tfvars.example dev.tfvars   # fill in the REQUIRES REAL VALUE entries
terraform init \
  -backend-config="bucket=<your-state-bucket>" \
  -backend-config="dynamodb_table=<your-lock-table>" \
  -backend-config="region=<region>" \
  -backend-config="key=ecommerce/dev/terraform.tfstate"
terraform plan  -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```
