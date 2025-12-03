# Terraform Variables Schema

**Date**: 2024-12-19  
**Feature**: AWS Minecraft Server Infrastructure  
**Purpose**: Define all Terraform input variables and their contracts

## Variable Contracts

### Root Module Variables

#### `aws_region`
- **Type**: `string`
- **Default**: `"sa-east-1"`
- **Description**: AWS region for resource deployment
- **Constraints**: Must be valid AWS region identifier
- **Example**: `"sa-east-1"`, `"us-east-1"`

#### `container_image`
- **Type**: `string`
- **Required**: Yes
- **Description**: Docker image URI for Minecraft server container
- **Constraints**: Must be valid Docker image reference (ECR, Docker Hub, etc.)
- **Example**: `"itzg/minecraft-server:latest"`, `"123456789012.dkr.ecr.sa-east-1.amazonaws.com/minecraft:1.20.1"`

#### `vpc_cidr`
- **Type**: `string`
- **Default**: `"10.0.0.0/16"`
- **Description**: CIDR block for VPC
- **Constraints**: Must be valid IPv4 CIDR notation, /16 or larger
- **Example**: `"10.0.0.0/16"`, `"172.16.0.0/16"`

#### `environment`
- **Type**: `string`
- **Default**: `"production"`
- **Description**: Environment name (used for resource naming and tagging)
- **Constraints**: Lowercase alphanumeric and hyphens only
- **Example**: `"production"`, `"staging"`, `"development"`

#### `desired_count`
- **Type**: `number`
- **Default**: `1`
- **Description**: Desired number of ECS tasks to run
- **Constraints**: Integer >= 1
- **Example**: `1`, `3`, `10`

#### `task_cpu`
- **Type**: `number`
- **Default**: `2048`
- **Description**: CPU units for ECS task (1024 = 1 vCPU)
- **Constraints**: Must be valid Fargate CPU value: 256, 512, 1024, 2048, 4096
- **Example**: `1024` (1 vCPU), `2048` (2 vCPU), `4096` (4 vCPU)

#### `task_memory`
- **Type**: `number`
- **Default**: `4096`
- **Description**: Memory in MB for ECS task
- **Constraints**: Must be valid Fargate memory value, compatible with CPU
- **Example**: `2048` (2GB), `4096` (4GB), `8192` (8GB)

#### `redis_node_type`
- **Type**: `string`
- **Default**: `"cache.t3.micro"`
- **Description**: ElastiCache Redis node instance type
- **Constraints**: Must be valid ElastiCache node type
- **Example**: `"cache.t3.micro"`, `"cache.t3.small"`, `"cache.t3.medium"`

#### `redis_replica_count`
- **Type**: `number`
- **Default**: `1`
- **Description**: Number of Redis replica nodes
- **Constraints**: Integer >= 0 (0 = no replication, 1+ = high availability)
- **Example**: `0`, `1`, `2`

#### `efs_performance_mode`
- **Type**: `string`
- **Default**: `"generalPurpose"`
- **Description**: EFS performance mode
- **Constraints**: Must be `"generalPurpose"` or `"maxIO"`
- **Example**: `"generalPurpose"` (recommended), `"maxIO"` (for high throughput)

#### `enable_global_accelerator`
- **Type**: `bool`
- **Default**: `true`
- **Description**: Enable AWS Global Accelerator for low-latency routing
- **Constraints**: Boolean
- **Example**: `true` (recommended for South America), `false` (lower cost)

#### `tags`
- **Type**: `map(string)`
- **Default**: `{}`
- **Description**: Additional tags to apply to all resources
- **Constraints**: Map of string key-value pairs
- **Example**: `{ CostCenter = "gaming", Team = "devops" }`

#### `redis_auth_token_secret_name`
- **Type**: `string`
- **Default**: `null`
- **Description**: AWS Secrets Manager secret name containing Redis auth token
- **Constraints**: Must exist in Secrets Manager, or null to auto-generate
- **Example**: `"minecraft/redis/auth-token"`

#### `minecraft_server_port`
- **Type**: `number`
- **Default**: `25565`
- **Description**: Minecraft server port
- **Constraints**: Integer between 1-65535
- **Example**: `25565` (standard), `25566` (custom)

#### `enable_deletion_protection`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Enable deletion protection on ALB (prevents accidental deletion)
- **Constraints**: Boolean
- **Example**: `true` (production), `false` (development, allows terraform destroy)

---

### Module Input Variables

#### VPC Module Variables
- `vpc_cidr`: VPC CIDR block
- `availability_zones`: List of AZs to use
- `public_subnet_cidrs`: List of CIDRs for public subnets
- `private_subnet_cidrs`: List of CIDRs for private subnets
- `tags`: Resource tags

#### ECS Module Variables
- `cluster_name`: ECS cluster name
- `service_name`: ECS service name
- `task_definition`: Task definition configuration
- `container_image`: Container image URI
- `task_cpu`: CPU units
- `task_memory`: Memory MB
- `desired_count`: Desired task count
- `subnet_ids`: Private subnet IDs
- `security_group_ids`: Security group IDs
- `efs_file_system_id`: EFS file system ID
- `target_group_arn`: ALB target group ARN
- `redis_endpoint`: Redis cluster endpoint
- `tags`: Resource tags

