output "kms_key_arns" {
  description = "Map of domain -> KMS key ARN."
  value       = { for k, v in aws_kms_key.domain : k => v.arn }
}

output "kms_key_ids" {
  description = "Map of domain -> KMS key id."
  value       = { for k, v in aws_kms_key.domain : k => v.key_id }
}

output "irsa_role_arns" {
  description = "Map of service -> IRSA IAM role ARN (annotate the K8s ServiceAccount with this)."
  value       = { for k, v in aws_iam_role.irsa : k => v.arn }
}

output "secret_arns" {
  description = "Map of secret key -> Secrets Manager ARN."
  value       = { for k, v in aws_secretsmanager_secret.this : k => v.arn }
}

output "web_acl_arn" {
  description = "WAFv2 web ACL ARN to associate with CloudFront/ALB."
  value       = aws_wafv2_web_acl.this.arn
}
