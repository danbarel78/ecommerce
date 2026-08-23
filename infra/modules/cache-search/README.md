# Module: cache-search

Multi-AZ ElastiCache Redis (sessions, cart, hot-product cache, stock-reservation
counters) and a zone-aware OpenSearch domain (catalog/faceted search projection).
Both encrypted in transit and at rest. Implements ARCHITECTURE.md §4.1.4 / §4.2.

Redis AUTH token comes from Secrets Manager (`redis_auth_secret_arn`) — never in TF.

## Usage

```hcl
module "cache_search" {
  source = "../../modules/cache-search"

  name                       = "ecommerce-dev"
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.private_data_subnet_ids
  allowed_security_group_ids = [module.eks.node_security_group_id]
  redis_auth_secret_arn      = module.security.secret_arns["redis-auth"] # REQUIRES REAL VALUE
  kms_cache_key_arn          = module.security.kms_key_arns["cache"]      # REQUIRES REAL VALUE
  kms_search_key_arn         = module.security.kms_key_arns["search"]     # REQUIRES REAL VALUE
  tags                       = { env = "dev" }
}
```

## Outputs
`redis_primary_endpoint`, `redis_reader_endpoint`, `redis_security_group_id`,
`opensearch_endpoint`, `opensearch_security_group_id`.
