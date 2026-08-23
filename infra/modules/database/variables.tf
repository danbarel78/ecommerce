variable "name" {
  description = "Name prefix (e.g. ecommerce-dev)."
  type        = string
}

variable "subnet_ids" {
  description = "Private data subnet ids for the DB subnet group (from network module)."
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC id for the security group."
  type        = string
}

variable "allowed_security_group_ids" {
  description = "Security group ids allowed to connect to the DB (e.g. EKS node SG, RDS Proxy SG)."
  type        = list(string)
  default     = []
}

variable "engine_version" {
  description = "Aurora PostgreSQL engine version."
  type        = string
  default     = "15.4"
}

variable "instance_class" {
  description = "Instance class for writer + replicas. dev: db.t4g.medium; prod: db.r6g.large+."
  type        = string
  default     = "db.t4g.medium"
}

variable "replica_count" {
  description = "Number of read replicas (in addition to the writer), spread across AZs."
  type        = number
  default     = 2
}

variable "database_name" {
  description = "Initial database name."
  type        = string
  default     = "ecommerce"
}

variable "master_username" {
  description = "Master DB username."
  type        = string
  default     = "ecommerce_admin"
}

variable "master_secret_arn" {
  description = "REQUIRES REAL VALUE — Secrets Manager ARN holding the master password (from the security module). The value is never set in Terraform."
  type        = string
}

variable "kms_key_arn" {
  description = "REQUIRES REAL VALUE — KMS key ARN for encryption at rest (security module, database domain)."
  type        = string
}

variable "enable_global_db" {
  description = "Create an Aurora Global Database for cross-region DR (ARCHITECTURE.md §4.1.3). Off in dev to save cost (Track C)."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Automated backup / PITR retention window."
  type        = number
  default     = 35
}

variable "enable_rds_proxy" {
  description = "Provision RDS Proxy for connection pooling (survives writer failover, §4.4)."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Prevent accidental cluster deletion. Enable in prod."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
