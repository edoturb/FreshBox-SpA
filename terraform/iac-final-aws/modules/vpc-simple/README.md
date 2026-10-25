# terraform-aws-vpc-simple

Módulo Terraform reutilizable que crea una VPC básica en AWS con:
- 1 subred pública (con ruta a Internet Gateway)
- 1 subred privada
- Internet Gateway y tabla de rutas pública
- Security Group base (SSH restringido + HTTP abierto)

## Uso básico

```hcl
module "network" {
  source  = "git::https://github.com/<tu-usuario>/terraform-aws-vpc-simple.git?ref=v1.0.0"

  environment          = "dev"
  owner                = "nombre-estudiante"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidr   = "10.0.1.0/24"
  private_subnet_cidr  = "10.0.2.0/24"
  availability_zone    = "us-east-1a"
  allowed_ssh_cidr     = "190.100.50.0/32" # tu IP pública, nunca 0.0.0.0/0
}
```

Ver ejemplo completo en [`examples/basic`](./examples/basic).

## Requisitos

| Nombre | Versión |
|---|---|
| terraform | >= 1.6.0 |
| aws provider | >= 5.0 |

## Inputs

| Variable | Descripción | Tipo | Default | Requerido |
|---|---|---|---|---|
| environment | Nombre del ambiente | string | - | sí |
| owner | Responsable del recurso (tag) | string | - | sí |
| vpc_cidr | CIDR de la VPC | string | 10.0.0.0/16 | no |
| public_subnet_cidr | CIDR subred pública | string | 10.0.1.0/24 | no |
| private_subnet_cidr | CIDR subred privada | string | 10.0.2.0/24 | no |
| availability_zone | AZ de despliegue | string | us-east-1a | no |
| allowed_ssh_cidr | CIDR permitido para SSH | string | 10.0.0.0/16 | no |
| tags | Tags adicionales | map(string) | {} | no |

## Outputs

| Nombre | Descripción |
|---|---|
| vpc_id | ID de la VPC |
| public_subnet_id | ID de la subred pública |
| private_subnet_id | ID de la subred privada |
| security_group_id | ID del security group base |

## Dependencias

Ninguna dependencia externa a AWS provider. El módulo es autocontenido.

## Versionado

Este módulo sigue [Semantic Versioning 2.0.0](https://semver.org/lang/es/). Ver [CHANGELOG.md](../../CHANGELOG.md).

- **MAJOR**: cambios incompatibles en variables/outputs.
- **MINOR**: nuevas funcionalidades retrocompatibles (ej: nueva subred opcional).
- **PATCH**: correcciones de bugs o documentación.
