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

# Resource Sizing Calculations
# When player_capacity is set, calculate all resource values using formulas
# Individual resource variables can override calculated values
locals {
  # CPU and Memory Calculations (from research.md)
  calculated_cpu_vcpu = var.player_capacity != null ? max(1, ceil(var.player_capacity / 100)) : null
  calculated_cpu_units = local.calculated_cpu_vcpu != null ? local.calculated_cpu_vcpu * 1024 : null
  calculated_memory_gb = var.player_capacity != null ? max(2, ceil(var.player_capacity / 50)) : null
  calculated_memory_mb = local.calculated_memory_gb != null ? local.calculated_memory_gb * 1024 : null

  # ECS CPU Discrete Options and Rounding
  cpu_options = [256, 512, 1024, 2048, 4096, 8192, 16384]
  rounded_cpu = local.calculated_cpu_units != null ? min([for cpu in local.cpu_options : cpu if cpu >= local.calculated_cpu_units]) : null

  # ECS Memory Constraints Based on CPU
  cpu_memory_min_map = {
    256   = 512
    512   = 1024
    1024  = 2048
    2048  = 4096
    4096  = 8192
    8192  = 16384
    16384 = 32768
  }
  cpu_memory_max_map = {
    256   = 2048
    512   = 4096
    1024  = 8192
    2048  = 16384
    4096  = 30720
    8192  = 30720
    16384 = 61440
  }
  valid_memory_min = local.rounded_cpu != null ? lookup(local.cpu_memory_min_map, local.rounded_cpu, 512) : null
  valid_memory_max = local.rounded_cpu != null ? lookup(local.cpu_memory_max_map, local.rounded_cpu, 61440) : null
  calculated_memory_validated = local.valid_memory_min != null && local.valid_memory_max != null && local.calculated_memory_mb != null ? max(local.valid_memory_min, min(local.calculated_memory_mb, local.valid_memory_max)) : null

  # Redis Instance Type Selection
  redis_instance_types = {
    "cache.t3.micro"  = { max_players = 500 }
    "cache.t3.small"  = { max_players = 2000 }
    "cache.t3.medium" = { max_players = 5000 }
    "cache.t3.large"  = { max_players = 10000 }
    "cache.r6g.large" = { max_players = 20000 }
    "cache.r6g.xlarge" = { max_players = 50000 }
  }
  calculated_redis_node_type = var.player_capacity != null ? (
    var.player_capacity <= 500 ? "cache.t3.micro" :
    var.player_capacity <= 2000 ? "cache.t3.small" :
    var.player_capacity <= 5000 ? "cache.t3.medium" :
    var.player_capacity <= 10000 ? "cache.t3.large" :
    var.player_capacity <= 20000 ? "cache.r6g.large" :
    "cache.r6g.xlarge"
  ) : null

  # Redis Replica Count
  calculated_redis_replica_count = var.player_capacity != null ? max(0, ceil(var.player_capacity / 5000) - 1) : null

  # EFS Performance Mode
  calculated_efs_performance_mode = var.player_capacity != null ? (var.player_capacity >= 5000 ? "maxIO" : "generalPurpose") : null

  # NAT Gateway Count
  calculated_nat_gateway_count = var.player_capacity != null ? (var.player_capacity >= 10000 ? 2 : 1) : null

  # Global Accelerator Enablement
  calculated_enable_global_accelerator = var.player_capacity != null ? (var.player_capacity >= 1000) : null

  # ECS Desired Count
  calculated_task_count = var.player_capacity != null ? (var.player_capacity < 5000 ? 1 : ceil(var.player_capacity / 5000)) : null
  calculated_desired_count = local.calculated_task_count != null ? (local.calculated_task_count == 1 ? 1 : max(2, local.calculated_task_count)) : null

  # Override Resolution Logic (override > calculated > default)
  # ECS CPU
  final_cpu = var.task_cpu != null ? var.task_cpu : (local.rounded_cpu != null ? local.rounded_cpu : 2048)

  # ECS Memory
  final_memory = var.task_memory != null ? var.task_memory : (local.calculated_memory_validated != null ? local.calculated_memory_validated : 4096)

  # ECS Desired Count
  final_desired_count = var.desired_count != null ? var.desired_count : (local.calculated_desired_count != null ? local.calculated_desired_count : 1)

  # Redis Node Type
  final_redis_node_type = var.redis_node_type != null ? var.redis_node_type : (local.calculated_redis_node_type != null ? local.calculated_redis_node_type : "cache.t3.micro")

  # Redis Replica Count
  final_redis_replica_count = var.redis_replica_count != null ? var.redis_replica_count : (local.calculated_redis_replica_count != null ? local.calculated_redis_replica_count : 1)

  # EFS Performance Mode
  final_efs_performance_mode = var.efs_performance_mode != null ? var.efs_performance_mode : (local.calculated_efs_performance_mode != null ? local.calculated_efs_performance_mode : "generalPurpose")

  # Global Accelerator
  final_enable_global_accelerator = var.enable_global_accelerator != null ? var.enable_global_accelerator : (local.calculated_enable_global_accelerator != null ? local.calculated_enable_global_accelerator : true)

  # NAT Gateway Count (used for resource creation)
  final_nat_gateway_count = local.calculated_nat_gateway_count != null ? local.calculated_nat_gateway_count : 1

  # Validation: ECS CPU/Memory Compatibility
  cpu_memory_valid = local.final_memory >= lookup(local.cpu_memory_min_map, local.final_cpu, 0) && local.final_memory <= lookup(local.cpu_memory_max_map, local.final_cpu, 999999)

  # Validation: Redis Node Type Validity
  valid_redis_types = ["cache.t3.micro", "cache.t3.small", "cache.t3.medium", "cache.t3.large", "cache.r6g.large", "cache.r6g.xlarge", "cache.r7g.large", "cache.r7g.xlarge"]
  redis_type_valid = contains(local.valid_redis_types, local.final_redis_node_type)

  # Cost Calculation Formulas (monthly costs in USD, assumes 730 hours/month)
  # ECS Fargate: CPU and Memory pricing
  final_cpu_vcpu = local.final_cpu / 1024
  final_memory_gb = local.final_memory / 1024
  monthly_cost_ecs = (local.final_cpu_vcpu * 0.04048 + local.final_memory_gb * 0.004445) * 730 * local.final_desired_count

  # ElastiCache Redis: Instance type pricing per hour
  redis_hourly_pricing = {
    "cache.t3.micro"  = 0.017
    "cache.t3.small"  = 0.034
    "cache.t3.medium" = 0.068
    "cache.t3.large"  = 0.136
    "cache.r6g.large" = 0.126
    "cache.r6g.xlarge" = 0.252
    "cache.r7g.large" = 0.126  # Approximate, same as r6g.large
    "cache.r7g.xlarge" = 0.252 # Approximate, same as r6g.xlarge
  }
  redis_hourly_cost = lookup(local.redis_hourly_pricing, local.final_redis_node_type, 0.017)
  monthly_cost_redis = local.redis_hourly_cost * 730 * (local.final_redis_replica_count + 1)

  # EFS: Storage pricing (simplified, assumes 100GB baseline)
  efs_storage_gb = 100  # Baseline storage estimate
  monthly_cost_efs = local.efs_storage_gb * 0.30

  # NAT Gateway: Per gateway pricing
  monthly_cost_nat = local.final_nat_gateway_count * 32.40

  # Application Load Balancer: Base cost
  monthly_cost_alb = 16.20  # Base cost, LCU charges vary by usage

  # Global Accelerator: Base cost if enabled
  monthly_cost_accelerator = local.final_enable_global_accelerator ? 7.20 : 0

  # Total Monthly Cost
  monthly_cost_total = local.monthly_cost_ecs + local.monthly_cost_redis + local.monthly_cost_efs + local.monthly_cost_nat + local.monthly_cost_alb + local.monthly_cost_accelerator
}

