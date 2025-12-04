# Storage Module (EFS)

Creates an Amazon EFS file system with mount targets for persistent shared storage, compatible with ECS Fargate.

## Usage

```hcl
module "storage" {
  source = "./modules/storage"

  vpc_id           = module.vpc.vpc_id
  subnet_ids       = module.vpc.private_subnet_ids
  performance_mode = "generalPurpose"
  project_name     = "minecraft"
  environment      = "production"
  tags             = {}
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| vpc_id | VPC ID | `string` | n/a | yes |
| subnet_ids | List of subnet IDs for EFS mount targets | `list(string)` | n/a | yes |
| performance_mode | EFS performance mode (generalPurpose or maxIO) | `string` | `"generalPurpose"` | no |
| project_name | Project name used for resource naming (e.g., 'minecraft') | `string` | n/a | yes |
| environment | Environment name used for resource naming and tagging (e.g., 'production', 'staging') | `string` | n/a | yes |
| tags | Additional tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| efs_id | EFS file system ID |
| efs_dns_name | EFS DNS name for mounting |
| efs_security_group_id | EFS security group ID |
| efs_arn | EFS file system ARN |

## Resources Created

- 1 EFS File System (encrypted, generalPurpose performance mode, bursting throughput)
- 2+ EFS Mount Targets (one per subnet/AZ)
- 1 Security Group (allows NFS from ECS tasks)

## Notes

- EFS automatically scales storage capacity (no manual intervention needed)
- Performance mode `generalPurpose` is recommended for small files and metadata operations
- Throughput mode `bursting` is cost-effective for variable workloads
- Encryption at rest is enabled by default
- Storage scales seamlessly from GB to PB without downtime or manual provisioning

