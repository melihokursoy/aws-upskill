output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet (ALB)."
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of the private subnet (ECS tasks, RDS)."
  value       = aws_subnet.private.id
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
