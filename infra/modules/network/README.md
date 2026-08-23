# Module: network

VPC spanning `length(var.azs)` Availability Zones with three subnet tiers
(public / private-app / private-data), NAT gateways, VPC endpoints, and optional
flow logs. Implements ARCHITECTURE.md §4.1.2–§4.1.3.

## Usage

```hcl
module "network" {
  source = "../../modules/network"

  name               = "ecommerce-dev"
  vpc_cidr           = "10.0.0.0/16"
  azs                = ["us-east-1a", "us-east-1b", "us-east-1c"] # REQUIRES REAL VALUE
  single_nat_gateway = true # dev: cost saving; prod: false for NAT-per-AZ
  tags               = { env = "dev", service = "platform", owner = "team-x" }
}
```

## Inputs (highlights)

| Name | Required | Notes |
|------|----------|-------|
| `name` | yes | Name prefix. |
| `azs` | yes | **REQUIRES REAL VALUE** — AZ names for the target region. |
| `vpc_cidr` | no | Defaults to `10.0.0.0/16`. |
| `single_nat_gateway` | no | `true` in dev (one NAT), `false` in prod (NAT/AZ). Cost lever. |

## Outputs

`vpc_id`, `vpc_cidr`, `public_subnet_ids`, `private_app_subnet_ids`,
`private_data_subnet_ids`, `vpce_security_group_id`.
