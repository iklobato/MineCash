# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/minecraft-server"
  retention_in_days = 7

  tags = var.tags
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(
    {
      Name = var.cluster_name
    },
    var.tags
  )
}

# ECS Task Execution Role (for ECS agent)
resource "aws_iam_role" "ecs_execution" {
  name = "${var.cluster_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional permissions for EFS, Secrets Manager, SSM
resource "aws_iam_role_policy" "ecs_execution_additional" {
  name = "${var.cluster_name}-execution-additional"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "efs:ClientMount",
          "efs:ClientWrite",
          "efs:ClientRootAccess"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.redis_auth_token_secret_name != null ? data.aws_secretsmanager_secret.redis_auth[0].arn : "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

# ECS Task Role (for application)
resource "aws_iam_role" "ecs_task" {
  name = "${var.cluster_name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# SSM permissions for Session Manager
resource "aws_iam_role_policy" "ecs_task_ssm" {
  name = "${var.cluster_name}-task-ssm"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

# Get Redis auth secret (if provided)
data "aws_secretsmanager_secret" "redis_auth" {
  count = var.redis_auth_token_secret_name != null ? 1 : 0
  name  = var.redis_auth_token_secret_name
}

# ECS Task Security Group
resource "aws_security_group" "ecs_task" {
  name        = "minecraft-ecs-task-sg"
  description = "Security group for ECS tasks"
  vpc_id      = data.aws_subnet.main.vpc_id

  ingress {
    description     = "Minecraft server port from ALB"
    from_port       = 25565
    to_port         = 25565
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    description     = "Redis port to Redis security group"
    from_port       = var.redis_port
    to_port         = var.redis_port
    protocol        = "tcp"
    security_groups = [var.redis_security_group_id]
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
      Name = "minecraft-ecs-task-sg"
    },
    var.tags
  )
}

# Get subnet info for VPC ID
data "aws_subnet" "main" {
  id = var.subnet_ids[0]
}

# Get AWS region
data "aws_region" "current" {}

# ECS Task Definition
resource "aws_ecs_task_definition" "main" {
  family                   = var.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = templatefile("${path.module}/task-definition.json.tpl", {
    container_image       = var.container_image
    redis_host            = split(":", var.redis_endpoint)[0]
    redis_port            = var.redis_port
    redis_auth_secret_arn = var.redis_auth_token_secret_name != null ? data.aws_secretsmanager_secret.redis_auth[0].arn : ""
    aws_region            = data.aws_region.current.name
  })

  volume {
    name = "efs-storage"

    efs_volume_configuration {
      file_system_id     = var.efs_file_system_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = null
        iam             = "ENABLED"
      }
    }
  }

  tags = var.tags
}

# ECS Service
resource "aws_ecs_service" "main" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs_task.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "minecraft-server"
    container_port   = 25565
  }

  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  enable_execute_command = true

  tags = var.tags

  depends_on = [
    aws_ecs_task_definition.main
  ]
}

