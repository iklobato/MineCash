# Data Model: AWS Minecraft Server Infrastructure

**Date**: 2024-12-19  
**Feature**: AWS Minecraft Server Infrastructure  
**Purpose**: Define Terraform resource structures and data relationships

## Overview

This infrastructure project uses Terraform to define AWS resources. The "data model" here represents the Terraform resource structures, variable schemas, and output definitions that compose the infrastructure.

## Core Resource Entities

### VPC Network

**Purpose**: Virtual network containing all infrastructure components

**Terraform Resource**: `aws_vpc`

**Attributes**:
- `cidr_block`: VPC CIDR range (default: 10.0.0.0/16)
- `enable_dns_hostnames`: true
- `enable_dns_support`: true
- `tags`: Project, Environment, ManagedBy

**Relationships**:
- Contains: Subnets (public and private)
- Has: Internet Gateway (public)
- Has: NAT Gateway (private subnets)
- Has: Route Tables

---

### Subnets

**Purpose**: Network isolation zones across multiple Availability Zones

**Terraform Resource**: `aws_subnet`

**Types**:
1. **Public Subnets** (for NAT Gateway, Load Balancer)
   - `map_public_ip_on_launch`: true
   - Route: Internet Gateway
   
2. **Private Subnets** (for ECS tasks, Redis, EFS)
   - `map_public_ip_on_launch`: false
   - Route: NAT Gateway

**Attributes**:
- `availability_zone`: One per AZ (minimum 2 AZs)
- `cidr_block`: Subnet CIDR (e.g., 10.0.1.0/24, 10.0.2.0/24)
- `vpc_id`: Reference to VPC

**Constraints**:
- Minimum 2 Availability Zones for high availability
- Public subnets: 2+ (one per AZ)
- Private subnets: 2+ (one per AZ)

---

### Security Groups

**Purpose**: Network-level access control

**Terraform Resource**: `aws_security_group`

**Types**:
1. **ALB Security Group**
   - Inbound: TCP 25565 (Minecraft) from 0.0.0.0/0
   - Outbound: All traffic

2. **ECS Task Security Group**
   - Inbound: TCP 25565 from ALB security group
   - Inbound: TCP 6379 (Redis) from Redis security group
   - Outbound: All traffic (via NAT Gateway)

3. **Redis Security Group**
   - Inbound: TCP 6379 from ECS task security group
   - Outbound: None

4. **EFS Security Group**
   - Inbound: NFS (2049) from ECS task security group
   - Outbound: None

**Attributes**:
- `name`: Descriptive name
- `description`: Purpose description
- `vpc_id`: Reference to VPC
- `ingress`: List of ingress rules
- `egress`: List of egress rules

---

### ECS Cluster

**Purpose**: Container orchestration platform

**Terraform Resource**: `aws_ecs_cluster`

**Attributes**:
- `name`: Cluster name
- `capacity_providers`: ["FARGATE", "FARGATE_SPOT"]
- `default_capacity_provider_strategy`: Fargate

**Relationships**:
- Contains: ECS Services
- Uses: Private subnets
- Uses: EFS for storage

---

### ECS Task Definition

**Purpose**: Container specification and resource allocation

**Terraform Resource**: `aws_ecs_task_definition`

**Attributes**:
- `family`: Task definition family name
- `network_mode`: awsvpc
- `requires_compatibilities`: ["FARGATE"]
- `cpu`: 2048 (2 vCPU, default)
- `memory`: 4096 (4GB, default)
- `execution_role_arn`: IAM role for ECS agent
- `task_role_arn`: IAM role for container
- `container_definitions`: JSON definition

**Container Definition Structure**:
```json
{
  "name": "minecraft-server",
  "image": "${var.container_image}",
  "essential": true,
  "portMappings": [{
    "containerPort": 25565,
    "protocol": "tcp"
  }],
  "mountPoints": [{
    "sourceVolume": "efs-storage",
    "containerPath": "/data"
  }],
  "environment": [...],
  "secrets": [...],
  "logConfiguration": {...}
}
```

**Relationships**:
- Uses: EFS volume
- Uses: Security groups
- Uses: IAM roles
- Referenced by: ECS Service

---

### ECS Service

**Purpose**: Maintains desired number of running tasks

**Terraform Resource**: `aws_ecs_service`

**Attributes**:
- `name`: Service name
- `cluster`: ECS cluster reference
- `task_definition`: Task definition reference
- `desired_count`: Number of tasks (default: 1)
- `launch_type`: FARGATE
- `network_configuration`: Subnets, security groups
- `load_balancer`: ALB target group configuration
- `deployment_configuration`: Rolling update settings

**Relationships**:
- Manages: ECS Tasks
- Uses: Task Definition
- Uses: ALB Target Group
- Uses: Private subnets

---

### EFS File System

**Purpose**: Persistent shared storage for world data

**Terraform Resource**: `aws_efs_file_system`

**Attributes**:
- `creation_token`: Unique identifier
- `performance_mode`: generalPurpose
- `throughput_mode`: bursting
- `encrypted`: true
- `tags`: Resource tags

**Relationships**:
- Has: Mount Targets (one per AZ)
- Has: Access Points (optional)
- Used by: ECS Tasks

---

### ElastiCache Redis Cluster

**Purpose**: Caching and state management

**Terraform Resource**: `aws_elasticache_replication_group`

**Attributes**:
- `replication_group_id`: Cluster identifier
- `description`: Cluster description
- `node_type`: cache.t3.micro
- `port`: 6379
- `parameter_group_name`: Redis parameter group
- `num_cache_clusters`: 2 (1 primary + 1 replica)
- `automatic_failover_enabled`: true
- `multi_az_enabled`: true
- `at_rest_encryption_enabled`: true
- `transit_encryption_enabled`: true
- `auth_token`: From Secrets Manager
- `subnet_group_name`: ElastiCache subnet group
- `security_group_ids`: Redis security group

