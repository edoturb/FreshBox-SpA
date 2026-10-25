resource "aws_eks_cluster" "freshbox_eks" {
  name     = "freshbox-cluster"
  role_arn = "arn:aws:iam::850411985525:role/LabRole"

  vpc_config {
    subnet_ids         = [aws_subnet.private_app_1a.id, aws_subnet.private_app_1b.id, aws_subnet.public_1a.id, aws_subnet.public_1b.id]
    security_group_ids = [aws_security_group.app.id]
  }
}

resource "aws_eks_node_group" "freshbox_nodes" {
  cluster_name    = aws_eks_cluster.freshbox_eks.name
  node_group_name = "freshbox-node-group"
  node_role_arn   = "arn:aws:iam::850411985525:role/LabRole"
  subnet_ids      = [aws_subnet.private_app_1a.id, aws_subnet.private_app_1b.id]

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }

  instance_types = ["t3.small"]
}
