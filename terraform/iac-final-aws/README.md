# Evaluación Final Transversal – Infraestructura como Código II (AUY1105)

**Estudiante:** [tu nombre]
**Repositorio del módulo (Terraform Registry):** [pegar link cuando esté publicado]
**Repositorio de este proyecto:** [pegar link de GitHub]

---

## 1. Introducción

Este proyecto consolida el trabajo desarrollado en los Parciales 1, 2 y 3 de la
asignatura, integrando en una única solución de Infraestructura como Código
(IaC) los siguientes componentes: [ajusta este párrafo a lo que realmente hiciste
en cada parcial]

- **Parcial 1:** flujo de trabajo colaborativo con Git/GitHub, revisiones de
  código mediante Pull Requests, y análisis estático de código (TFLint, Checkov).
- **Parcial 2:** definición de políticas de seguridad como código (OPA/Rego)
  y un sistema de permisos automatizado que evalúa cambios propuestos antes
  de permitir su despliegue.
- **Parcial 3:** desarrollo de un módulo de Terraform reutilizable, documentado
  y versionado semánticamente, publicado como referencia consumible.

La solución final despliega una infraestructura de red básica en AWS (VPC,
subredes, Security Group e instancia EC2) utilizando Terraform, con un pipeline
CI/CD en GitHub Actions que automatiza validación, análisis de calidad,
aplicación de políticas de seguridad y despliegue.

## 2. Alcance

**Objetivos a cumplir:**
- Desplegar infraestructura de red reproducible y segura en AWS mediante un
  módulo Terraform reutilizable.
- Automatizar el ciclo de vida del despliegue (CI/CD) con gates de calidad y
  seguridad obligatorios antes de aplicar cambios.
- Mantener trazabilidad y gobierno mediante Pull Requests, políticas como
  código y versionado semántico.

**Recursos necesarios:**
- Cuenta AWS (capa gratuita) con usuario IAM con permisos programáticos.
- Cuenta de GitHub (repositorio público para publicar el módulo en el Terraform Registry).
- Terraform CLI >= 1.6, AWS CLI, TFLint, Checkov, OPA/Conftest instalados localmente.

**Criterios de éxito:**
- `terraform plan`/`apply` se ejecutan sin errores contra AWS.
- El pipeline de CI bloquea automáticamente un PR que viole una política de
  seguridad (ej. SSH abierto a `0.0.0.0/0`) o que falle análisis estático.
- El despliegue a `main` requiere aprobación manual (gate de permisos).
- El módulo está documentado, versionado (tags `vX.Y.Z`) y es reutilizable.

## 3. Diseño de la solución

### 3.1 Componentes principales

| Componente | Herramienta | Función |
|---|---|---|
| Infraestructura | Terraform + AWS Provider | VPC, subredes, IGW, Security Group, EC2 |
| Módulo reutilizable | `modules/vpc-simple` | Encapsula la red, versionado semánticamente |
| Control de versiones | Git / GitHub | Historial, ramas, Pull Requests |
| Revisión de código | GitHub PR + CODEOWNERS | Obliga revisión antes de fusionar |
| Análisis estático | TFLint, Checkov | Calidad de código y vulnerabilidades |
| Políticas de seguridad | OPA / Conftest (Rego) | Reglas de cumplimiento como código |
| Sistema de permisos | GitHub Branch Protection + Environments | Permite/deniega merge y apply automáticamente |
| CI/CD | GitHub Actions | `terraform-ci.yml` (validación en PR) y `terraform-cd.yml` (despliegue en main) |
| Estado remoto | S3 + DynamoDB (lock) | Estado centralizado y bloqueo de concurrencia |

### 3.2 Flujo de trabajo (de código a despliegue)

1. Se crea una rama a partir de `main` y se modifica código Terraform.
2. Se abre un Pull Request → se ejecuta `terraform-ci.yml`:
   - `terraform fmt` y `terraform validate`
   - TFLint y Checkov (análisis estático)
   - `terraform plan` convertido a JSON y evaluado por Conftest contra las
     políticas de `policy/` (sistema de permisos automatizado: si una política
     falla, el check falla y GitHub Branch Protection bloquea el merge).
3. Un revisor (CODEOWNERS) aprueba el PR dejando comentarios documentados.
4. Al hacer merge a `main`, se dispara `terraform-cd.yml`, que requiere
   aprobación manual en el Environment `production-approval` antes de ejecutar
   `terraform apply`.
5. El estado se guarda remotamente en S3 con bloqueo vía DynamoDB.

### 3.3 Políticas de seguridad implementadas

- **`require_tags.rego`**: exige tags `Environment` y `Owner` en recursos
  clave (trazabilidad y cumplimiento).
- **`deny_open_ssh.rego`**: deniega cualquier Security Group que exponga el
  puerto 22 a `0.0.0.0/0`.

Ambas cuentan con pruebas unitarias (`policy/tests/`) ejecutadas en el pipeline.

## 4. Diagrama de la arquitectura

**Arquitectura de red en AWS:**

![Arquitectura de red](docs/diagrama-arquitectura-red.svg)

**Flujo del pipeline CI/CD:**

![Pipeline CI/CD](docs/diagrama-pipeline-cicd.svg)

## 5. Conclusiones

La solución implementada aborda de manera integral los requisitos definidos
en los Parciales 1, 2 y 3: se automatiza el ciclo de vida completo de la
infraestructura desde la revisión de código hasta el despliegue en la nube,
incorporando controles de calidad (análisis estático), controles de
seguridad (políticas como código con evaluación automatizada) y buenas
prácticas de modularidad, documentación y versionado semántico. Esto asegura
un flujo de entrega continuo, auditable y alineado con estándares de la
industria para Infraestructura como Código.

[Amplía este párrafo con tu experiencia concreta: qué funcionó, qué tuviste
que ajustar, qué aprendiste.]

## 6. Anexos

- **GitHub Repository:** [link a este repositorio]
- **Terraform Registry:** [link al módulo publicado, ej. `https://registry.terraform.io/modules/<usuario>/vpc-simple/aws/1.0.0`]
- **Evidencia (capturas):** ver carpeta `docs/evidencia/`

---

## Cómo desplegar este proyecto (para el docente/replicación)

```bash
cd environments/dev
terraform init
terraform plan -var="owner=nombre" -var="allowed_ssh_cidr=TU.IP/32"
terraform apply -var="owner=nombre" -var="allowed_ssh_cidr=TU.IP/32"
```

Ver [`modules/vpc-simple/README.md`](modules/vpc-simple/README.md) para la
documentación del módulo reutilizable.
