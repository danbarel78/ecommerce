# ---------------------------------------------------------------------------
# PROD environment root — HA + DR sizing.
# NAT-per-AZ, larger instances, cross-region DR (Aurora Global DB + MSK Replicator),
# deletion protection on. Mirrors ARCHITECTURE.md §4.1.3 warm-standby DR.
# ---------------------------------------------------------------------------

locals {
  env  = "prod"
  name = "ecommerce-prod"
  tags = {
    env     = local.env
    service = "ecommerce-platform"
    owner   = var.owner
  }
}

module "network" {
  source = "../../modules/network"

  name               = local.name
  azs                = var.azs
  single_nat_gateway = false # prod: NAT per AZ for HA
  tags               = local.tags
}

module "eks" {
  source = "../../modules/eks"

  name                   = local.name
  vpc_id                 = module.network.vpc_id
  private_app_subnet_ids = module.network.private_app_subnet_ids
  endpoint_public_access = false # private endpoint in prod
  public_access_cidrs    = var.eks_public_access_cidrs

  on_demand_instance_types = ["m6i.xlarge"]
  on_demand_desired_size   = 3
  on_demand_min_size       = 3
  on_demand_max_size       = 8
  spot_desired_size        = 3
  spot_max_size            = 30
  tags                     = local.tags
}

module "security" {
  source = "../../modules/security"

  name = local.name

  eks_oidc_provider_arn = module.eks.oidc_provider_arn
  eks_oidc_provider_url = module.eks.oidc_provider_url

  irsa_service_accounts = {
    order = {
      namespace       = "app"
      service_account = "order"
      policy_statements = [{
        sid       = "OrderReadSecret"
        actions   = ["secretsmanager:GetSecretValue"]
        resources = ["arn:aws:secretsmanager:${var.region}:*:secret:${local.name}/aurora-master-*"]
      }]
    }
    realtime = {
      namespace       = "app"
      service_account = "realtime"
      policy_statements = [{
        sid       = "RealtimeWriteLake"
        actions   = ["s3:PutObject"]
        resources = ["arn:aws:s3:::${local.name}-data-lake/realtime/*"]
      }]
    }
  }

  managed_secrets = {
    aurora-master = { description = "Aurora master credentials (prod)", rotation_days = 30 }
    redis-auth    = { description = "Redis AUTH token (prod)", rotation_days = 30 }
  }

  waf_scope = "CLOUDFRONT"
  tags      = local.tags
}

module "database" {
  source = "../../modules/database"

  name                       = local.name
  subnet_ids                 = module.network.private_data_subnet_ids
  vpc_id                     = module.network.vpc_id
  allowed_security_group_ids = [module.eks.node_security_group_id]
  master_secret_arn          = module.security.secret_arns["aurora-master"]
  kms_key_arn                = module.security.kms_key_arns["database"]
  instance_class             = "db.r6g.large"
  replica_count              = 2
  enable_global_db           = true # DR
  deletion_protection        = true
  tags                       = local.tags
}

module "cache_search" {
  source = "../../modules/cache-search"

  name                          = local.name
  vpc_id                        = module.network.vpc_id
  subnet_ids                    = module.network.private_data_subnet_ids
  allowed_security_group_ids    = [module.eks.node_security_group_id]
  redis_auth_secret_arn         = module.security.secret_arns["redis-auth"]
  kms_cache_key_arn             = module.security.kms_key_arns["cache"]
  kms_search_key_arn            = module.security.kms_key_arns["search"]
  redis_node_type               = "cache.r6g.large"
  redis_replicas_per_node_group = 2
  opensearch_instance_type      = "r6g.large.search"
  opensearch_instance_count     = 3
  tags                          = local.tags
}

module "eventing" {
  source = "../../modules/eventing"

  name                       = local.name
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.private_data_subnet_ids
  allowed_security_group_ids = [module.eks.node_security_group_id]
  kms_key_arn                = module.security.kms_key_arns["eventing"]
  broker_instance_type       = "kafka.m5.large"
  broker_count               = 3
  broker_ebs_size            = 200
  enable_dr                  = true
  dr_broker_arn              = var.dr_msk_cluster_arn
  tags                       = local.tags
}

module "loadbalancer" {
  source = "../../modules/loadbalancer"

  name                           = local.name
  vpc_id                         = module.network.vpc_id
  public_subnet_ids              = module.network.public_subnet_ids
  acm_certificate_arn            = var.acm_certificate_arn
  web_acl_arn                    = module.security.web_acl_arn
  enable_cloudfront              = true
  cloudfront_aliases             = var.cloudfront_aliases
  cloudfront_acm_certificate_arn = var.cloudfront_acm_certificate_arn
  tags                           = local.tags
}

module "observability" {
  source = "../../modules/observability"

  name                       = local.name
  eks_oidc_provider_arn      = module.eks.oidc_provider_arn
  eks_oidc_provider_url      = module.eks.oidc_provider_url
  log_retention_days         = 90
  monthly_budget_usd         = 5000
  budget_notification_emails = var.budget_notification_emails
  tags                       = local.tags
}
