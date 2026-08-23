# Module: security (Track B)

Least-privilege IAM (IRSA factory), KMS CMKs (one per data domain), Secrets Manager
secret definitions with optional rotation, and a WAFv2 web ACL. Implements the security
posture in ARCHITECTURE.md §4.4.

## What it does NOT do
- **No secret values.** Only secret *definitions* live here; values are set out-of-band
  (CI / console / rotation lambda), never in Terraform state.
- **No wildcards.** IRSA policies are built from explicit `actions`/`resources` you pass in.

## Usage

```hcl
module "security" {
  source = "../../modules/security"

  name = "ecommerce-dev"

  # Populate after the eks module exists (its OIDC provider). Empty = skip IRSA roles.
  eks_oidc_provider_arn = module.eks.oidc_provider_arn # REQUIRES REAL VALUE at apply
  eks_oidc_provider_url = module.eks.oidc_provider_url

  irsa_service_accounts = {
    order = {
      namespace       = "app"
      service_account = "order"
      policy_statements = [{
        sid       = "ReadOrderSecret"
        actions   = ["secretsmanager:GetSecretValue"]
        resources = [module.security.secret_arns["order-db"]]
      }]
    }
  }

  managed_secrets = {
    aurora-master = { description = "Aurora master credentials", rotation_days = 30 }
  }

  waf_scope      = "REGIONAL" # or CLOUDFRONT (create in us-east-1)
  waf_rate_limit = 2000
  tags           = { env = "dev" }
}
```

## Outputs
`kms_key_arns`, `kms_key_ids`, `irsa_role_arns`, `secret_arns`, `web_acl_arn`.
