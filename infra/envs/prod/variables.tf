variable "region" {
  description = "REQUIRES REAL VALUE — primary AWS region (e.g. us-east-1)."
  type        = string
}

variable "azs" {
  description = "REQUIRES REAL VALUE — Availability Zones to span (3 for HA)."
  type        = list(string)
}

variable "owner" {
  description = "Owner tag value for cost attribution."
  type        = string
  default     = "platform-team"
}

variable "acm_certificate_arn" {
  description = "REQUIRES REAL VALUE — ACM cert ARN for the ALB HTTPS listener."
  type        = string
}

variable "cloudfront_acm_certificate_arn" {
  description = "REQUIRES REAL VALUE — ACM cert ARN in us-east-1 for CloudFront (if using custom domain)."
  type        = string
  default     = ""
}

variable "cloudfront_aliases" {
  description = "REQUIRES REAL VALUE — custom domain CNAMEs for CloudFront."
  type        = list(string)
  default     = []
}

variable "eks_public_access_cidrs" {
  description = "REQUIRES REAL VALUE — CIDRs allowed to reach the EKS API endpoint (if public)."
  type        = list(string)
  default     = []
}

variable "dr_msk_cluster_arn" {
  description = "REQUIRES REAL VALUE — DR-region MSK cluster ARN for cross-region replication."
  type        = string
  default     = ""
}

variable "budget_notification_emails" {
  description = "REQUIRES REAL VALUE — emails for AWS Budgets alerts."
  type        = list(string)
  default     = []
}
