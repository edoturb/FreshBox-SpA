resource "aws_lb" "alb" {
  name               = "ALB-FreshBoxSpA"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1a.id, aws_subnet.public_1b.id]

  tags = { Name = "ALB-FreshBoxSpA" }
}

resource "aws_lb_target_group" "frontend" {
  name     = "TG-Frontend"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.freshbox_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }

  tags = { Name = "TG-Frontend" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "freshbox-app-lt-"
  image_id      = data.aws_ami.al2023_arm.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = var.lab_instance_profile
  }

  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = base64encode(templatefile("${path.module}/templates/app-userdata.sh.tftpl", {
    region      = var.aws_region
    db_host     = aws_instance.mysql.private_ip
    db_user     = var.db_user
    db_password = var.db_password
    db_name     = var.db_name
  }))

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 20
      volume_type = "gp3"
      encrypted   = true
    }
  }

  metadata_options {
    http_tokens = "required"
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "EC2-FreshBox-App"
    }
  }
}

resource "aws_autoscaling_group" "app" {
  name                      = "ASG-FreshBoxSpA-App"
  vpc_zone_identifier       = [aws_subnet.private_app_1a.id, aws_subnet.private_app_1b.id]
  target_group_arns         = [aws_lb_target_group.frontend.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 420
  min_size                  = 2
  max_size                  = 4
  desired_capacity          = 2

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  depends_on = [aws_instance.mysql, aws_nat_gateway.nat_gw]

  tag {
    key                 = "Name"
    value               = "EC2-FreshBox-App"
    propagate_at_launch = true
  }
}

output "alb_dns_name" {
  value       = aws_lb.alb.dns_name
  description = "DNS público del ALB (CRUD por HTTP puerto 80)"
}

output "mysql_private_ip" {
  value       = aws_instance.mysql.private_ip
  description = "IP privada de EC2 MySQL (capa Data)"
}

output "ecr_repository_urls" {
  value       = { for k, r in aws_ecr_repository.repos : k => r.repository_url }
  description = "URLs de los 5 repositorios ECR"
}
