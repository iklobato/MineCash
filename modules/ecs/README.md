# ECS Module (Fargate)

Creates an ECS Fargate cluster, task definition, and service for running Minecraft server containers.

## Usage

```hcl
module "ecs" {
  source = "./modules/ecs"

  cluster_name                 = "minecraft-cluster-production"
  service_name                 = "minecraft-server-production"
  container_image              = "itzg/minecraft-server:latest"
  task_cpu                     = 2048
  task_memory                  = 4096
  desired_count                = 1
  subnet_ids                   = module.vpc.private_subnet_ids
  efs_file_system_id           = module.storage.efs_id
  efs_security_group_id        = module.storage.efs_security_group_id
  target_group_arn             = module.networking.target_group_arn
  redis_endpoint               = module.cache.redis_endpoint
  redis_port                   = 6379
  redis_auth_token_secret_name = "minecraft/redis/auth-token"
  minecraft_server_port        = 25565
  project_name                 = "minecraft"
  environment                  = "production"
  tags                         = {}
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_name | ECS cluster name (typically `{project_name}-cluster-{environment}`) | `string` | n/a | yes |
| service_name | ECS service name (typically `{project_name}-server-{environment}`) | `string` | n/a | yes |
| container_image | Docker image URI for Minecraft server container | `string` | n/a | yes |
| task_cpu | CPU units for ECS task (1024 = 1 vCPU) | `number` | `2048` | no |
| task_memory | Memory in MB for ECS task | `number` | `4096` | no |
| desired_count | Desired number of ECS tasks | `number` | `1` | no |
| subnet_ids | List of private subnet IDs for ECS tasks | `list(string)` | n/a | yes |
| efs_file_system_id | EFS file system ID | `string` | n/a | yes |
| efs_security_group_id | EFS security group ID | `string` | n/a | yes |
| target_group_arn | ALB target group ARN | `string` | n/a | yes |
| redis_endpoint | Redis cluster endpoint | `string` | n/a | yes |
| redis_port | Redis port | `number` | `6379` | no |
| redis_auth_token_secret_name | AWS Secrets Manager secret name containing Redis auth token | `string` | `null` | no |
| minecraft_server_port | Minecraft server port (default: 25565) | `number` | `25565` | no |
| project_name | Project name used for resource naming (e.g., 'minecraft') | `string` | n/a | yes |
| environment | Environment name used for resource naming and tagging (e.g., 'production', 'staging') | `string` | n/a | yes |
| tags | Additional tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| ecs_cluster_id | ECS cluster ID/ARN |
| ecs_service_id | ECS service ID |
| ecs_task_security_group_id | ECS task security group ID |
| ecs_task_definition_arn | ECS task definition ARN |

## Resources Created

- 1 CloudWatch Log Group (`/ecs/{project_name}-server`, e.g., `/ecs/minecraft-server`)
- 1 ECS Cluster (Fargate)
- 1 IAM Role (Task Execution - for ECS agent)
- 1 IAM Role (Task - for application)
- 1 Security Group (allows TCP 25565 from ALB, TCP 6379 from Redis)
- 1 Task Definition (Fargate, with EFS volume, environment variables, secrets)
- 1 ECS Service (Fargate launch type, load balancer integration, zero-downtime deployment)

## Notes

- Tasks run in private subnets (no public IP)
- EFS volume mounted at /data for persistent storage
- Secrets retrieved from Secrets Manager
- Session Manager enabled for administrative access (enable_execute_command = true)
- Deployment circuit breaker enabled for automatic rollback
- Zero-downtime deployments configured (200% max, 100% min healthy)


