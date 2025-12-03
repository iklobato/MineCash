# Cache Module (ElastiCache Redis)

Creates an ElastiCache Redis cluster with Cluster Mode Enabled, replication, encryption, and secure access.

## Usage

```hcl
module "cache" {
  source = "./modules/cache"

  cluster_id              = "minecraft-redis-production"
  node_type              = "cache.t3.micro"
  num_cache_nodes        = 2
  subnet_group_name      = "minecraft-redis-subnet-production"
  subnet_ids             = module.vpc.private_subnet_ids
  auth_token_secret_name = "minecraft/redis/auth-token"
  tags                   = {}
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_id | Redis cluster identifier | `string` | n/a | yes |
| node_type | Redis node instance type | `string` | `"cache.t3.micro"` | no |
| num_cache_nodes | Number of cache nodes (primary + replicas) | `number` | `2` | no |
| subnet_group_name | ElastiCache subnet group name | `string` | n/a | yes |
| subnet_ids | List of subnet IDs for ElastiCache subnet group | `list(string)` | n/a | yes |
| auth_token_secret_name | AWS Secrets Manager secret name containing Redis auth token | `string` | `null` | no |
| tags | Additional tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| redis_endpoint | ElastiCache Redis cluster endpoint |
| redis_port | Redis port |
| redis_cluster_id | ElastiCache Redis cluster ID |
| redis_security_group_id | Redis security group ID |
| redis_primary_endpoint | Redis primary endpoint address |

## Resources Created

- 1 ElastiCache Subnet Group
- 1 Security Group (allows TCP 6379 from ECS tasks)
- 1 Parameter Group (Redis 7 family)
- 1 Replication Group (Cluster Mode Enabled, encrypted, with replication if num_cache_nodes > 1)

## Notes

- Cluster Mode Enabled for scalability
- Encryption in-transit and at-rest enabled
- Automatic failover enabled if num_cache_nodes > 1
- Multi-AZ enabled if num_cache_nodes > 1
- Auth token retrieved from Secrets Manager (if provided)
- Security group restricts access to ECS tasks only

