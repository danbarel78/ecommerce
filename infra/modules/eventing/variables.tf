variable "name" {
  description = "Name prefix (e.g. ecommerce-dev)."
  type        = string
}

variable "vpc_id" {
  description = "VPC id for the broker security group."
  type        = string
}

variable "subnet_ids" {
  description = "Private data subnet ids (one broker per AZ)."
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security group ids allowed to reach the brokers (producers/consumers)."
  type        = list(string)
  default     = []
}

variable "kafka_version" {
  description = "Apache Kafka version for MSK."
  type        = string
  default     = "3.6.0"
}

variable "broker_instance_type" {
  description = "MSK broker instance type. dev: kafka.t3.small; prod: kafka.m5.large+."
  type        = string
  default     = "kafka.t3.small"
}

variable "broker_count" {
  description = "Number of broker nodes (multiple of AZ count; 3 for 3-AZ HA)."
  type        = number
  default     = 3
}

variable "broker_ebs_size" {
  description = "EBS volume size per broker (GB)."
  type        = number
  default     = 50
}

variable "kms_key_arn" {
  description = "REQUIRES REAL VALUE — KMS key ARN for MSK at-rest encryption (security module, eventing domain)."
  type        = string
}

variable "enable_dr" {
  description = "Provision the DR replication scaffolding (MSK Replicator config). Off in dev (Track C). ARCHITECTURE.md §4.1.3 Kafka DR gap fix."
  type        = bool
  default     = false
}

variable "dr_broker_arn" {
  description = "REQUIRES REAL VALUE — target (DR-region) MSK cluster ARN when enable_dr = true. Empty otherwise."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
