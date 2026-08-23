# Module: database

Aurora PostgreSQL cluster (1 writer + N replicas across AZs), optional Aurora Global
Database for cross-region DR, and RDS Proxy for connection pooling. Implements
ARCHITECTURE.md §4.1.3 / §4.3.1 / §4.4.

Master password is read from a Secrets Manager secret (`master_secret_arn`) — never set
in Terraform. `lifecycle.ignore_changes = [master_password]` lets rotation own it.

## Usage

```hcl
module "database" {
  source = "../../modules/database"

  name                       = "ecommerce-dev"
  subnet_ids                 = module.network.private_data_subnet_ids
  vpc_id                     = module.network.vpc_id
  allowed_security_group_ids = [module.eks.node_security_group_id]
  master_secret_arn          = module.security.secret_arns["aurora-master"] # REQUIRES REAL VALUE
  kms_key_arn                = module.security.kms_key_arns["database"]      # REQUIRES REAL VALUE
  instance_class             = "db.t4g.medium"
  replica_count              = 2
  enable_global_db           = false # true in prod for DR
  tags                       = { env = "dev" }
}
```

## Outputs
`cluster_endpoint`, `reader_endpoint`, `proxy_endpoint`, `security_group_id`,
`cluster_identifier`, `global_cluster_id`.
