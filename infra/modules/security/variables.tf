variable "name" {
  description = "Name prefix for security resources (e.g. ecommerce-dev)."
  type        = string
}

variable "kms_key_domains" {
  description = "Logical data domains that each get their own KMS CMK (least-privilege, one key per domain)."
  type        = list(string)
  default     = ["database", "cache", "search", "eventing", "s3", "secrets"]
}

variable "kms_deletion_window_days" {
  description = "Waiting period before a scheduled KMS key deletion completes."
  type        = number
  default     = 30
}

variable "eks_oidc_provider_arn" {
  description = "REQUIRES REAL VALUE — ARN of the EKS cluster OIDC provider (from the eks module) used to scope IRSA trust. Empty string disables IRSA role creation (e.g. before the cluster exists)."
  type        = string
  default     = ""
}

variable "eks_oidc_provider_url" {
  description = "REQUIRES REAL VALUE — URL (no https://) of the EKS OIDC provider, used in the IRSA trust condition."
  type        = string
  default     = ""
}

variable "irsa_service_accounts" {
  description = <<-EOT
    Map of microservice -> IRSA definition. Each service account gets an IAM role
    scoped to ONLY the actions/resources it needs (deny-by-default, no wildcards).
    Example:
      order = {
        namespace       = "app"
        service_account = "order"
        policy_statements = [{
          sid       = "OrderSecretRead"
          actions   = ["secretsmanager:GetSecretValue"]
          resources = ["arn:aws:secretsmanager:...:secret:ecommerce/order-*"]
        }]
      }
  EOT
  type = map(object({
    namespace       = string
    service_account = string
    policy_statements = list(object({
      sid       = string
      actions   = list(string)
      resources = list(string)
    }))
  }))
  default = {}
}

variable "managed_secrets" {
  description = <<-EOT
    Secrets Manager secret definitions. Only NAMES/metadata live here — actual secret
    values are set out-of-band (console/CI/rotation), never in Terraform. Set
    rotation_lambda_arn to enable automatic rotation.
  EOT
  type = map(object({
    description         = string
    rotation_lambda_arn = optional(string)
    rotation_days       = optional(number, 30)
  }))
  default = {}
}

variable "waf_scope" {
  description = "WAFv2 scope: CLOUDFRONT (edge, must be created in us-east-1) or REGIONAL (ALB/API GW)."
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["CLOUDFRONT", "REGIONAL"], var.waf_scope)
    error_message = "waf_scope must be CLOUDFRONT or REGIONAL."
  }
}

variable "waf_rate_limit" {
  description = "Rate-based rule threshold: max requests per 5 minutes per IP before blocking (edge defense; complements app rate limit in the product API)."
  type        = number
  default     = 2000
}

variable "waf_blocked_countries" {
  description = "Optional ISO-3166 country codes to geo-block. Empty = no geo blocking."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags applied to every resource."
  type        = map(string)
  default     = {}
}
