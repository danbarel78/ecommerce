output "cluster_arn" {
  description = "MSK cluster ARN."
  value       = aws_msk_cluster.this.arn
}

output "bootstrap_brokers_sasl_iam" {
  description = "SASL/IAM bootstrap broker connection string."
  value       = aws_msk_cluster.this.bootstrap_brokers_sasl_iam
}

output "bootstrap_brokers_tls" {
  description = "TLS bootstrap broker connection string."
  value       = aws_msk_cluster.this.bootstrap_brokers_tls
}

output "security_group_id" {
  description = "MSK security group id."
  value       = aws_security_group.msk.id
}
