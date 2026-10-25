provider "aws" {
  region = var.aws_region
}

module "network" {
  source = "../../modules/vpc-simple"

  environment          = var.environment
  owner                = var.owner
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidr   = var.public_subnet_cidr
  private_subnet_cidr  = var.private_subnet_cidr
  availability_zone    = var.availability_zone
  allowed_ssh_cidr      = var.allowed_ssh_cidr

  tags = {
    Project = "iac-final-aws"
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "demo" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = module.network.public_subnet_id
  vpc_security_group_ids = [module.network.security_group_id]

  tags = {
    Name        = "${var.environment}-demo-instance"
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
  }
}
