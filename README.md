 FreshBox SpA — Arquitectura Cloud EP2: EKS + RDS MySQL Multi-AZ

 🚀 Resumen Ejecutivo
Migración del sistema FreshBox SpA desde una arquitectura basada en EC2 + Docker (EP1) hacia una plataforma altamente disponible, autorreparable y escalable en Amazon EKS y Amazon RDS MySQL Multi-AZ. La aplicación mantiene la funcionalidad CRUD dividida en 5 microservicios desacoplados (1 frontend Nginx y 4 backends Node.js)

 🏗️ Arquitectura por Capas y Subredes

La VPC principal utiliza el bloque CIDR `10.0.0.0/22` distribuida en 2 Zonas de Disponibilidad (`us-east-1a` y `us-east-1b`) con 6 subredes en total

| Capa | Subredes (CIDR) | Componentes Principales | Tipo de Acceso |
| :--- | :--- | :--- | :--- |
| **1. Pública** | `10.0.0.0/24` (1a)<br>`10.0.1.0/24` (1b) | Internet Gateway, ALB internet-facing, NAT Gateway + Elastic IP| Público (HTTP 80)
| **2. Aplicación** | `10.0.2.0/25` (1a)<br>`10.0.2.128/25` (1b) | EKS Node Group (`t3.small`, 2-4 nodos), 10 pods activos| Privado (vía ALB e internet por NAT)
| **3. Datos** | `10.0.3.0/25` (1a)<br>`10.0.3.128/25` (1b) | Amazon RDS MySQL 8.0 Multi-AZ (Instancia primaria + Standby)| Privado (puerto 3306 desde EKS)

---
 📦 Tabla de Microservicios y Manifiestos K8s

La aplicación comprende 5 Deployments en el namespace `freshbox`, sumando 10 pods (2 réplicas por servicio) repartidos en 2 zonas de disponibilidad

| Microservicio | Imagen ECR | Puerto | Service (ClusterIP) | Réplicas | Requests / Limits CPU & RAM |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `frontend` | `freshbox-frontend` | 80 | `frontend:80` | 2 | `100m/128Mi` - `250m/256Mi`
| `get-products` | `freshbox-get-products` | 3001 | `get-products:3001` | 2 (HPA 2-5) | `100m/128Mi` - `250m/256Mi
| `create-product` | `freshbox-create-product` | 3002 | `create-product:3002` | 2 (HPA 2-5) | `100m/128Mi` - `250m/256Mi`
| `update-product` | `freshbox-update-product` | 3003 | `update-product:3003` | 2 (HPA 2-5) | `100m/128Mi` - `250m/256Mi`
| `delete-product` | `freshbox-delete-product` | 3004 | `delete-product:3004` | 2 (HPA 2-5) | `100m/128Mi` - `250m/256Mi`

 🛡️ Seguridad y Control de Acceso

* **Cadena de Security Groups:** Enrutamiento en cascada: ALB SG (`freshbox-alb-sg`) → EKS Cluster SG → RDS SG (`freshbox-data-sg` permitiendo puerto 3306)
* **Almacenamiento de Datos:** Instancia RDS con cifrado de almacenamiento activo (`storage_encrypted = true`) con KMS y backups automáticos de 7 días
* **Gestión de Credenciales:** Parámetros sensibles en `Secret` (`freshbox-secret`) y configuración no sensible en `ConfigMap` (`freshbox-config`)


 🔄 Pipeline CI/CD (GitHub Actions)

El workflow en `.github/workflows/deploy.yml` se dispara automáticamente tras cada push a la rama `ep2`

1. **Checkout:** Descarga del código fuente en el runner[cite: 8].
2. **Autenticación AWS:** Configuración de credenciales temporales con `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` y `AWS_SESSION_TOKEN` desde GitHub Secrets
3. **Kubeconfig:** Actualización del archivo de contexto mediante `aws eks update-kubeconfig`
4. **Despliegue Declarativo:** Aplicación secuencial con `kubectl apply -f k8s/` (`namespace`, `secret`, `configmap`, `deployments`, `ingress`, `hpa`)
5. **Validación:** Monitoreo del estado con `kubectl rollout status`

 ⚠️ Nota sobre Credenciales Temporales
Al utilizar **AWS Academy Learner Lab**, las credenciales expiran al finalizar cada sesión de laboratorio. Es necesario actualizar el `AWS_SESSION_TOKEN` en GitHub Secrets antes de cada ejecución del pipeline


🧹 Procedimiento de Limpieza y Destrucción

Para evitar que las Interfaces de Red Elásticas (ENI) creadas por el AWS Load Balancer Controller bloqueen la eliminación de la VPC durante el `terraform destroy`, ejecute la limpieza en el siguiente orden estricto

```bash
# 1. Eliminar el recurso Ingress para desaprovisionar el ALB
kubectl delete -f k8s/ingress.yaml

# 2. Desinstalar el AWS Load Balancer Controller
helm uninstall aws-load-balancer-controller -n kube-system

# 3. Destruir la infraestructura administrada por Terraform
cd terraform
terraform destroy
