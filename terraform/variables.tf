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
  description = "Desired number of ECS tasks to run"
  type        = number
  default     = 1

  validation {
    condition     = var.desired_count > 0 && var.desired_count <= 100
    error_message = "Desired count must be between 1 and 100."
  }
}

variable "task_cpu" {
  description = "CPU units for ECS task (1024 = 1 vCPU)"
  type        = number
  default     = 2048

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.task_cpu)
    error_message = "Task CPU must be one of: 256, 512, 1024, 2048, 4096."
  }
}

variable "task_memory" {
  description = "Memory in MB for ECS task"
  type        = number
  default     = 4096

  validation {
    condition     = var.task_memory >= 512 && var.task_memory <= 30720
    error_message = "Task memory must be between 512 and 30720 MB."
  }
}

variable "redis_node_type" {
  description = "ElastiCache Redis node instance type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_replica_count" {
  description = "Number of Redis replica nodes"
  type        = number
  default     = 1
}

variable "efs_performance_mode" {
  description = "EFS performance mode"
  type        = string
  default     = "generalPurpose"

  validation {
    condition     = contains(["generalPurpose", "maxIO"], var.efs_performance_mode)
    error_message = "EFS performance mode must be 'generalPurpose' or 'maxIO'."
  }
}

variable "enable_global_accelerator" {
  description = "Enable AWS Global Accelerator for low-latency routing"
  type        = bool
  default     = true
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

