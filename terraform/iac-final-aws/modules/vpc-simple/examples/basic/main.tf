provider "aws" {
  region = "us-east-1"
}

module "network" {
  source = "../../"

  environment         = "example"
  owner               = "estudiante"
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidr  = "10.0.1.0/24"
  private_subnet_cidr = "10.0.2.0/24"
  availability_zone   = "us-east-1a"
  allowed_ssh_cidr    = "10.0.0.0/16"
}

output "vpc_id" {
  value = module.network.vpc_id
}
