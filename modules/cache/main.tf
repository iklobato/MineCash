# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "main" {
  name       = var.subnet_group_name
  subnet_ids = var.subnet_ids

  tags = merge(
    {
      Name = var.subnet_group_name
    },
    var.tags
  )
}

# Redis Security Group
# Note: Ingress rule will be added via security_group_rule in root module
# to avoid circular dependency with ECS module
resource "aws_security_group" "redis" {
  name        = "minecraft-redis-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = data.aws_subnet.main.vpc_id

  egress {
    description = "No outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = []
  }

  tags = merge(
    {
      Name = "minecraft-redis-sg"
    },
    var.tags
  )
}

# Get subnet info for VPC ID
data "aws_subnet" "main" {
  id = var.subnet_ids[0]
}

# Get Redis auth token from Secrets Manager (if provided)
data "aws_secretsmanager_secret" "redis_auth" {
  count = var.auth_token_secret_name != null ? 1 : 0
  name  = var.auth_token_secret_name
}

data "aws_secretsmanager_secret_version" "redis_auth" {
  count     = var.auth_token_secret_name != null ? 1 : 0
  secret_id = data.aws_secretsmanager_secret.redis_auth[0].id
}

# ElastiCache Parameter Group
resource "aws_elasticache_parameter_group" "main" {
  name   = "${var.cluster_id}-params"
  family = "redis7"

  tags = merge(
    {
      Name = "${var.cluster_id}-params"
    },
    var.tags
  )
}

# ElastiCache Replication Group (Redis Cluster Mode Enabled)
resource "aws_elasticache_replication_group" "main" {
  replication_group_id       = var.cluster_id
  description                = "Redis cluster for Minecraft server"
  node_type                  = var.node_type
  port                       = 6379
  parameter_group_name       = aws_elasticache_parameter_group.main.name
  num_cache_clusters         = var.num_cache_nodes
  automatic_failover_enabled = var.num_cache_nodes > 1
  multi_az_enabled           = var.num_cache_nodes > 1
  subnet_group_name          = aws_elasticache_subnet_group.main.name
  security_group_ids         = [aws_security_group.redis.id]
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.auth_token_secret_name != null ? data.aws_secretsmanager_secret_version.redis_auth[0].secret_string : null

  tags = merge(
    {
      Name = var.cluster_id
    },
    var.tags
  )
}

