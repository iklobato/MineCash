locals {
  alb_security_group_name = "${var.project_name}-alb-sg"
  alb_name                = "${var.project_name}-alb"
  target_group_name       = "${var.project_name}-tg"
}

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = local.alb_security_group_name
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "Minecraft server port from internet"
    from_port   = var.target_group_port
    to_port     = var.target_group_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name = local.alb_security_group_name
    },
    var.tags
  )
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = local.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  enable_deletion_protection = var.enable_deletion_protection

  tags = merge(
    {
      Name = local.alb_name
    },
    var.tags
  )
}

# Target Group
resource "aws_lb_target_group" "main" {
  name        = local.target_group_name
  port        = var.target_group_port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    protocol            = "TCP"
    port                = var.target_group_port
  }

  tags = merge(
    {
      Name = local.target_group_name
    },
    var.tags
  )
}

# ALB Listener
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.target_group_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}


