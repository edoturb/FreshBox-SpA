terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# --- 1. RED (VPC /16, Subredes, IGW, NAT GW, Tablas de Ruteo) ---
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "VPC-EscolarOnline"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "IGW-EscolarOnline" }
}

resource "aws_subnet" "public_1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "Subnet-Public-1a" }
}

resource "aws_subnet" "public_1b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags                    = { Name = "Subnet-Public-1b" }
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1a.id
  tags          = { Name = "NAT-GW-EscolarOnline" }
}

resource "aws_subnet" "private_app_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "Subnet-Private-APP-1a" }
}

resource "aws_subnet" "private_app_1b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"
  tags              = { Name = "Subnet-Private-APP-1b" }
}

resource "aws_subnet" "private_data_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "Subnet-Private-DATA-1a" }
}

resource "aws_subnet" "private_data_1b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "us-east-1b"
  tags              = { Name = "Subnet-Private-DATA-1b" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "RT-Public" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "RT-Private" }
}

resource "aws_route_table_association" "pub_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "pub_1b" {
  subnet_id      = aws_subnet.public_1b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "priv_app_1a" {
  subnet_id      = aws_subnet.private_app_1a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "priv_app_1b" {
  subnet_id      = aws_subnet.private_app_1b.id
  route_table_id = aws_route_table.private.id
}

# --- 2. SECURITY GROUPS ---
resource "aws_security_group" "alb" {
  name        = "SG-ALB"
  vpc_id      = aws_vpc.main.id
  description = "Permite entrada HTTP"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app" {
  name        = "SG-APP"
  vpc_id      = aws_vpc.main.id
  description = "Permite trafico desde el ALB"

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port       = 3001
    to_port         = 3004
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "data" {
  name        = "SG-DATA"
  vpc_id      = aws_vpc.main.id
  description = "Permite MySQL desde las instancias APP"

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- 3. REPOSITORIOS ECR ---
resource "aws_ecr_repository" "repos" {
  for_each = toset(["frontend", "get-products", "create-product", "update-product", "delete-product"])
  name     = "escolaronline/${each.key}"
}

# --- 4. INSTANCIAS EC2 ---
data "aws_ami" "amazon_linux_2023_arm" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-arm64"]
  }
}

resource "aws_instance" "ec2_mysql" {
  ami                  = data.aws_ami.amazon_linux_2023_arm.id
  instance_type        = "t4g.micro"
  subnet_id            = aws_subnet.private_data_1a.id
  vpc_security_group_ids = [aws_security_group.data.id]
  iam_instance_profile = "LabInstanceProfile"

  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y docker
              systemctl enable --now docker
              EOF

  tags = { Name = "EC2-MySQL" }
}

resource "aws_instance" "ec2_app_1" {
  ami                  = data.aws_ami.amazon_linux_2023_arm.id
  instance_type        = "t4g.micro"
  subnet_id            = aws_subnet.private_app_1a.id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile = "LabInstanceProfile"

  tags = { Name = "EC2-APP-1" }
}

resource "aws_instance" "ec2_app_2" {
  ami                  = data.aws_ami.amazon_linux_2023_arm.id
  instance_type        = "t4g.micro"
  subnet_id            = aws_subnet.private_app_1b.id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile = "LabInstanceProfile"

  tags = { Name = "EC2-APP-2" }
}

# --- 5. APPLICATION LOAD BALANCER ---
resource "aws_lb" "alb" {
  name               = "ALB-EscolarOnline"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1a.id, aws_subnet.public_1b.id]
}

resource "aws_lb_target_group" "tg_frontend" {
  name     = "TG-EscolarOnline-Frontend"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
  }
}

resource "aws_lb_target_group_attachment" "att_app1" {
  target_group_arn = aws_lb_target_group.tg_frontend.arn
  target_id        = aws_instance.ec2_app_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "att_app2" {
  target_group_arn = aws_lb_target_group.tg_frontend.arn
  target_id        = aws_instance.ec2_app_2.id
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_frontend.arn
  }
}

# --- 6. AWS BACKUP ---
resource "aws_backup_vault" "vault" {
  name = "EscolarOnline-Vault"
}

resource "aws_backup_plan" "plan" {
  name = "EscolarOnline-BackupPlan"

  rule {
    rule_name         = "DailyBackup"
    target_vault_name = aws_backup_vault.vault.name
    schedule          = "cron(0 12 * * ? *)"

    lifecycle {
      delete_after = 30
    }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_backup_selection" "selection" {
  iam_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  name         = "MySQL-Backup-Selection"
  plan_id      = aws_backup_plan.plan.id

  resources = [
    aws_instance.ec2_mysql.arn
  ]
}

# OUTPUTS
output "alb_dns_name" {
  value       = aws_lb.alb.dns_name
  description = "URL publica del Application Load Balancer"
}

output "mysql_private_ip" {
  value       = aws_instance.ec2_mysql.private_ip
  description = "IP Privada del servidor MySQL"
}
