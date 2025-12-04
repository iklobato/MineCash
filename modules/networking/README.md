# Networking Module (ALB + Global Accelerator)

Creates an Application Load Balancer with target group and listener for distributing Minecraft server traffic. Global Accelerator integration is handled at the root module level.

## Usage

```hcl
module "networking" {
  source = "./modules/networking"

  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = module.vpc.public_subnet_ids
  target_group_port         = 25565
  enable_deletion_protection = false
  project_name              = "minecraft"
  environment               = "production"
  tags                      = {}
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| vpc_id | VPC ID | `string` | n/a | yes |
| subnet_ids | List of public subnet IDs for ALB | `list(string)` | n/a | yes |
| target_group_port | Port for target group (Minecraft server port) | `number` | `25565` | no |
| enable_global_accelerator | Enable Global Accelerator | `bool` | `true` | no |
| enable_deletion_protection | Enable deletion protection on ALB | `bool` | `false` | no |
| project_name | Project name used for resource naming (e.g., 'minecraft') | `string` | n/a | yes |
| environment | Environment name used for resource naming and tagging (e.g., 'production', 'staging') | `string` | n/a | yes |
| tags | Additional tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| alb_arn | Application Load Balancer ARN |
| alb_dns_name | Application Load Balancer DNS name |
| target_group_arn | Target group ARN |
| alb_security_group_id | ALB security group ID |
| listener_arn | ALB listener ARN |

## Resources Created

- 1 Security Group (allows TCP 25565 from 0.0.0.0/0)
- 1 Application Load Balancer (public, in public subnets)
- 1 Target Group (TCP, port 25565, IP target type)
- 1 ALB Listener (TCP, forwards to target group)

## Notes

- ALB is created in public subnets for internet access
- Target group uses IP target type for ECS Fargate tasks
- Health checks configured for TCP protocol
- Global Accelerator integration handled at root module level for optimal latency routing

## Global Accelerator Latency Optimization

Global Accelerator is configured at the root module level to provide optimal routing for players in South America:

- Routes traffic via AWS backbone network for lowest latency
- Provides stable static IP addresses (anycast)
- Automatically routes to nearest healthy endpoint
- Reduces latency and jitter for gaming workloads

For players in Brazil/South America, Global Accelerator typically provides <50ms latency when connecting to the Minecraft server deployed in sa-east-1 (São Paulo) region.

