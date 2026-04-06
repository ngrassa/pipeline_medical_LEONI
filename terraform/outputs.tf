output "instance_id" {
  description = "ID de l'instance EC2"
  value       = aws_instance.server_terraform.id
}

output "elastic_ip" {
  description = "Adresse IP publique fixe (Elastic IP)"
  value       = aws_eip.server_terraform_eip.public_ip
}

output "instance_private_ip" {
  description = "Adresse IP privée de l'instance"
  value       = aws_instance.server_terraform.private_ip
}

output "public_dns" {
  description = "DNS public de l'instance"
  value       = aws_instance.server_terraform.public_dns
}

output "ssh_command" {
  description = "Commande SSH pour se connecter à l'instance"
  value       = "ssh -i ~/.ssh/vockey.pem ubuntu@${aws_eip.server_terraform_eip.public_ip}"
}

output "security_group_id" {
  description = "ID du Security Group"
  value       = aws_security_group.server_terraform_sg.id
}

output "frontend_url" {
  description = "URL du frontend React"
  value       = "http://${aws_eip.server_terraform_eip.public_ip}:5173"
}

output "backend_url" {
  description = "URL du backend Django"
  value       = "http://${aws_eip.server_terraform_eip.public_ip}:8000"
}
