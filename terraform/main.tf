data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az_a = data.aws_availability_zones.available.names[0]
  az_b = data.aws_availability_zones.available.names[1]

  services = [
    "freshbox-frontend",
    "freshbox-get-products",
    "freshbox-create-product",
    "freshbox-update-product",
    "freshbox-delete-product"
  ]
}

resource "aws_vpc" "freshbox_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "FreshBox-VPC" }
}

# Capa 1 — públicas (ALB)
resource "aws_subnet" "public_1a" {
  vpc_id                  = aws_vpc.freshbox_vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = local.az_a
  map_public_ip_on_launch = true
  tags                    = { Name = "Public-Subnet-1a" }
}

resource "aws_subnet" "public_1b" {
  vpc_id                  = aws_vpc.freshbox_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = local.az_b
  map_public_ip_on_launch = true
  tags                    = { Name = "Public-Subnet-1b" }
}

# Capa 2 — privadas App
resource "aws_subnet" "private_app_1a" {
  vpc_id            = aws_vpc.freshbox_vpc.id
  cidr_block        = "10.0.2.0/25"
  availability_zone = local.az_a
  tags              = { Name = "Private-App-Subnet-1a" }
}

resource "aws_subnet" "private_app_1b" {
  vpc_id            = aws_vpc.freshbox_vpc.id
  cidr_block        = "10.0.2.128/25"
  availability_zone = local.az_b
  tags              = { Name = "Private-App-Subnet-1b" }
}

# Capa 3 — privadas Data
resource "aws_subnet" "private_data_1a" {
  vpc_id            = aws_vpc.freshbox_vpc.id
  cidr_block        = "10.0.3.0/25"
  availability_zone = local.az_a
  tags              = { Name = "Private-Data-Subnet-1a" }
}

resource "aws_subnet" "private_data_1b" {
  vpc_id            = aws_vpc.freshbox_vpc.id
  cidr_block        = "10.0.3.128/25"
  availability_zone = local.az_b
  tags              = { Name = "Private-Data-Subnet-1b" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.freshbox_vpc.id
  tags   = { Name = "FreshBox-IGW" }
}

# Un solo NAT (costo pyme). Salida de App y Data hacia ECR, yum y SSM.
resource "aws_eip" "nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
  tags       = { Name = "FreshBox-NAT-EIP" }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_1a.id
  tags          = { Name = "FreshBox-NAT-GW" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.freshbox_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "FreshBox-RT-Public" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.freshbox_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = { Name = "FreshBox-RT-Private" }
}

resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1b" {
  subnet_id      = aws_subnet.public_1b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_app_1a" {
  subnet_id      = aws_subnet.private_app_1a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_app_1b" {
  subnet_id      = aws_subnet.private_app_1b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_data_1a" {
  subnet_id      = aws_subnet.private_data_1a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_data_1b" {
  subnet_id      = aws_subnet.private_data_1b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_ecr_repository" "repos" {
  for_each             = toset(local.services)
  name                 = each.value
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = { Name = each.value }
}
