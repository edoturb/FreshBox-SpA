resource "aws_security_group" "alb" {
  name        = "freshbox-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.freshbox_vpc.id

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

  tags = { Name = "freshbox-alb-sg" }
}

resource "aws_security_group" "app" {
  name        = "freshbox-app-sg"
  description = "Security group for EKS App Nodes"
  vpc_id      = aws_vpc.freshbox_vpc.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "freshbox-app-sg" }
}

resource "aws_security_group" "data" {
  name        = "freshbox-data-sg"
  description = "Security group for RDS MySQL"
  vpc_id      = aws_vpc.freshbox_vpc.id

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

  tags = { Name = "freshbox-data-sg" }
}
