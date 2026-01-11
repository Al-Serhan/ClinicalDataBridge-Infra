output "vpc_id" {
  description = "ID of the VPC created for the infrastructure"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_id" {
  description = "ID of the public subnet for bastion host and NAT gateway"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of the private subnet for air-gapped resources"
  value       = aws_subnet.private.id
}

output "nat_gateway_id" {
  description = "ID of the NAT gateway for private subnet internet access"
  value       = aws_nat_gateway.nat.id
}

output "public_security_group_id" {
  description = "Security group ID for public subnet resources"
  value       = aws_security_group.public.id
}

output "private_security_group_id" {
  description = "Security group ID for private subnet resources"
  value       = aws_security_group.private.id
}
