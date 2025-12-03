variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "service_name" {
  description = "ECS service name"
  type        = string
}

variable "container_image" {
  description = "Docker image URI for Minecraft server container"
  type        = string
}

variable "task_cpu" {
  description = "CPU units for ECS task (1024 = 1 vCPU)"
  type        = number
  default     = 2048
}

variable "task_memory" {
  description = "Memory in MB for ECS task"
  type        = number
  default     = 4096
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 1
}

variable "subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "efs_file_system_id" {
  description = "EFS file system ID"
  type        = string
}

variable "efs_security_group_id" {
  description = "EFS security group ID"
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN"
  type        = string
}

variable "alb_security_group_id" {
  description = "ALB security group ID"
  type        = string
}

variable "redis_endpoint" {
  description = "Redis cluster endpoint"
  type        = string
}

variable "redis_port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

variable "redis_security_group_id" {
  description = "Redis security group ID"
  type        = string
}

variable "redis_auth_token_secret_name" {
  description = "AWS Secrets Manager secret name containing Redis auth token"
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

