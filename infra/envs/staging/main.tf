# ---------------------------------------------------------------------------
# STAGING environment root — prod-like topology at reduced scale.
# NAT-per-AZ (HA parity), moderate instances, no cross-region DR.
# ---------------------------------------------------------------------------

locals {
  env  = "staging"
  name = "ecommerce-staging"
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
  single_nat_gateway = false # HA parity with prod
  tags               = local.tags
}

module "eks" {
  source = "../../modules/eks"

  name                   = local.name
  vpc_id                 = module.network.vpc_id
  private_app_subnet_ids = module.network.private_app_subnet_ids
  endpoint_public_access = true
  public_access_cidrs    = var.eks_public_access_cidrs

  on_demand_desired_size = 2
  spot_desired_size      = 2
  spot_max_size          = 15
  tags                   = local.tags
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
  }

  managed_secrets = {
    aurora-master = { description = "Aurora master credentials (staging)", rotation_days = 30 }
    redis-auth    = { description = "Redis AUTH token (staging)", rotation_days = 30 }
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
  enable_global_db           = false
  deletion_protection        = false
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
  redis_node_type               = "cache.t4g.medium"
  redis_replicas_per_node_group = 1
  opensearch_instance_type      = "t3.medium.search"
  tags                          = local.tags
}

module "eventing" {
  source = "../../modules/eventing"

  name                       = local.name
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.private_data_subnet_ids
  allowed_security_group_ids = [module.eks.node_security_group_id]
  kms_key_arn                = module.security.kms_key_arns["eventing"]
  broker_instance_type       = "kafka.t3.small"
  broker_count               = 3
  enable_dr                  = false
  tags                       = local.tags
}

module "loadbalancer" {
  source = "../../modules/loadbalancer"

  name                = local.name
  vpc_id              = module.network.vpc_id
  public_subnet_ids   = module.network.public_subnet_ids
  acm_certificate_arn = var.acm_certificate_arn
  web_acl_arn         = module.security.web_acl_arn
  enable_cloudfront   = true
  tags                = local.tags
}

module "observability" {
  source = "../../modules/observability"

  name                       = local.name
  eks_oidc_provider_arn      = module.eks.oidc_provider_arn
  eks_oidc_provider_url      = module.eks.oidc_provider_url
  log_retention_days         = 60
  monthly_budget_usd         = 1000
  budget_notification_emails = var.budget_notification_emails
  tags                       = local.tags
}
