terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Project     = "minecraft-server"
        Environment = var.environment
        ManagedBy   = "terraform"
      },
      var.tags
    )
  }
}

# VPC Module - Must be created first as all other modules depend on it
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = var.vpc_cidr
  availability_zones   = data.aws_availability_zones.available.names
  public_subnet_cidrs  = [for i in range(2) : cidrsubnet(var.vpc_cidr, 8, i)]
  private_subnet_cidrs = [for i in range(2) : cidrsubnet(var.vpc_cidr, 8, i + 10)]
  tags                 = var.tags
}

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Storage Module (EFS) - Created first, security group will be updated later
module "storage" {
  source = "./modules/storage"

  vpc_id           = module.vpc.vpc_id
  subnet_ids       = module.vpc.private_subnet_ids
  performance_mode = var.efs_performance_mode
  tags             = var.tags

  depends_on = [module.vpc]
}

# Cache Module (ElastiCache Redis) - Created before ECS, security group will be updated later
module "cache" {
  source = "./modules/cache"

  cluster_id             = "minecraft-redis-${var.environment}"
  node_type              = var.redis_node_type
  num_cache_nodes        = var.redis_replica_count + 1
  subnet_group_name      = "minecraft-redis-subnet-${var.environment}"
  subnet_ids             = module.vpc.private_subnet_ids
  auth_token_secret_name = var.redis_auth_token_secret_name
  tags                   = var.tags

  depends_on = [module.vpc]
}

# Networking Module (ALB + Global Accelerator)
module "networking" {
  source = "./modules/networking"

  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.public_subnet_ids
  target_group_port          = var.minecraft_server_port
  enable_global_accelerator  = var.enable_global_accelerator
  enable_deletion_protection = var.enable_deletion_protection
  tags                       = var.tags

  depends_on = [module.vpc]
}

# ECS Module (Fargate Cluster and Service)
module "ecs" {
  source = "./modules/ecs"

  cluster_name                 = "minecraft-cluster-${var.environment}"
  service_name                 = "minecraft-server-${var.environment}"
  container_image              = var.container_image
  task_cpu                     = var.task_cpu
  task_memory                  = var.task_memory
  desired_count                = var.desired_count
  subnet_ids                   = module.vpc.private_subnet_ids
  efs_file_system_id           = module.storage.efs_id
  efs_security_group_id        = module.storage.efs_security_group_id
  target_group_arn             = module.networking.target_group_arn
  alb_security_group_id        = module.networking.alb_security_group_id
  redis_endpoint               = module.cache.redis_endpoint
  redis_port                   = module.cache.redis_port
  redis_security_group_id      = module.cache.redis_security_group_id
  redis_auth_token_secret_name = var.redis_auth_token_secret_name
  tags                         = var.tags

  depends_on = [
    module.vpc,
    module.storage,
    module.cache,
    module.networking
  ]
}

# Update EFS security group to allow access from ECS tasks
resource "aws_security_group_rule" "efs_from_ecs" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = module.ecs.ecs_task_security_group_id
  security_group_id        = module.storage.efs_security_group_id
  description              = "NFS from ECS tasks"
}

# Update Redis security group to allow access from ECS tasks
resource "aws_security_group_rule" "redis_from_ecs" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = module.ecs.ecs_task_security_group_id
  security_group_id        = module.cache.redis_security_group_id
  description              = "Redis from ECS tasks"
}

# Update ECS task security group to allow access from ALB
resource "aws_security_group_rule" "ecs_from_alb" {
  type                     = "ingress"
  from_port                = 25565
  to_port                  = 25565
  protocol                 = "tcp"
  source_security_group_id = module.networking.alb_security_group_id
  security_group_id        = module.ecs.ecs_task_security_group_id
  description              = "Minecraft server port from ALB"
}

# Update ECS task security group to allow access to Redis
resource "aws_security_group_rule" "ecs_to_redis" {
  type                     = "egress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = module.cache.redis_security_group_id
  security_group_id        = module.ecs.ecs_task_security_group_id
  description              = "Redis access from ECS tasks"
}

# Global Accelerator (if enabled)
resource "aws_globalaccelerator_accelerator" "main" {
  count = var.enable_global_accelerator ? 1 : 0

  name            = "minecraft-${var.environment}"
  ip_address_type = "IPV4"
  enabled         = true

  tags = var.tags
}

resource "aws_globalaccelerator_listener" "main" {
  count = var.enable_global_accelerator ? 1 : 0

  accelerator_arn = aws_globalaccelerator_accelerator.main[0].id
  protocol        = "TCP"
  port_ranges {
    from_port = var.minecraft_server_port
    to_port   = var.minecraft_server_port
  }
}

resource "aws_globalaccelerator_endpoint_group" "main" {
  count = var.enable_global_accelerator ? 1 : 0

  listener_arn = aws_globalaccelerator_listener.main[0].id

  endpoint_configuration {
    endpoint_id = module.networking.alb_arn
    weight      = 100
  }

  health_check_port     = var.minecraft_server_port
  health_check_protocol = "TCP"
}

