variable "name" {
  description = "Name prefix for all network resources (e.g. ecommerce-dev)."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Non-secret; safe default provided."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "REQUIRES REAL VALUE — list of Availability Zone names to span (e.g. [\"us-east-1a\",\"us-east-1b\",\"us-east-1c\"]). Must match var.region's AZs. Architecture spans 3 AZs (ARCHITECTURE.md §4.1.3)."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (ALB + NAT), one per AZ."
  type        = list(string)
  default     = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private application subnets (EKS nodes), one per AZ."
  type        = list(string)
  default     = ["10.0.48.0/20", "10.0.64.0/20", "10.0.80.0/20"]
}

variable "private_data_subnet_cidrs" {
  description = "CIDR blocks for private data subnets (Aurora/Redis/MSK/OpenSearch), one per AZ. No route to internet."
  type        = list(string)
  default     = ["10.0.96.0/20", "10.0.112.0/20", "10.0.128.0/20"]
}

variable "single_nat_gateway" {
  description = "Cost toggle (Track C): true = one shared NAT gateway (dev); false = one NAT per AZ (prod HA)."
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs to CloudWatch for network audit."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags applied to every resource (env/service/owner)."
  type        = map(string)
  default     = {}
}
