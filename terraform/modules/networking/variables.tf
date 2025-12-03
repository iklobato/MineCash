variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of public subnet IDs for ALB"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for ALB (will be created if null)"
  type        = string
  default     = null
}

variable "target_group_port" {
  description = "Port for target group (Minecraft server port)"
  type        = number
  default     = 25565
}

variable "enable_global_accelerator" {
  description = "Enable Global Accelerator"
  type        = bool
  default     = true
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection on ALB"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

