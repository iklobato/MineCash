provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Project     = "${var.project_name}-server"
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
  project_name         = var.project_name
  environment          = var.environment
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
  project_name     = var.project_name
  environment      = var.environment
  tags             = var.tags

  depends_on = [module.vpc]
}

# Cache Module (ElastiCache Redis) - Created before ECS, security group will be updated later
module "cache" {
  source = "./modules/cache"

  cluster_id             = "${var.project_name}-redis-${var.environment}"
  node_type              = var.redis_node_type
  num_cache_nodes        = var.redis_replica_count + 1
  subnet_group_name      = "${var.project_name}-redis-subnet-${var.environment}"
  subnet_ids             = module.vpc.private_subnet_ids
  auth_token_secret_name = var.redis_auth_token_secret_name
  project_name           = var.project_name
  environment            = var.environment
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
  project_name               = var.project_name
  environment                = var.environment
  tags                       = var.tags

  depends_on = [module.vpc]
}

# ECS Module (Fargate Cluster and Service)
module "ecs" {
  source = "./modules/ecs"

  cluster_name                 = "${var.project_name}-cluster-${var.environment}"
  service_name                 = "${var.project_name}-server-${var.environment}"
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
  minecraft_server_port        = var.minecraft_server_port
  project_name                 = var.project_name
  environment                  = var.environment
  tags                         = var.tags

  depends_on = [
    module.vpc,
    module.storage,
    module.cache,
    module.networking
  ]
}

# Security Group Rules
# Note: These rules are kept in the root module to avoid circular dependencies.
# Storage and cache modules depend on ECS outputs, but ECS also depends on storage/cache,
# creating a cycle if rules were moved into modules. The rules reference security groups
# from modules but are created after all modules are instantiated.

# EFS security group: Allow access from ECS tasks
resource "aws_security_group_rule" "efs_from_ecs" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = module.ecs.ecs_task_security_group_id
  security_group_id        = module.storage.efs_security_group_id
  description              = "NFS from ECS tasks"
}

# Redis security group: Allow access from ECS tasks
resource "aws_security_group_rule" "redis_from_ecs" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = module.ecs.ecs_task_security_group_id
  security_group_id        = module.cache.redis_security_group_id
  description              = "Redis from ECS tasks"
}

# ECS task security group: Allow access from ALB (already in module, but kept for consistency)
# Note: The ingress rule from ALB is already defined in modules/ecs/main.tf
# The egress rule to Redis is also already defined in modules/ecs/main.tf

# Global Accelerator (if enabled)
resource "aws_globalaccelerator_accelerator" "main" {
  count = var.enable_global_accelerator ? 1 : 0

  name            = "${var.project_name}-${var.environment}"
  ip_address_type = "IPV4"
  enabled         = true

  tags = var.tags
}

resource "aws_globalaccelerator_listener" "main" {
  count = var.enable_global_accelerator ? 1 : 0

  accelerator_arn = aws_globalaccelerator_accelerator.main[0].id
  protocol        = "TCP"
  port_range {
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

