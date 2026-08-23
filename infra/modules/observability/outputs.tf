output "log_group_names" {
  description = "Map of service -> CloudWatch log group name."
  value       = { for k, v in aws_cloudwatch_log_group.service : k => v.name }
}

output "otel_role_arn" {
  description = "OTel collector IRSA role ARN (null if OIDC not supplied)."
  value       = var.eks_oidc_provider_arn == "" ? null : aws_iam_role.otel[0].arn
}
