# Module: eventing

Amazon MSK (managed Apache Kafka) — the event backbone. Multi-AZ brokers, TLS +
SASL/IAM auth, encryption at rest, CloudWatch logging, and optional cross-region
MSK Replicator for DR (closes the Kafka-DR gap in ARCHITECTURE.md §4.1.3).

## Usage

```hcl
module "eventing" {
  source = "../../modules/eventing"

  name                       = "ecommerce-dev"
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.private_data_subnet_ids
  allowed_security_group_ids = [module.eks.node_security_group_id]
  kms_key_arn                = module.security.kms_key_arns["eventing"] # REQUIRES REAL VALUE
  broker_count               = 3
  enable_dr                  = false # true in prod; set dr_broker_arn
  tags                       = { env = "dev" }
}
```

## Outputs
`cluster_arn`, `bootstrap_brokers_sasl_iam`, `bootstrap_brokers_tls`,
`security_group_id`.
