output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "EC2 Public IP"
  value       = aws_instance.web.public_ip
}

output "public_dns" {
  description = "EC2 Public DNS"
  value       = aws_instance.web.public_dns
}

output "application_url" {
  description = "UI UX Application URL"
  value       = "http://${aws_instance.web.public_ip}:3000"
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "security_group_id" {
  value = aws_security_group.web_sg.id
}