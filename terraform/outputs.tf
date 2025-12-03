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

