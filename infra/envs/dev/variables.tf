variable "region" {
  description = "REQUIRES REAL VALUE — AWS region for this environment (e.g. us-east-1)."
  type        = string
}

variable "azs" {
  description = "REQUIRES REAL VALUE — Availability Zones to span (3 for HA)."
  type        = list(string)
}

variable "owner" {
  description = "Owner tag value (team/individual) for cost attribution."
  type        = string
  default     = "platform-team"
}

variable "acm_certificate_arn" {
  description = "REQUIRES REAL VALUE — ACM cert ARN for the ALB HTTPS listener."
  type        = string
}

variable "eks_public_access_cidrs" {
  description = "REQUIRES REAL VALUE — CIDRs allowed to reach the EKS public API endpoint."
  type        = list(string)
  default     = []
}

variable "budget_notification_emails" {
  description = "REQUIRES REAL VALUE — emails for AWS Budgets alerts."
  type        = list(string)
  default     = []
}
