variable "name" {
  description = "Name prefix / cluster name base (e.g. ecommerce-dev)."
  type        = string
}

variable "vpc_id" {
  description = "VPC id."
  type        = string
}

variable "private_app_subnet_ids" {
  description = "Private application subnet ids for worker nodes + control-plane ENIs."
  type        = list(string)
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.29"
}

variable "endpoint_public_access" {
  description = "Whether the EKS API endpoint is publicly reachable. Prefer false (private) in prod."
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "REQUIRES REAL VALUE (if endpoint_public_access) — CIDRs allowed to reach the public API endpoint (e.g. office/VPN ranges)."
  type        = list(string)
  default     = []
}

variable "on_demand_instance_types" {
  description = "Instance types for the On-Demand node group (critical/stateful workloads)."
  type        = list(string)
  default     = ["m6i.large"]
}

variable "on_demand_desired_size" {
  description = "Desired On-Demand node count."
  type        = number
  default     = 2
}

variable "on_demand_min_size" {
  description = "Minimum On-Demand node count."
  type        = number
  default     = 2
}

variable "on_demand_max_size" {
  description = "Maximum On-Demand node count."
  type        = number
  default     = 4
}

variable "spot_instance_types" {
  description = "Instance types for the Spot node group (stateless/burst workloads, Track C cost saving)."
  type        = list(string)
  default     = ["m6i.large", "m5.large", "m5a.large"]
}

variable "spot_desired_size" {
  description = "Desired Spot node count."
  type        = number
  default     = 2
}

variable "spot_min_size" {
  description = "Minimum Spot node count."
  type        = number
  default     = 0
}

variable "spot_max_size" {
  description = "Maximum Spot node count (burst headroom)."
  type        = number
  default     = 10
}

variable "enable_karpenter" {
  description = "Create the Karpenter controller IRSA role + node instance profile (node right-sizing, §4.3.4)."
  type        = bool
  default     = true
}

variable "cluster_addons" {
  description = "Managed EKS addons to install."
  type        = list(string)
  default     = ["vpc-cni", "coredns", "kube-proxy", "aws-ebs-csi-driver"]
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
