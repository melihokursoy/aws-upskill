output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the primary public subnet (ALB, NAT Gateway)."
  value       = aws_subnet.public.id
}

output "public_subnet_ids" {
  description = "IDs of both public subnets (pass to ALB — AWS requires 2 AZs)."
  value       = [aws_subnet.public.id, aws_subnet.public_2.id]
}

output "private_subnet_id" {
  description = "ID of the primary private subnet (ECS tasks, RDS instance)."
  value       = aws_subnet.private.id
}

output "private_subnet_id_2" {
  description = "ID of the secondary private subnet (AZ2 — required by RDS DB subnet group)."
  value       = aws_subnet.private_2.id
}

output "nat_gateway_ip" {
  description = "Elastic IP of the NAT Gateway."
  value       = aws_eip.nat.public_ip
}

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID of the private route table."
  value       = aws_route_table.private.id
}
