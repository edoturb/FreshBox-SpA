# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.
El formato sigue [Keep a Changelog](https://keepachangelog.com/es/1.0.0/) y
este proyecto usa [Semantic Versioning](https://semver.org/lang/es/).

## [1.1.0] - fecha-pendiente
### Added
- Regla de TFLint `terraform_documented_variables` y `terraform_documented_outputs`.
- Política OPA de tags obligatorios (`require_tags.rego`).

## [1.0.0] - fecha-pendiente
### Added
- Módulo `vpc-simple` inicial: VPC, subred pública/privada, IGW, route table, security group.
- Pipeline CI/CD con GitHub Actions (fmt, validate, tflint, checkov, OPA/conftest).
- Ambiente `dev` de ejemplo consumiendo el módulo.
