# Module: loadbalancer

Application Load Balancer (multi-AZ, HTTPS with HTTP→HTTPS redirect, IP-target group for
EKS pods) plus an optional CloudFront distribution with WAF association. Implements the
edge/ingress layer in ARCHITECTURE.md §4.1.2.

## Usage

```hcl
module "loadbalancer" {
  source = "../../modules/loadbalancer"

  name                = "ecommerce-dev"
  vpc_id              = module.network.vpc_id
  public_subnet_ids   = module.network.public_subnet_ids
  acm_certificate_arn = "arn:aws:acm:...:certificate/..." # REQUIRES REAL VALUE
  web_acl_arn         = module.security.web_acl_arn
  tags                = { env = "dev" }
}
```

## Outputs
`alb_arn`, `alb_dns_name`, `alb_security_group_id`, `target_group_arn`,
`cloudfront_domain_name`.
