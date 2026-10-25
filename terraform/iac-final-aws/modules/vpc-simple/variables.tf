variable "environment" {
  description = "Nombre del ambiente (ej: dev, staging, prod). Se usa para nombrar y etiquetar recursos."
  type        = string
}

variable "vpc_cidr" {
  description = "Bloque CIDR de la VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Bloque CIDR de la subred pública."
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "Bloque CIDR de la subred privada."
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "Zona de disponibilidad donde se crean las subredes."
  type        = string
  default     = "us-east-1a"
}

variable "allowed_ssh_cidr" {
  description = "Bloque CIDR permitido para acceso SSH (nunca usar 0.0.0.0/0 en producción)."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = var.allowed_ssh_cidr != "0.0.0.0/0"
    error_message = "Por politica de seguridad, allowed_ssh_cidr no puede ser 0.0.0.0/0."
  }
}

variable "owner" {
  description = "Responsable/dueño del recurso, usado en tags obligatorios."
  type        = string
}

variable "tags" {
  description = "Tags adicionales para aplicar a todos los recursos del módulo."
  type        = map(string)
  default     = {}
}
