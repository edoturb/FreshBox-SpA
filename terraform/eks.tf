data "aws_caller_identity" "current" {}

locals {
  lab_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
}

resource "aws_eks_cluster" "freshbox_eks" {
  name     = "freshbox-cluster"
  role_arn = local.lab_role_arn

  vpc_config {
    subnet_ids         = [aws_subnet.private_app_1a.id, aws_subnet.private_app_1b.id, aws_subnet.public_1a.id, aws_subnet.public_1b.id]
    security_group_ids = [aws_security_group.app.id]
  }
}

# Launch Template explícito: fuerza a que las instancias del node group usen
# freshbox-app-sg (y no el Security Group "cluster security group" que EKS
# genera automáticamente por defecto). Este fue el hallazgo real detectado
# en el despliegue EP3: sin esto, las reglas de RDS hacia freshbox-app-sg
# no cubren el tráfico real de los pods.
resource "aws_launch_template" "freshbox_nodes" {
  name_prefix = "freshbox-node-"

  vpc_security_group_ids = [aws_security_group.app.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2 # requerido por el AWS Load Balancer Controller (IMDS vía red del pod)
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "freshbox-eks-node" }
  }
}

resource "aws_eks_node_group" "freshbox_nodes" {
  cluster_name    = aws_eks_cluster.freshbox_eks.name
  node_group_name = "freshbox-node-group"
  node_role_arn   = local.lab_role_arn
  subnet_ids      = [aws_subnet.private_app_1a.id, aws_subnet.private_app_1b.id]

  launch_template {
    id      = aws_launch_template.freshbox_nodes.id
    version = aws_launch_template.freshbox_nodes.latest_version
  }

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }

  # instance_types va en el launch template cuando se usa launch_template con instance_types fijo;
  # EKS requiere declararlo igual aquí si no se especifica en el launch template.
  instance_types = ["t3.small"]
}
