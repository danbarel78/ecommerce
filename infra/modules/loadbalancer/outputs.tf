output "alb_arn" {
  description = "ALB ARN."
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "ALB DNS name."
  value       = aws_lb.this.dns_name
}

output "alb_security_group_id" {
  description = "ALB security group id."
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "Target group ARN (bind the EKS ingress/pods to this)."
  value       = aws_lb_target_group.this.arn
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain (null if disabled)."
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.this[0].domain_name : null
}