**Relationships**:
- Uses: ElastiCache Subnet Group
- Uses: Security Group
- Uses: Parameter Group
- Accessed by: ECS Tasks

---

### Application Load Balancer

**Purpose**: Distributes player traffic to ECS tasks

**Terraform Resource**: `aws_lb`

**Attributes**:
- `name`: ALB name
- `internal`: false (public)
- `load_balancer_type`: application
- `subnets`: Public subnet IDs
- `security_groups`: ALB security group
- `enable_deletion_protection`: false (for terraform destroy)

**Relationships**:
- Has: Target Groups
- Has: Listeners
- Uses: Public subnets
- Uses: Security groups
- Connected to: Global Accelerator

---

### Global Accelerator

**Purpose**: Optimizes routing for low latency

**Terraform Resource**: `aws_globalaccelerator_accelerator`

**Attributes**:
- `name`: Accelerator name
- `ip_address_type`: IPV4
- `enabled`: true

**Relationships**:
- Has: Listeners
- Has: Endpoint Groups (pointing to ALB)

---

## Variable Schema

### Root Module Variables

**Required Variables**:
- `aws_region`: AWS region (default: "sa-east-1")
- `container_image`: Docker image for Minecraft server

**Optional Variables**:
- `vpc_cidr`: VPC CIDR block (default: "10.0.0.0/16")
- `environment`: Environment name (default: "production")
- `desired_count`: ECS service desired count (default: 1)
- `task_cpu`: Task CPU units (default: 2048)
- `task_memory`: Task memory MB (default: 4096)
- `redis_node_type`: ElastiCache node type (default: "cache.t3.micro")
- `redis_replica_count`: Redis replica count (default: 1)
- `efs_performance_mode`: EFS performance mode (default: "generalPurpose")
- `enable_global_accelerator`: Enable Global Accelerator (default: true)
- `tags`: Additional resource tags (default: {})

**Secret Variables** (via data sources):
- Redis auth token: Retrieved from Secrets Manager
- Container registry credentials: Retrieved from Secrets Manager (if needed)

---

## Output Schema

### Root Module Outputs

**Connection Information**:
- `minecraft_endpoint`: Public endpoint (ALB DNS or Global Accelerator IP)
- `redis_endpoint`: ElastiCache Redis endpoint
- `efs_dns_name`: EFS DNS name for mounting

**Resource IDs**:
- `vpc_id`: VPC ID
- `ecs_cluster_id`: ECS cluster ID
- `ecs_service_id`: ECS service ID
- `alb_arn`: Application Load Balancer ARN
- `redis_cluster_id`: ElastiCache cluster ID
- `efs_id`: EFS file system ID

**Network Information**:
- `public_subnet_ids`: List of public subnet IDs
- `private_subnet_ids`: List of private subnet IDs
- `security_group_ids`: Map of security group IDs by name

**Deployment Information**:
- `terraform_state_bucket`: S3 bucket for Terraform state
- `deployment_region`: AWS region where resources are deployed

---

## Data Flow

1. **Player Connection Flow**:
   - Player → Global Accelerator → ALB → Target Group → ECS Task (port 25565)

2. **Container Storage Access**:
   - ECS Task → EFS Mount Target → EFS File System

3. **Cache Access**:
   - ECS Task → Redis Security Group → ElastiCache Redis Cluster

4. **Administrative Access**:
   - DevOps Engineer → Systems Manager Session Manager → ECS Task

5. **Outbound Internet Access**:
   - ECS Task → NAT Gateway → Internet Gateway → Internet

---

## State Transitions

### ECS Task Lifecycle
1. **Created**: Task definition created, no running tasks
2. **Pending**: Task scheduled, pulling container image
3. **Running**: Task running, health checks passing
4. **Stopped**: Task stopped (manual or due to failure)
5. **Destroyed**: Task removed (via terraform destroy)

### Infrastructure Lifecycle
1. **Initialized**: Terraform initialized, state backend configured
2. **Planned**: terraform plan executed, changes previewed
3. **Applied**: terraform apply executed, resources created
4. **Running**: All resources operational, service healthy
5. **Updated**: terraform apply executed with changes
6. **Destroyed**: terraform destroy executed, all resources removed

---

## Validation Rules

### CIDR Block Validation
- VPC CIDR must be valid IPv4 CIDR (e.g., 10.0.0.0/16)
- Subnet CIDRs must be within VPC CIDR
- Subnet CIDRs must not overlap

### Resource Naming
- All resource names must be unique within AWS account
- Naming convention: `{project}-{component}-{environment}-{identifier}`
- Example: `minecraft-vpc-production-main`

### Port Validation
- Minecraft server port: 25565 (standard)
- Redis port: 6379 (standard)
- ALB listener port: 80/443 (HTTP/HTTPS)

### Capacity Validation
- ECS task CPU: Must be valid Fargate CPU value (256, 512, 1024, 2048, 4096)
- ECS task memory: Must be valid Fargate memory value (512MB to 30GB)
- Memory must be compatible with CPU (see AWS Fargate documentation)

---

## Relationships Summary

```
VPC
├── Public Subnets (2+)
│   ├── NAT Gateway
│   └── Application Load Balancer
│       └── Global Accelerator
│
├── Private Subnets (2+)
│   ├── ECS Tasks
│   │   ├── EFS Mount
│   │   └── Redis Connection
│   ├── ElastiCache Redis
│   └── EFS Mount Targets
│
└── Security Groups
    ├── ALB Security Group
    ├── ECS Task Security Group
    ├── Redis Security Group
    └── EFS Security Group
```


