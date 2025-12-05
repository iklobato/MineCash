variable "project_name" {
  description = "Project name used for resource naming (e.g., 'minecraft'). Defaults to 'minecraft' for backward compatibility. This value is used in resource naming patterns across all modules."
  type        = string
  default     = "minecraft"
}

variable "player_capacity" {
  description = "Target number of concurrent players. When specified, automatically calculates resource sizing for all components (ECS CPU/memory, Redis instance type, EFS performance mode, NAT Gateway count, Global Accelerator enablement). Individual resource variables can override calculated values."
  type        = number
  default     = null

  validation {
    condition     = var.player_capacity == null || (var.player_capacity >= 100 && var.player_capacity <= 50000 && floor(var.player_capacity) == var.player_capacity)
    error_message = "Player capacity must be an integer between 100 and 50,000, or null to use manual resource specification. For capacities above 50,000, consider multi-region deployment or custom architecture."
  }
}

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "sa-east-1"
}

variable "container_image" {
  description = "Docker image URI for Minecraft server container"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "environment" {
  description = "Environment name (used for resource naming and tagging)"
  type        = string
  default     = "production"
}

variable "desired_count" {
  description = "Desired number of ECS tasks to run. Overrides calculated value when player_capacity is set."
  type        = number
  default     = null

  validation {
    condition     = var.desired_count == null || (var.desired_count > 0 && var.desired_count <= 100)
    error_message = "Desired count must be between 1 and 100, or null to use calculated value."
  }
}

variable "task_cpu" {
  description = "CPU units for ECS task (1024 = 1 vCPU). Overrides calculated value when player_capacity is set."
  type        = number
  default     = null

  validation {
    condition     = var.task_cpu == null || contains([256, 512, 1024, 2048, 4096, 8192, 16384], var.task_cpu)
    error_message = "Task CPU must be one of: 256, 512, 1024, 2048, 4096, 8192, 16384, or null to use calculated value."
  }
}

variable "task_memory" {
  description = "Memory in MB for ECS task. Overrides calculated value when player_capacity is set."
  type        = number
  default     = null

  validation {
    condition     = var.task_memory == null || (var.task_memory >= 512 && var.task_memory <= 61440)
    error_message = "Task memory must be between 512 and 61440 MB, or null to use calculated value."
  }
}

variable "redis_node_type" {
  description = "ElastiCache Redis node instance type. Overrides calculated value when player_capacity is set."
  type        = string
  default     = null
}

variable "redis_replica_count" {
  description = "Number of Redis replica nodes. Overrides calculated value when player_capacity is set."
  type        = number
  default     = null

  validation {
    condition     = var.redis_replica_count == null || (var.redis_replica_count >= 0 && var.redis_replica_count <= 5)
    error_message = "Redis replica count must be between 0 and 5, or null to use calculated value."
  }
}

variable "efs_performance_mode" {
  description = "EFS performance mode. Overrides calculated value when player_capacity is set."
  type        = string
  default     = null

  validation {
    condition     = var.efs_performance_mode == null || contains(["generalPurpose", "maxIO"], var.efs_performance_mode)
    error_message = "EFS performance mode must be 'generalPurpose' or 'maxIO', or null to use calculated value."
  }
}

variable "enable_global_accelerator" {
  description = "Enable AWS Global Accelerator for low-latency routing. Overrides calculated value when player_capacity is set."
  type        = bool
  default     = null
}

variable "redis_auth_token_secret_name" {
  description = "AWS Secrets Manager secret name containing Redis auth token"
  type        = string
  default     = null
}

variable "minecraft_server_port" {
  description = "Minecraft server port"
  type        = number
  default     = 25565
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection on ALB (prevents accidental deletion)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}


