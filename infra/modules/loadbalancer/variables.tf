variable "name" {
  description = "Name prefix (e.g. ecommerce-dev)."
  type        = string
}

variable "vpc_id" {
  description = "VPC id."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet ids for the ALB."
  type        = list(string)
}

variable "acm_certificate_arn" {
  description = "REQUIRES REAL VALUE — ACM certificate ARN for the ALB HTTPS listener (account/region-specific)."
  type        = string
}

variable "ingress_cidrs" {
  description = "CIDRs allowed to reach the ALB on 80/443. Default open (edge is fronted by CloudFront+WAF)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "target_port" {
  description = "Port the EKS ingress/target group listens on."
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "Health check path on the targets."
  type        = string
  default     = "/healthz"
}

variable "enable_cloudfront" {
  description = "Create a CloudFront distribution in front of the ALB (CDN + edge cache, §4.1.2)."
  type        = bool
  default     = true
}

variable "cloudfront_aliases" {
  description = "REQUIRES REAL VALUE (if custom domain) — CNAMEs for the CloudFront distribution. Empty = use the default *.cloudfront.net domain."
  type        = list(string)
  default     = []
}

variable "cloudfront_acm_certificate_arn" {
  description = "REQUIRES REAL VALUE (if aliases set) — ACM cert ARN in us-east-1 for CloudFront. Empty = default CloudFront cert."
  type        = string
  default     = ""
}

variable "web_acl_arn" {
  description = "WAFv2 web ACL ARN to associate with CloudFront (from security module). Empty = none."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
