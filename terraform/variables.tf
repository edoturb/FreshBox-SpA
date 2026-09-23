variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/22"
}

variable "instance_type" {
  type        = string
  default     = "t4g.small"
  description = "Graviton ARM — alineado a Mac M1 y a la tabla 2.3 del EP1"
}

variable "db_user" {
  type    = string
  default = "alumno"
}

variable "db_password" {
  type      = string
  default   = "alumno123"
  sensitive = true
}

variable "db_name" {
  type    = string
  default = "freshbox"
}

variable "lab_instance_profile" {
  type        = string
  default     = "LabInstanceProfile"
  description = "Perfil IAM de AWS Academy (SSM + ECR). No se crea en Terraform."
}

variable "backup_role_name" {
  type        = string
  default     = "AWSBackupDefaultServiceRole"
  description = "Rol de servicio de AWS Backup ya existente en Academy"
}
