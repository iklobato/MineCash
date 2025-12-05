output "minecraft_endpoint" {
  description = "Public endpoint for Minecraft server connection (prioritizes Global Accelerator IP for low latency)"
  value       = var.enable_global_accelerator ? try(aws_globalaccelerator_accelerator.main[0].ip_sets[0].ip_addresses[0], module.networking.alb_dns_name) : module.networking.alb_dns_name
}

output "global_accelerator_dns_name" {
  description = "Global Accelerator DNS name (if enabled)"
  value       = var.enable_global_accelerator ? try(aws_globalaccelerator_accelerator.main[0].dns_name, null) : null
}

output "redis_endpoint" {
  description = "ElastiCache Redis cluster endpoint"
  value       = module.cache.redis_endpoint
}

output "efs_dns_name" {
  description = "EFS DNS name for mounting"
  value       = module.storage.efs_dns_name
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "ecs_cluster_id" {
  description = "ECS cluster ID/ARN"
  value       = module.ecs.ecs_cluster_id
}

output "ecs_service_id" {
  description = "ECS service ID"
  value       = module.ecs.ecs_service_id
}

output "alb_arn" {
  description = "Application Load Balancer ARN"
  value       = module.networking.alb_arn
}

output "redis_cluster_id" {
  description = "ElastiCache Redis cluster ID"
  value       = module.cache.redis_cluster_id
}

output "efs_id" {
  description = "EFS file system ID"
  value       = module.storage.efs_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "security_group_ids" {
  description = "Map of security group IDs by name"
  value = {
    alb   = module.networking.alb_security_group_id
    ecs   = module.ecs.ecs_task_security_group_id
    redis = module.cache.redis_security_group_id
    efs   = module.storage.efs_security_group_id
  }
}

# Calculated Resource Values (from player_capacity)
output "calculated_ecs_cpu" {
  description = "Calculated ECS CPU units (from player_capacity)"
  value       = local.calculated_cpu_units
}

output "calculated_ecs_memory" {
  description = "Calculated ECS memory in MB (from player_capacity)"
  value       = local.calculated_memory_mb
}

output "calculated_ecs_desired_count" {
  description = "Calculated ECS desired task count (from player_capacity)"
  value       = local.calculated_desired_count
}

output "calculated_redis_node_type" {
  description = "Calculated Redis instance type (from player_capacity)"
  value       = local.calculated_redis_node_type
}

output "calculated_redis_replica_count" {
  description = "Calculated Redis replica count (from player_capacity)"
  value       = local.calculated_redis_replica_count
}

output "calculated_efs_performance_mode" {
  description = "Calculated EFS performance mode (from player_capacity)"
  value       = local.calculated_efs_performance_mode
}

output "calculated_nat_gateway_count" {
  description = "Calculated NAT Gateway count (from player_capacity)"
  value       = local.calculated_nat_gateway_count
}

output "calculated_enable_global_accelerator" {
  description = "Calculated Global Accelerator enablement (from player_capacity)"
  value       = local.calculated_enable_global_accelerator
}

# Cost Estimation Outputs
output "monthly_cost_ecs" {
  description = "Estimated monthly cost for ECS Fargate (USD)"
  value       = local.monthly_cost_ecs
}

output "monthly_cost_redis" {
  description = "Estimated monthly cost for ElastiCache Redis (USD)"
  value       = local.monthly_cost_redis
}

output "monthly_cost_efs" {
  description = "Estimated monthly cost for EFS storage (USD)"
  value       = local.monthly_cost_efs
}

output "monthly_cost_nat" {
  description = "Estimated monthly cost for NAT Gateways (USD)"
  value       = local.monthly_cost_nat
}

output "monthly_cost_alb" {
  description = "Estimated monthly cost for Application Load Balancer (USD)"
  value       = local.monthly_cost_alb
}

output "monthly_cost_accelerator" {
  description = "Estimated monthly cost for Global Accelerator (USD, 0 if disabled)"
  value       = local.monthly_cost_accelerator
}

output "monthly_cost_total" {
  description = "Estimated total monthly infrastructure cost (USD). Sum of all component costs."
  value       = local.monthly_cost_total
}

