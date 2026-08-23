variable "name" {
  description = "Name prefix (e.g. ecommerce-dev)."
  type        = string
}

variable "log_retention_days" {
  description = "Retention for application/platform log groups."
  type        = number
  default     = 30
}

variable "log_groups" {
  description = "Application log group short names to create (prefixed with /ecommerce/<name>/)."
  type        = list(string)
  default     = ["catalog", "cart", "checkout", "order", "payment", "auth", "realtime"]
}

variable "eks_oidc_provider_arn" {
  description = "REQUIRES REAL VALUE — EKS OIDC provider ARN for the OTel collector IRSA role. Empty disables the role."
  type        = string
  default     = ""
}

variable "eks_oidc_provider_url" {
  description = "REQUIRES REAL VALUE — EKS OIDC provider URL (no scheme) for the IRSA trust condition."
  type        = string
  default     = ""
}

variable "otel_namespace" {
  description = "Kubernetes namespace of the OpenTelemetry collector service account."
  type        = string
  default     = "observability"
}

variable "otel_service_account" {
  description = "Service account name for the OTel collector."
  type        = string
  default     = "otel-collector"
}

variable "monthly_budget_usd" {
  description = "AWS Budgets monthly cost threshold (Track C cost visibility). 0 disables the budget."
  type        = number
  default     = 0
}

variable "budget_notification_emails" {
  description = "REQUIRES REAL VALUE (if monthly_budget_usd > 0) — emails to alert when the budget threshold is crossed."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
