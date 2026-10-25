output "vpc_id" {
  value = module.network.vpc_id
}

output "instance_public_ip" {
  value = aws_instance.demo.public_ip
}
