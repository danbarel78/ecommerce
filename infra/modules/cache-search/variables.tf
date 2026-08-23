variable "name" {
  description = "Name prefix (e.g. ecommerce-dev)."
  type        = string
}

variable "vpc_id" {
  description = "VPC id for security groups."
  type        = string
}

variable "subnet_ids" {
  description = "Private data subnet ids for Redis + OpenSearch."
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security group ids allowed to connect (e.g. EKS node SG)."
  type        = list(string)
  default     = []
}

# --- Redis (ElastiCache) ---
variable "redis_node_type" {
  description = "ElastiCache node type. dev: cache.t4g.micro; prod: cache.r6g.large+."
  type        = string
  default     = "cache.t4g.micro"
}

variable "redis_replicas_per_node_group" {
  description = "Read replicas per shard. >=1 enables multi-AZ automatic failover."
  type        = number
  default     = 1
}

variable "redis_num_node_groups" {
  description = "Number of shards (node groups) for cluster mode."
  type        = number
  default     = 1
}

variable "redis_engine_version" {
  description = "Redis engine version."
  type        = string
  default     = "7.1"
}

variable "redis_auth_secret_arn" {
  description = "REQUIRES REAL VALUE — Secrets Manager ARN holding the Redis AUTH token (security module). Value never set in TF."
  type        = string
}

# --- OpenSearch ---
variable "opensearch_engine_version" {
  description = "OpenSearch engine version."
  type        = string
  default     = "OpenSearch_2.11"
}

variable "opensearch_instance_type" {
  description = "OpenSearch data node instance type."
  type        = string
  default     = "t3.small.search"
}

variable "opensearch_instance_count" {
  description = "OpenSearch data node count (multiple of AZ count for zone awareness)."
  type        = number
  default     = 3
}

variable "opensearch_az_count" {
  description = "Number of AZs for OpenSearch zone awareness (2 or 3)."
  type        = number
  default     = 3
}

variable "kms_cache_key_arn" {
  description = "REQUIRES REAL VALUE — KMS key ARN for Redis at-rest encryption (security module, cache domain)."
  type        = string
}

variable "kms_search_key_arn" {
  description = "REQUIRES REAL VALUE — KMS key ARN for OpenSearch at-rest encryption (security module, search domain)."
  type        = string
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