#### Storage Module Variables
- `vpc_id`: VPC ID
- `subnet_ids`: Subnet IDs for mount targets
- `security_group_id`: EFS security group ID
- `performance_mode`: EFS performance mode
- `tags`: Resource tags

#### Cache Module Variables
- `cluster_id`: Redis cluster identifier
- `node_type`: Redis node type
- `num_cache_nodes`: Number of cache nodes
- `subnet_group_name`: ElastiCache subnet group name
- `security_group_ids`: Security group IDs
- `auth_token`: Redis auth token (from Secrets Manager)
- `tags`: Resource tags

#### Networking Module Variables
- `vpc_id`: VPC ID
- `subnet_ids`: Public subnet IDs for ALB
- `security_group_id`: ALB security group ID
- `target_group_port`: Target group port
- `enable_global_accelerator`: Enable Global Accelerator
- `tags`: Resource tags

---

## Variable Validation

### Terraform Validation Rules

```hcl
variable "task_cpu" {
  type        = number
  default     = 2048
  description = "CPU units for ECS task"
  
  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.task_cpu)
    error_message = "Task CPU must be one of: 256, 512, 1024, 2048, 4096."
  }
}

variable "task_memory" {
  type        = number
  default     = 4096
  description = "Memory in MB for ECS task"
  
  validation {
    condition     = var.task_memory >= 512 && var.task_memory <= 30720
    error_message = "Task memory must be between 512 and 30720 MB."
  }
}

variable "desired_count" {
  type        = number
  default     = 1
  description = "Desired number of ECS tasks"
  
  validation {
    condition     = var.desired_count > 0 && var.desired_count <= 100
    error_message = "Desired count must be between 1 and 100."
  }
}
```

---

## Output Contracts

### Root Module Outputs

#### `minecraft_endpoint`
- **Type**: `string`
- **Description**: Public endpoint for Minecraft server connection
- **Format**: DNS name or IP address
- **Example**: `"minecraft.example.com"` or `"1.2.3.4"`

#### `redis_endpoint`
- **Type**: `string`
- **Description**: ElastiCache Redis cluster endpoint
- **Format**: `{cluster-id}.cache.amazonaws.com:6379`
- **Example**: `"minecraft-redis.abc123.cache.sa-east-1.amazonaws.com:6379"`

#### `efs_dns_name`
- **Type**: `string`
- **Description**: EFS DNS name for mounting
- **Format**: `{file-system-id}.efs.{region}.amazonaws.com`
- **Example**: `"fs-12345678.efs.sa-east-1.amazonaws.com"`

#### `vpc_id`
- **Type**: `string`
- **Description**: VPC ID
- **Format**: `vpc-{hexadecimal}`
- **Example**: `"vpc-0123456789abcdef0"`

#### `ecs_cluster_id`
- **Type**: `string`
- **Description**: ECS cluster ID/ARN
- **Format**: `arn:aws:ecs:{region}:{account}:cluster/{name}`
- **Example**: `"arn:aws:ecs:sa-east-1:123456789012:cluster/minecraft-cluster"`

---

## Environment Variables (Container)

### Minecraft Server Container Environment Variables

These are passed to the container via ECS task definition, not Terraform variables:

- `EULA`: Must be `"TRUE"` to accept Minecraft EULA
- `VERSION`: Minecraft server version (e.g., `"LATEST"`, `"1.20.1"`)
- `TYPE`: Server type (e.g., `"VANILLA"`, `"FORGE"`, `"SPIGOT"`)
- `MODE`: Server mode (e.g., `"survival"`, `"creative"`)
- `DIFFICULTY`: Game difficulty (e.g., `"easy"`, `"normal"`, `"hard"`)
- `MAX_PLAYERS`: Maximum concurrent players
- `REDIS_HOST`: Redis endpoint (from Terraform output)
- `REDIS_PORT`: Redis port (default: 6379)
- `REDIS_AUTH`: Redis auth token (from Secrets Manager)

---

## Secrets Management Contracts

### AWS Secrets Manager Secrets

#### Redis Auth Token Secret
- **Secret Name**: Configurable via `redis_auth_token_secret_name` variable
- **Secret Format**: Plain text string
- **Access**: ECS task execution role must have `secretsmanager:GetSecretValue` permission
- **Rotation**: Optional, can be configured separately

#### Container Registry Credentials (if using private registry)
- **Secret Name**: Configurable
- **Secret Format**: JSON: `{"username": "...", "password": "..."}`
- **Access**: ECS task execution role must have `secretsmanager:GetSecretValue` permission

---

## Configuration File Contracts

### terraform.tfvars.example

```hcl
# Required
container_image = "itzg/minecraft-server:latest"

# Optional - override defaults
aws_region      = "sa-east-1"
environment     = "production"
desired_count   = 2
task_cpu        = 2048
task_memory     = 4096

# Tags
tags = {
  CostCenter = "gaming"
  Team       = "devops"
  Project    = "minecraft"
}
```

---

## Contract Validation

All variables must be validated at Terraform plan/apply time:
- Type checking: Terraform validates types automatically
- Custom validation: Use `validation` blocks in variable definitions
- Required variables: Must be provided or have defaults
- Secrets: Must exist in Secrets Manager before apply
- Resource limits: AWS service limits must be respected


