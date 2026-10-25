output "eks_cluster_name" {
  value = aws_eks_cluster.freshbox_eks.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.freshbox_eks.endpoint
}

output "rds_endpoint" {
  value = aws_db_instance.freshbox_rds.endpoint
}

output "rds_address" {
  value = aws_db_instance.freshbox_rds.address
}
