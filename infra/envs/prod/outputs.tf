output "vpc_id" {
  value = module.network.vpc_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "aurora_endpoint" {
  value = module.database.cluster_endpoint
}

output "aurora_proxy_endpoint" {
  value = module.database.proxy_endpoint
}

output "aurora_global_cluster_id" {
  value = module.database.global_cluster_id
}

output "redis_primary_endpoint" {
  value = module.cache_search.redis_primary_endpoint
}

output "opensearch_endpoint" {
  value = module.cache_search.opensearch_endpoint
}

output "msk_bootstrap_brokers" {
  value = module.eventing.bootstrap_brokers_sasl_iam
}

output "alb_dns_name" {
  value = module.loadbalancer.alb_dns_name
}

output "cloudfront_domain_name" {
  value = module.loadbalancer.cloudfront_domain_name
}
