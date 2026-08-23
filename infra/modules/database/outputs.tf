output "cluster_endpoint" {
  description = "Aurora writer endpoint."
  value       = aws_rds_cluster.this.endpoint
}

output "reader_endpoint" {
  description = "Aurora reader endpoint (load-balanced across replicas)."
  value       = aws_rds_cluster.this.reader_endpoint
}

output "proxy_endpoint" {
  description = "RDS Proxy endpoint (use this from services when enabled)."
  value       = var.enable_rds_proxy ? aws_db_proxy.this[0].endpoint : null
}

output "security_group_id" {
  description = "Aurora security group id."
  value       = aws_security_group.aurora.id
}

output "cluster_identifier" {
  description = "Aurora cluster identifier."
  value       = aws_rds_cluster.this.cluster_identifier
}

output "global_cluster_id" {
  description = "Aurora Global cluster id (null if DR disabled)."
  value       = var.enable_global_db ? aws_rds_global_cluster.this[0].id : null
}
