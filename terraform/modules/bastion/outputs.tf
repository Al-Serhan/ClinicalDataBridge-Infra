output "instance_id" {
  description = "EC2 instance ID of the bastion host"
  value       = aws_instance.bastion.id
}

output "public_ip" {
  description = "Public IP address of the bastion host for SSH access"
  value       = aws_instance.bastion.public_ip
}

output "security_group_id" {
  description = "Security group ID attached to the bastion host"
  value       = aws_security_group.bastion.id
}

output "bastion_hostname" {
  description = "SSH connection string for the bastion host (username@ip)"
  value       = "ec2-user@${aws_instance.bastion.public_ip}"
}
