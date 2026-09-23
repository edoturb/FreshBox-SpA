# Matriz 2.4 EP1 — SG por capa (sin SSH 22 a internet; ops vvia Session Manager)

resource "aws_security_group" "alb" {
  name        = "SG-ALB"
  description = "ALB - HTTP/HTTPS desde Internet"
  vpc_id      = aws_vpc.freshbox_vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS - demo Academy usa HTTP 80"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "SG-ALB" }
}

resource "aws_security_group" "app" {
  name        = "SG-APP"
  description = "EC2 App - 80/443 solo desde SG-ALB"
  vpc_id      = aws_vpc.freshbox_vpc.id

  ingress {
    description     = "HTTP desde ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "HTTPS desde ALB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "SG-APP" }
}

resource "aws_security_group" "data" {
  name        = "SG-DATA"
  description = "EC2 MySQL - 3306 solo desde SG-APP"
  vpc_id      = aws_vpc.freshbox_vpc.id

  ingress {
    description     = "MySQL desde App"
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

  tags = { Name = "SG-DATA" }
}

data "aws_ami" "al2023_arm" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-*-arm64"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "mysql" {
  ami                    = data.aws_ami.al2023_arm.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_data_1a.id
  vpc_security_group_ids = [aws_security_group.data.id]
  iam_instance_profile   = var.lab_instance_profile
  user_data              = templatefile("${path.module}/templates/mysql-userdata.sh.tftpl", {
    db_user     = var.db_user
    db_password = var.db_password
    db_name     = var.db_name
    init_sql_b64 = base64encode(file("${path.module}/../init.sql"))
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name       = "EC2-FreshBox-MySQL"
    Backup     = "true"
    Role       = "mysql"
    RestoreAZ  = "data-1b"
  }
}










