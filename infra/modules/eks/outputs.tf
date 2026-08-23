output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 CA data for kubeconfig."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN for IRSA (feed into the security module)."
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL without scheme, for IRSA trust conditions."
  value       = replace(aws_iam_openid_connect_provider.this.url, "https://", "")
}

output "node_security_group_id" {
  description = "Worker node security group id (allow this on data-tier SGs)."
  value       = aws_security_group.node.id
}

output "karpenter_role_arn" {
  description = "Karpenter controller IRSA role ARN (null if disabled)."
  value       = var.enable_karpenter ? aws_iam_role.karpenter[0].arn : null
}
