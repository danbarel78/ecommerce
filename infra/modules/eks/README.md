# Module: eks (compute)

Amazon EKS cluster (portability anchor, ARCHITECTURE.md §4.2) with:
- On-Demand managed node group — critical/stateful services (checkout, order, payment).
- Spot managed node group — stateless/burst workloads (Track C cost saving).
- IAM OIDC provider for IRSA (feeds the security module's per-service roles).
- Managed addons (VPC-CNI, CoreDNS, kube-proxy, EBS-CSI).
- Optional Karpenter controller IRSA role for node right-sizing (§4.3.4).

## Usage

```hcl
module "eks" {
  source = "../../modules/eks"

  name                   = "ecommerce-dev"
  vpc_id                 = module.network.vpc_id
  private_app_subnet_ids = module.network.private_app_subnet_ids
  kubernetes_version     = "1.29"
  endpoint_public_access = true
  public_access_cidrs    = ["203.0.113.0/24"] # REQUIRES REAL VALUE (office/VPN)
  tags                   = { env = "dev" }
}
```

Wire `module.eks.oidc_provider_arn` / `oidc_provider_url` into the security module to mint
IRSA roles, and `module.eks.node_security_group_id` into the data-tier modules' allow lists.

## Outputs
`cluster_name`, `cluster_endpoint`, `cluster_certificate_authority_data`,
`oidc_provider_arn`, `oidc_provider_url`, `node_security_group_id`, `karpenter_role_arn`.
