output "instance_id" {
  value = aws_instance.private_vm.id
}

output "private_ip" {
  value = aws_instance.private_vm.private_ip
}

output "security_group_id" {
  value = aws_security_group.private_vm.id
}

output "eni_id" {
  value = aws_instance.private_vm.primary_network_interface_id
}
