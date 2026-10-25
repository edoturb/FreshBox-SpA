output "vpc_id" {
  description = "ID de la VPC creada."
  value       = aws_vpc.this.id
}

output "public_subnet_id" {
  description = "ID de la subred pública."
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID de la subred privada."
  value       = aws_subnet.private.id
}

output "security_group_id" {
  description = "ID del security group base creado por el módulo."
  value       = aws_security_group.this.id
}
