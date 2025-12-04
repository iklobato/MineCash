variable "cluster_id" {
  description = "Redis cluster identifier"
  type        = string
}

variable "node_type" {
  description = "Redis node instance type"
  type        = string
  default     = "cache.t3.micro"
}

variable "num_cache_nodes" {
  description = "Number of cache nodes (primary + replicas)"
  type        = number
  default     = 2
}

variable "subnet_group_name" {
  description = "ElastiCache subnet group name"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for ElastiCache subnet group"
  type        = list(string)
}

variable "auth_token_secret_name" {
  description = "AWS Secrets Manager secret name containing Redis auth token"
  type        = string
  default     = null
}

variable "project_name" {
  description = "Project name used for resource naming (e.g., 'minecraft')"
  type        = string
}

variable "environment" {
  description = "Environment name used for resource naming and tagging (e.g., 'production', 'staging')"
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}


