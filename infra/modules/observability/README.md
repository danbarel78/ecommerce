# Module: observability

Per-service CloudWatch log groups (OTel export target, ARCHITECTURE.md §4.2), an IRSA
role for the OpenTelemetry collector, and an AWS Budgets monthly cost alert (Track C
cost governance).

## Usage

```hcl
module "observability" {
  source = "../../modules/observability"

  name                       = "ecommerce-dev"
  eks_oidc_provider_arn      = module.eks.oidc_provider_arn # REQUIRES REAL VALUE
  eks_oidc_provider_url      = module.eks.oidc_provider_url
  monthly_budget_usd         = 500
  budget_notification_emails = ["finops@example.com"] # REQUIRES REAL VALUE
  tags                       = { env = "dev" }
}
```

## Outputs
`log_group_names`, `otel_role_arn`.