# Validation checks
check "ecs_cpu_memory_compatibility" {
  assert {
    condition     = local.cpu_memory_valid
    error_message = "ECS memory value (${local.final_memory} MB) is not compatible with selected CPU value (${local.final_cpu} CPU units). Valid memory range for ${local.final_cpu} CPU: ${lookup(local.cpu_memory_min_map, local.final_cpu, 0)}-${lookup(local.cpu_memory_max_map, local.final_cpu, 999999)} MB."
  }
}

check "redis_node_type_validity" {
  assert {
    condition     = local.redis_type_valid
    error_message = "Invalid Redis instance type: ${local.final_redis_node_type}. Valid types: ${join(", ", local.valid_redis_types)}"
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
  performance_mode = local.final_efs_performance_mode
  project_name     = var.project_name
  environment      = var.environment
  tags             = var.tags

  depends_on = [module.vpc]
}

# Cache Module (ElastiCache Redis) - Created before ECS, security group will be updated later
module "cache" {
  source = "./modules/cache"

  cluster_id             = "${var.project_name}-redis-${var.environment}"
  node_type              = local.final_redis_node_type
  num_cache_nodes        = local.final_redis_replica_count + 1
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
  enable_global_accelerator  = local.final_enable_global_accelerator
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
  task_cpu                     = local.final_cpu
  task_memory                  = local.final_memory
  desired_count                = local.final_desired_count
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
  count = local.final_enable_global_accelerator ? 1 : 0

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

