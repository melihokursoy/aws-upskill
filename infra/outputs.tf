# ---------------------------------------------------------------------------
# Root Module Outputs
#
# Aggregates outputs from all modules. These are the single source of truth
# for all infrastructure identifiers — no magic strings in application code.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# VPC & Networking
# ---------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_id" {
  description = "ID of the public subnet (ALB lives here)."
  value       = module.vpc.public_subnet_id
}

output "private_subnet_id" {
  description = "ID of the private subnet (ECS tasks and RDS live here)."
  value       = module.vpc.private_subnet_id
}

output "nat_gateway_ip" {
  description = "Elastic IP of the NAT Gateway (outbound IP for private subnet traffic)."
  value       = module.vpc.nat_gateway_ip
}
