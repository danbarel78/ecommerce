output "redis_primary_endpoint" {
  description = "Redis primary endpoint address."
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "Redis reader endpoint address."
  value       = aws_elasticache_replication_group.redis.reader_endpoint_address
}

output "redis_security_group_id" {
  description = "Redis security group id."
  value       = aws_security_group.redis.id
}

output "opensearch_endpoint" {
  description = "OpenSearch domain endpoint."
  value       = aws_opensearch_domain.this.endpoint
}

output "opensearch_security_group_id" {
  description = "OpenSearch security group id."
  value       = aws_security_group.opensearch.id
}
