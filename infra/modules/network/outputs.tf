output "vpc_id" {
  description = "The VPC id."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "The VPC CIDR block."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet ids (ALB, NAT)."
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "Private application subnet ids (EKS nodes)."
  value       = aws_subnet.private_app[*].id
}

output "private_data_subnet_ids" {
  description = "Private data subnet ids (Aurora/Redis/MSK/OpenSearch)."
  value       = aws_subnet.private_data[*].id
}

output "vpce_security_group_id" {
  description = "Security group id used by the interface VPC endpoints."
  value       = aws_security_group.vpce.id
}
