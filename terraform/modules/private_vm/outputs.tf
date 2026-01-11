output "instance_id" {
  description = "EC2 instance ID of the private VM"
  value       = aws_instance.private_vm.id
}

output "private_ip" {
  description = "Private IP address of the VM (accessible only via bastion)"
  value       = aws_instance.private_vm.private_ip
}

output "security_group_id" {
  description = "Security group ID attached to the private VM"
  value       = aws_security_group.private_vm.id
}

output "eni_id" {
  description = "Primary network interface ID of the private VM"
  value       = aws_instance.private_vm.primary_network_interface_id
}
