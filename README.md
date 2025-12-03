# AWS Minecraft Server Infrastructure

Production-ready Terraform project for deploying a containerized Minecraft server on AWS, optimized for low latency in Brazil/South America.

## Features

- **VPC with Public/Private Subnets**: Multi-AZ deployment for high availability
- **ECS Fargate**: Serverless container orchestration (no EC2 management)
- **EFS Storage**: Persistent shared storage for world data, mods, and plugins
- **ElastiCache Redis**: Managed Redis cluster for caching and state management
- **Application Load Balancer**: Distributes player traffic
- **Global Accelerator**: Optimizes routing for lowest latency via AWS backbone
- **Route 53 DNS**: Automatic DNS record creation for friendly hostnames (subdomain or apex domain)
- **Security**: Security groups, Secrets Manager integration, Systems Manager Session Manager

## Architecture Overview

### High-Level Architecture

The infrastructure follows a three-tier architecture pattern with clear network isolation:

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet                                 │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ TCP 25565 (Minecraft)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              AWS Global Accelerator (Optional)                  │
│         Static IP addresses, optimal routing via AWS backbone   │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              Application Load Balancer (Public)                 │
│         Health checks, traffic distribution, TCP listener      │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ TCP 25565
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    VPC (10.0.0.0/16)                            │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Public Subnets (AZ-1, AZ-2)                           │   │
│  │  ├── NAT Gateway (per AZ)                               │   │
│  │  └── Application Load Balancer                          │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Private Subnets (AZ-1, AZ-2)                           │   │
│  │  ├── ECS Fargate Tasks (Minecraft Server)                │   │
│  │  ├── ElastiCache Redis Cluster                           │   │
│  │  └── EFS Mount Targets                                    │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Component Relationships

1. **Network Layer**: VPC provides isolated network with public/private subnets across multiple AZs
2. **Compute Layer**: ECS Fargate runs Minecraft server containers in private subnets
3. **Storage Layer**: EFS provides persistent shared storage accessible from all containers
4. **Cache Layer**: ElastiCache Redis provides fast state management and caching
5. **Traffic Layer**: ALB distributes player traffic, Global Accelerator optimizes routing
6. **Security Layer**: Security groups enforce least-privilege access, Secrets Manager handles credentials

### Network Topology

**Public Subnets** (10.0.1.0/24, 10.0.2.0/24):
- Host NAT Gateways (one per AZ for high availability)
- Host Application Load Balancer (spans multiple AZs)
- Route traffic via Internet Gateway for direct internet access

**Private Subnets** (10.0.11.0/24, 10.0.12.0/24):
- Host ECS Fargate tasks (no public IPs)
- Host ElastiCache Redis cluster
- Host EFS mount targets
- Route outbound traffic via NAT Gateway (no inbound internet access)

### Multi-AZ Deployment Strategy

- **Minimum 2 Availability Zones**: Ensures high availability
- **NAT Gateway per AZ**: Prevents single point of failure for outbound connectivity
- **EFS Mount Targets per AZ**: Enables fast local access to shared storage
- **ECS Tasks distributed**: Automatically distributed across AZs by ECS service
- **Redis Multi-AZ**: Automatic failover if primary node fails

### Security Architecture

- **Defense in Depth**: Multiple security layers (VPC isolation, security groups, encryption)
- **Least Privilege**: Security groups restrict access to only necessary ports and sources
- **No Direct Internet Access**: Containers in private subnets, no public IPs
- **Encrypted Communications**: All data encrypted in-transit (TLS) and at-rest (AES-256)
- **Secrets Management**: No hard-coded credentials, all secrets from AWS Secrets Manager
- **Audit Trail**: Session Manager logs all administrative access

## Prerequisites

- Terraform >= 1.0
- AWS CLI >= 2.0 configured with appropriate credentials
- AWS account with permissions to create VPC, ECS, EFS, ElastiCache, ALB, Global Accelerator resources

### Required AWS Permissions

The AWS credentials must have permissions to create and manage:
- VPC, Subnets, Route Tables, Internet Gateway, NAT Gateway
- ECS Cluster, Task Definitions, Services, IAM Roles
- EFS File Systems, Mount Targets
- ElastiCache Redis Clusters, Subnet Groups, Parameter Groups
- Application Load Balancer, Target Groups, Listeners
- Global Accelerator, Listeners, Endpoint Groups
- Security Groups and Rules
- Secrets Manager secrets (if creating)
- CloudWatch Log Groups

### AWS Service Quotas

Ensure your AWS account has sufficient quotas:
- VPCs per region: At least 1
- NAT Gateways per AZ: At least 1
- ECS tasks: At least 10 (for scaling)
- ElastiCache clusters: At least 1
- Elastic IPs: At least 2 (for NAT Gateways)

## Quick Start

1. **Clone and navigate**:
   ```bash
   cd terraform
   ```

2. **Configure variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. **Create Redis auth token secret** (if not using auto-generation):
   ```bash
   aws secretsmanager create-secret \
     --name minecraft/redis/auth-token \
     --secret-string "$(openssl rand -base64 32)" \
     --region sa-east-1
   ```

4. **Initialize Terraform**:
   ```bash
   terraform init
   ```

5. **Review plan**:
   ```bash
   terraform plan
   ```

6. **Deploy infrastructure**:
   ```bash
   terraform apply
   ```

7. **Get connection information**:
   ```bash
   terraform output minecraft_endpoint
   ```

## Project Structure

### Directory Layout

```
terraform/
├── main.tf                      # Root module - orchestrates all sub-modules
├── variables.tf                 # Input variables with defaults and validation
├── outputs.tf                   # Output values (endpoints, IDs, etc.)
├── terraform.tfvars.example     # Example variable values
├── versions.tf                  # Provider version constraints
├── backend.tf.example          # Example S3 backend configuration
├── README.md                    # This comprehensive documentation
│
├── modules/
│   ├── vpc/                     # VPC module
│   │   ├── main.tf              # VPC, subnets, gateways, route tables
│   │   ├── variables.tf         # Module input variables
│   │   ├── outputs.tf           # Module outputs (VPC ID, subnet IDs, etc.)
│   │   └── README.md            # Module-specific documentation
│   │
│   ├── ecs/                     # ECS Fargate module
│   │   ├── main.tf              # Cluster, task definition, service, IAM roles
│   │   ├── variables.tf         # Module input variables
│   │   ├── outputs.tf           # Module outputs (cluster ID, service ID, etc.)
│   │   ├── task-definition.json.tpl  # Task definition template
│   │   └── README.md            # Module-specific documentation
│   │
│   ├── storage/                 # EFS storage module
│   │   ├── main.tf              # EFS file system, mount targets, security group
│   │   ├── variables.tf         # Module input variables
│   │   ├── outputs.tf           # Module outputs (EFS ID, DNS name, etc.)
│   │   └── README.md            # Module-specific documentation
│   │
│   ├── cache/                   # ElastiCache Redis module
│   │   ├── main.tf              # Redis cluster, subnet group, security group
│   │   ├── variables.tf         # Module input variables
│   │   ├── outputs.tf           # Module outputs (Redis endpoint, etc.)
│   │   └── README.md            # Module-specific documentation
│   │
│   ├── networking/              # ALB + Global Accelerator module
│   │   ├── main.tf              # ALB, target group, listener, security group
│   │   ├── variables.tf         # Module input variables
│   │   ├── outputs.tf           # Module outputs (ALB ARN, DNS name, etc.)
│   │   └── README.md            # Module-specific documentation
│   │
│   └── route53-dns/             # Route 53 DNS module
│       ├── main.tf              # Route 53 record, hosted zone lookup, alias configuration
│       ├── variables.tf         # Module input variables
│       ├── outputs.tf           # Module outputs (FQDN, record name)
│       ├── versions.tf          # Provider requirements
│       └── README.md            # Module-specific documentation
```

### File-by-File Explanation

**Root Module Files**:

- `main.tf`: Orchestrates all modules, defines provider configuration, creates Global Accelerator resources, and manages security group cross-references between modules
- `variables.tf`: Defines all input variables with types, defaults, descriptions, and validation rules
- `outputs.tf`: Exposes important resource identifiers and connection information for use by other systems or operators
- `versions.tf`: Constrains Terraform and provider versions to ensure compatibility
- `terraform.tfvars.example`: Example configuration file showing all available variables with sample values
- `backend.tf.example`: Example remote state backend configuration using S3 and DynamoDB

**Module Files** (each module follows same pattern):

- `main.tf`: Contains all resource definitions for the module (the "what" and "how")
- `variables.tf`: Defines module inputs (the "interface" that callers must provide)
- `outputs.tf`: Defines module outputs (the "results" that other modules can use)
- `README.md`: Module-specific documentation explaining usage, inputs, outputs, and resources created

**Special Files**:

- `modules/ecs/task-definition.json.tpl`: Template file for ECS task definition container configuration, uses Terraform templatefile() function for variable substitution
- `modules/route53-dns/INTEGRATION_EXAMPLE.md`: Integration guide for Route 53 DNS module

## Component Deep Dive

### VPC Module (`modules/vpc/`)

**Purpose**: Creates the foundational network infrastructure that all other components depend on.

**Responsibilities**:
- Virtual Private Cloud (VPC) creation and configuration
- Public and private subnet provisioning across multiple Availability Zones
- Internet Gateway for public subnet internet access
- NAT Gateways for private subnet outbound internet access
- Route table configuration for proper traffic routing

**Resources Created**:

1. **VPC** (`aws_vpc.main`):
   - CIDR block: Configurable via `vpc_cidr` variable (default: 10.0.0.0/16)
   - DNS hostnames: Enabled (required for ECS service discovery)
   - DNS support: Enabled (required for VPC DNS resolution)

2. **Public Subnets** (`aws_subnet.public`, one per AZ):
   - CIDR blocks: Calculated dynamically from VPC CIDR (e.g., 10.0.1.0/24, 10.0.2.0/24)
   - `map_public_ip_on_launch`: true (enables automatic public IP assignment)
   - Purpose: Host NAT Gateways and Application Load Balancer

3. **Private Subnets** (`aws_subnet.private`, one per AZ):
   - CIDR blocks: Calculated dynamically from VPC CIDR (e.g., 10.0.11.0/24, 10.0.12.0/24)
   - `map_public_ip_on_launch`: false (no public IPs)
   - Purpose: Host ECS tasks, Redis, and EFS mount targets

4. **Internet Gateway** (`aws_internet_gateway.main`):
   - Attached to VPC
   - Enables public subnet resources to access internet directly

5. **NAT Gateways** (`aws_nat_gateway.main`, one per AZ):
   - Elastic IP: One per NAT Gateway (from `aws_eip.nat`)
   - Subnet: Placed in public subnet
   - Purpose: Enables private subnet resources to access internet for outbound connections (container image pulls, updates)

6. **Route Tables**:
   - **Public Route Table** (`aws_route_table.public`): Routes 0.0.0.0/0 → Internet Gateway
   - **Private Route Tables** (`aws_route_table.private`, one per AZ): Routes 0.0.0.0/0 → NAT Gateway (per AZ)

**Network Isolation Strategy**:
- Public subnets: Direct internet access via Internet Gateway (for ALB, NAT Gateway)
- Private subnets: No direct internet access, outbound only via NAT Gateway (for ECS tasks, Redis, EFS)
- Security groups: Additional layer of network security (see Security section)

**CIDR Allocation Logic**:
- VPC CIDR: 10.0.0.0/16 (65,536 IP addresses)
- Public subnets: /24 (256 IPs each) - 10.0.1.0/24, 10.0.2.0/24, etc.
- Private subnets: /24 (256 IPs each) - 10.0.11.0/24, 10.0.12.0/24, etc.
- Allocation uses `cidrsubnet()` function for automatic calculation

**High Availability Design**:
- Minimum 2 Availability Zones required
- NAT Gateway per AZ prevents single point of failure
- Subnets distributed across AZs for redundancy
- Route tables per AZ for independent routing

**Module Interface**:

**Inputs** (`modules/vpc/variables.tf`):
- `vpc_cidr`: VPC CIDR block (required)
- `availability_zones`: List of AZs to use (required)
- `public_subnet_cidrs`: List of CIDR blocks for public subnets (required)
- `private_subnet_cidrs`: List of CIDR blocks for private subnets (required)
- `tags`: Additional tags (optional)

**Outputs** (`modules/vpc/outputs.tf`):
- `vpc_id`: VPC ID (used by all other modules)
- `public_subnet_ids`: List of public subnet IDs (used by networking module)
- `private_subnet_ids`: List of private subnet IDs (used by ECS, storage, cache modules)
- `nat_gateway_id`: First NAT Gateway ID (for reference)
- `nat_gateway_ids`: All NAT Gateway IDs
- `internet_gateway_id`: Internet Gateway ID

---

### Storage Module (`modules/storage/`)

**Purpose**: Provides persistent shared storage for Minecraft world data, mods, plugins, and configuration files.

**Responsibilities**:
- Amazon EFS file system creation and configuration
- Mount target provisioning across Availability Zones
- Security group management for NFS access
- Performance and encryption configuration

**Resources Created**:

1. **EFS File System** (`aws_efs_file_system.main`):
   - **Performance Mode**: `generalPurpose` (default, configurable)
     - Optimized for small files and metadata operations
     - Suitable for Minecraft world files, configs, mods
     - Alternative: `maxIO` for high-throughput workloads (not needed for typical Minecraft usage)
   - **Throughput Mode**: `bursting` (fixed)
     - Cost-effective for variable workloads
     - Provides baseline throughput with burst credits
     - Automatically scales based on file system size
   - **Encryption**: At-rest encryption enabled (AES-256)
   - **Lifecycle Management**: Not configured (all data in standard storage class)

2. **EFS Mount Targets** (`aws_efs_mount_target.main`, one per subnet/AZ):
   - **Purpose**: Provides network interface for ECS tasks to mount EFS
   - **Placement**: One mount target per private subnet/AZ
   - **Security**: Protected by EFS security group
   - **High Availability**: Mount targets in multiple AZs ensure availability

3. **EFS Security Group** (`aws_security_group.efs`):
   - **Ingress**: TCP 2049 (NFS) from ECS task security group (added via security_group_rule in root module)
   - **Egress**: All traffic allowed (for NFS protocol requirements)
   - **Isolation**: Only accessible from ECS tasks, not from internet or other resources

**Use Cases**:

- **World Data**: Minecraft world files stored persistently, survives container restarts
- **Mods/Plugins**: Server modifications and plugins stored in `/data/plugins/` or `/data/mods/`
- **Configuration Files**: `server.properties`, `bukkit.yml`, and other config files
- **Logs**: Server logs can be written to EFS for centralized access

**Storage Scaling**:
- EFS automatically scales from GB to PB without manual intervention
- No need to provision storage capacity upfront
- Pay only for storage used
- Performance scales with file system size (larger = more baseline throughput)

**Mount Configuration**:
- EFS mounted at `/data` in containers (configurable in task definition)
- Uses IAM authorization (enabled in task definition volume config)
- Transit encryption enabled for data in-flight

**Module Interface**:

**Inputs** (`modules/storage/variables.tf`):
- `vpc_id`: VPC ID (required)
- `subnet_ids`: List of subnet IDs for mount targets (required)
- `performance_mode`: EFS performance mode (default: "generalPurpose")
- `tags`: Additional tags (optional)

**Outputs** (`modules/storage/outputs.tf`):
- `efs_id`: EFS file system ID (used by ECS module)
- `efs_dns_name`: EFS DNS name for mounting (used for manual mounts if needed)
- `efs_security_group_id`: EFS security group ID (used for security group rules)
- `efs_arn`: EFS ARN (for IAM policies, backups)

---

### Cache Module (`modules/cache/`)

**Purpose**: Provides managed Redis cluster for caching and state management for the Minecraft server.

**Responsibilities**:
- ElastiCache Redis cluster creation with Cluster Mode Enabled
- Subnet group configuration for VPC placement
- Security group management for Redis access
- Encryption configuration (in-transit and at-rest)
- Authentication token management via Secrets Manager

**Resources Created**:

1. **ElastiCache Subnet Group** (`aws_elasticache_subnet_group.main`):
   - **Purpose**: Defines which subnets Redis cluster can be placed in
   - **Subnets**: Private subnets only (for security)
   - **Multi-AZ**: Automatically distributes nodes across AZs

2. **Redis Security Group** (`aws_security_group.redis`):
   - **Ingress**: TCP 6379 from ECS task security group (added via security_group_rule in root module)
   - **Egress**: None (Redis doesn't initiate outbound connections)
   - **Isolation**: Only accessible from ECS tasks within VPC

3. **ElastiCache Parameter Group** (`aws_elasticache_parameter_group.main`):
   - **Family**: redis7 (Redis 7.x compatible)
   - **Purpose**: Custom Redis configuration parameters (currently uses defaults)
   - **Extensibility**: Can be extended with custom parameters if needed

4. **ElastiCache Replication Group** (`aws_elasticache_replication_group.main`):
   - **Cluster Mode**: Enabled (supports horizontal scaling via sharding)
   - **Node Type**: Configurable (default: cache.t3.micro)
   - **Node Count**: Configurable (default: 2 = 1 primary + 1 replica)
   - **Port**: 6379 (standard Redis port)
   - **Automatic Failover**: Enabled if num_cache_nodes > 1
   - **Multi-AZ**: Enabled if num_cache_nodes > 1
   - **Encryption at Rest**: Enabled (AES-256)
   - **Encryption in Transit**: Enabled (TLS)
   - **Auth Token**: Retrieved from Secrets Manager (if provided)

**Cluster Mode Enabled Explanation**:
- **What it is**: Redis Cluster Mode allows horizontal scaling by sharding data across multiple nodes
- **Benefits**: Can scale beyond single node limits, supports high availability
- **Current Configuration**: Single shard (1 primary + 1 replica) but can scale to multiple shards
- **Future Scalability**: Can add more shards by increasing `num_cache_nodes` to 4, 6, etc.

**Replication Strategy**:
- **Primary Node**: Handles all read/write operations
- **Replica Node**: Maintains copy of primary data, automatically promoted if primary fails
- **Failover Time**: Typically < 1 minute with automatic failover enabled
- **Data Durability**: Asynchronous replication (small window for data loss)

**Encryption Configuration**:
- **In-Transit**: TLS encryption for all Redis communications
- **At-Rest**: AES-256 encryption for data stored on disk
- **Key Management**: Uses AWS managed keys (KMS)

**Authentication**:
- **Auth Token**: Required for all Redis connections
- **Storage**: Token stored in AWS Secrets Manager (not hard-coded)
- **Retrieval**: Retrieved at Terraform apply time via data source
- **Injection**: Passed to Redis cluster configuration

**Module Interface**:

**Inputs** (`modules/cache/variables.tf`):
- `cluster_id`: Redis cluster identifier (required)
- `node_type`: Redis node instance type (default: "cache.t3.micro")
- `num_cache_nodes`: Number of cache nodes (default: 2)
- `subnet_group_name`: ElastiCache subnet group name (required)
- `subnet_ids`: List of subnet IDs for subnet group (required)
- `auth_token_secret_name`: Secrets Manager secret name (optional)
- `tags`: Additional tags (optional)

**Outputs** (`modules/cache/outputs.tf`):
- `redis_endpoint`: Redis cluster endpoint (host:port format)
- `redis_port`: Redis port (6379)
- `redis_cluster_id`: ElastiCache cluster ID
- `redis_security_group_id`: Redis security group ID (used for security group rules)
- `redis_primary_endpoint`: Primary endpoint address (for direct connections)

---

### Networking Module (`modules/networking/`)

**Purpose**: Provides public entry point for player connections with load balancing and optional global routing optimization.

**Responsibilities**:
- Application Load Balancer creation and configuration
- Target group management for ECS task registration
- Listener configuration for traffic forwarding
- Security group management for ALB
- Integration point for Global Accelerator (configured at root level)

**Resources Created**:

1. **ALB Security Group** (`aws_security_group.alb`):
   - **Ingress**: TCP 25565 (Minecraft port) from 0.0.0.0/0 (internet)
   - **Egress**: All traffic allowed (for forwarding to targets)
   - **Purpose**: Controls access to load balancer

2. **Application Load Balancer** (`aws_lb.main`):
   - **Type**: Application Load Balancer (Layer 7)
   - **Scheme**: Internet-facing (public)
   - **Subnets**: Public subnets (spans multiple AZs)
   - **Security Groups**: ALB security group
   - **Deletion Protection**: Configurable via variable (default: false for terraform destroy)

3. **Target Group** (`aws_lb_target_group.main`):
   - **Protocol**: TCP (Minecraft uses TCP)
   - **Port**: 25565 (Minecraft default port, configurable)
   - **Target Type**: IP (required for Fargate tasks)
   - **Health Check**:
     - Protocol: TCP
     - Port: 25565
     - Interval: 30 seconds
     - Timeout: 5 seconds
     - Healthy threshold: 2 consecutive successes
     - Unhealthy threshold: 2 consecutive failures
   - **Purpose**: Registers ECS task IPs, performs health checks, routes traffic

4. **ALB Listener** (`aws_lb_listener.main`):
   - **Protocol**: TCP
   - **Port**: 25565
   - **Default Action**: Forward to target group
   - **Purpose**: Receives traffic on port 25565 and forwards to healthy targets

**Health Check Strategy**:
- **Protocol**: TCP (simple connectivity check)
- **Frequency**: Every 30 seconds
- **Failure Detection**: 2 consecutive failures mark target unhealthy
- **Recovery**: 2 consecutive successes mark target healthy
- **Purpose**: Ensures only healthy Minecraft servers receive traffic

**Integration with Global Accelerator**:
- Global Accelerator configured at root module level (not in networking module)
- ALB ARN passed to Global Accelerator endpoint group
- Global Accelerator provides static IP addresses and optimal routing
- Players connect to Global Accelerator IP, which routes to ALB

**Module Interface**:

**Inputs** (`modules/networking/variables.tf`):
- `vpc_id`: VPC ID (required)
- `subnet_ids`: List of public subnet IDs (required)
- `target_group_port`: Port for target group (default: 25565)
- `enable_deletion_protection`: Enable ALB deletion protection (default: false)
- `tags`: Additional tags (optional)

**Outputs** (`modules/networking/outputs.tf`):
- `alb_arn`: ALB ARN (used by Global Accelerator endpoint group)
- `alb_dns_name`: ALB DNS name (fallback endpoint if Global Accelerator disabled)
- `target_group_arn`: Target group ARN (used by ECS service)
- `alb_security_group_id`: ALB security group ID (used for security group rules)
- `listener_arn`: ALB listener ARN (for reference)

---

### ECS Module (`modules/ecs/`)

**Purpose**: Manages the containerized Minecraft server lifecycle using ECS Fargate.

**Responsibilities**:
- ECS cluster creation and configuration
- Task definition creation with container configuration
- ECS service management for desired count and deployments
- IAM role management (execution and task roles)
- Security group management for ECS tasks
- CloudWatch logging configuration
- EFS volume integration
- Secrets injection from Secrets Manager
- Session Manager (ECS Exec) configuration

**Resources Created**:

1. **CloudWatch Log Group** (`aws_cloudwatch_log_group.main`):
   - **Name**: `/ecs/minecraft-server`
   - **Retention**: 7 days (configurable)
   - **Purpose**: Centralized logging for container stdout/stderr

2. **ECS Cluster** (`aws_ecs_cluster.main`):
   - **Name**: Configurable via variable
   - **Container Insights**: Enabled (provides detailed metrics)
   - **Capacity Providers**: Fargate (automatic, no EC2 instances)

3. **ECS Task Execution Role** (`aws_iam_role.ecs_execution`):
   - **Purpose**: Used by ECS agent to pull images, write logs, mount EFS, retrieve secrets
   - **Policies Attached**:
     - `AmazonECSTaskExecutionRolePolicy` (AWS managed)
     - Custom policy for EFS access (`efs:ClientMount`, `efs:ClientWrite`, `efs:ClientRootAccess`)
     - Custom policy for Secrets Manager (`secretsmanager:GetSecretValue`)
     - Custom policy for SSM Session Manager (for ECS Exec)

4. **ECS Task Role** (`aws_iam_role.ecs_task`):
   - **Purpose**: Used by the containerized application (Minecraft server)
   - **Policies Attached**:
     - Custom policy for SSM Session Manager (for ECS Exec access)

5. **ECS Task Security Group** (`aws_security_group.ecs_task`):
   - **Ingress**: TCP 25565 from ALB security group (added via security_group_rule in root)
   - **Egress**: TCP 6379 to Redis security group, all other traffic to 0.0.0.0/0
   - **Purpose**: Controls network access to/from containers

6. **ECS Task Definition** (`aws_ecs_task_definition.main`):
   - **Family**: Service name (used for versioning)
   - **Network Mode**: `awsvpc` (required for Fargate)
   - **Launch Type**: Fargate
   - **CPU**: Configurable (default: 2048 = 2 vCPU)
   - **Memory**: Configurable (default: 4096 = 4GB)
   - **Execution Role**: Task execution role ARN
   - **Task Role**: Task role ARN
   - **Container Definition**: Generated from template file
   - **Volumes**: EFS volume mounted at `/data`

7. **ECS Service** (`aws_ecs_service.main`):
   - **Name**: Configurable via variable
   - **Cluster**: ECS cluster ID
   - **Task Definition**: Task definition ARN
   - **Desired Count**: Configurable (default: 1)
   - **Launch Type**: Fargate
   - **Network Configuration**:
     - Subnets: Private subnets
     - Security Groups: ECS task security group
     - Assign Public IP: false (containers in private subnets)
   - **Load Balancer**: Target group ARN, container name, container port
   - **Deployment Configuration**:
     - Maximum Percent: 200 (allows double capacity during deployments)
     - Minimum Healthy Percent: 100 (maintains full capacity during deployments)
   - **Deployment Circuit Breaker**: Enabled with automatic rollback
   - **ECS Exec**: Enabled (for Session Manager access)

**Task Definition Structure**:

The task definition is generated from `task-definition.json.tpl` template:

- **Container Name**: `minecraft-server`
- **Image**: Configurable via variable
- **Essential**: true (service fails if container stops)
- **Port Mappings**: Container port 25565 → Host port 25565
- **Mount Points**: EFS volume mounted at `/data`
- **Environment Variables**:
  - `EULA`: "TRUE" (accepts Minecraft EULA)
  - `REDIS_HOST`: Redis endpoint hostname
  - `REDIS_PORT`: Redis port (6379)
- **Secrets**: `REDIS_AUTH` retrieved from Secrets Manager
- **Log Configuration**: CloudWatch Logs driver, log group `/ecs/minecraft-server`

**Zero-Downtime Deployment Strategy**:
- **Rolling Update**: New tasks started before old tasks stopped
- **Maximum Percent**: 200% allows 2x desired count during deployment
- **Minimum Healthy Percent**: 100% ensures full capacity maintained
- **Circuit Breaker**: Automatically rolls back if new tasks fail health checks
- **Health Check Grace Period**: Configured in target group (not in service)

**EFS Volume Mounting**:
- **Volume Name**: `efs-storage`
- **Mount Point**: `/data` in container
- **Transit Encryption**: Enabled (TLS for data in-flight)
- **IAM Authorization**: Enabled (uses IAM for access control)
- **Access Point**: Not used (direct file system access)

**Secrets Injection**:
- **Method**: `secrets` block in container definition
- **Source**: AWS Secrets Manager
- **Secret Name**: `REDIS_AUTH`
- **Secret ARN**: Retrieved from Secrets Manager data source
- **Security**: Secret value never appears in task definition JSON, retrieved at runtime

**Session Manager Configuration**:
- **ECS Exec**: Enabled in service (`enable_execute_command = true`)
- **IAM Permissions**: Both execution and task roles have SSM permissions
- **Access Method**: `aws ecs execute-command` (see Accessing Containers section)
- **Security**: No SSH ports required, IAM-based access control, audit logging

**Module Interface**:

**Inputs** (`modules/ecs/variables.tf`):
- `cluster_name`: ECS cluster name (required)
- `service_name`: ECS service name (required)
- `container_image`: Docker image URI (required)
- `task_cpu`: CPU units (default: 2048)
- `task_memory`: Memory MB (default: 4096)
- `desired_count`: Desired task count (default: 1)
- `subnet_ids`: Private subnet IDs (required)
- `efs_file_system_id`: EFS file system ID (required)
- `efs_security_group_id`: EFS security group ID (required)
- `target_group_arn`: ALB target group ARN (required)
- `alb_security_group_id`: ALB security group ID (required)
- `redis_endpoint`: Redis endpoint (required)
- `redis_port`: Redis port (default: 6379)
- `redis_security_group_id`: Redis security group ID (required)
- `redis_auth_token_secret_name`: Secrets Manager secret name (optional)
- `tags`: Additional tags (optional)

**Outputs** (`modules/ecs/outputs.tf`):
- `ecs_cluster_id`: ECS cluster ID/ARN
- `ecs_service_id`: ECS service ID
- `ecs_task_security_group_id`: ECS task security group ID (used for security group rules)
- `ecs_task_definition_arn`: Task definition ARN

---

### Route 53 DNS Module (`modules/route53-dns/`)

**Purpose**: Creates Route 53 DNS records for Minecraft server endpoints, enabling players to connect using friendly domain names instead of IP addresses or AWS DNS names.

**Responsibilities**:
- Route 53 DNS record creation (alias, A, or AAAA records)
- Automatic hosted zone lookup for existing domains
- Alias record auto-configuration for AWS resources (ALB, Global Accelerator, CloudFront)
- Domain name normalization and validation
- Error handling for missing or ambiguous hosted zones

**Resources Created**:

1. **Route 53 DNS Record** (`aws_route53_record.main`):
   - **Record Type**: Alias (for AWS resources), A (for IPv4), or AAAA (for IPv6)
   - **Record Name**: Subdomain + domain (e.g., `mc.example.com`) or apex domain (e.g., `example.com`)
   - **Target**: ALB DNS name, Global Accelerator DNS name, CloudFront DNS name, or IP address
   - **TTL**: Configurable for A/AAAA records (default: 300 seconds), not applicable for alias records

**Hosted Zone Lookup**:

- **Automatic Lookup**: When `hosted_zone_id` is not provided, module automatically looks up public hosted zones for the domain
- **Single Zone**: If exactly one public zone exists, uses it automatically
- **Multiple Zones**: If multiple public zones exist, errors with clear message requiring explicit `hosted_zone_id`
- **No Zone**: If no public zones exist, errors with clear message

**Alias Record Auto-Configuration**:

The module automatically configures alias record attributes based on `target_endpoint` pattern:

- **ALB Endpoints** (`.elb.amazonaws.com`):
  - `evaluate_target_health = true`
  - Zone ID: Looked up by region using `data.aws_lb_hosted_zone_id`
- **Global Accelerator Endpoints** (`.awsglobalaccelerator.com`):
  - `evaluate_target_health = false`
  - Zone ID: `Z2BJ6XQ5FK7U4H` (Global Accelerator constant)
- **CloudFront Endpoints** (`.cloudfront.net`):
  - `evaluate_target_health = false`
  - Zone ID: `Z2FDTNDATAQYW2` (CloudFront constant)

Override variables (`evaluate_target_health_override`, `zone_id_override`) allow advanced customization.

**Domain Normalization**:

- **Trailing Dots**: Automatically removed (Route 53 stores domains without trailing dots)
- **Case**: Automatically lowercased for consistency
- **Subdomain Handling**: Null or empty subdomain creates apex domain record

**Validation**:

- **Domain Name**: RFC 1123 compliant, 1-253 characters, cannot start/end with hyphen or dot
- **Subdomain**: RFC 1123 compliant, 1-63 characters per label
- **Record Type**: Must be exactly one of: `"alias"`, `"A"`, or `"AAAA"`
- **Target Endpoint**: Format must match record_type (DNS name for alias, IPv4 for A, IPv6 for AAAA)
- **TTL**: Must be between 60 and 2147483647 seconds (Route 53 limits)

**Use Cases**:

- **Subdomain**: Create `mc.example.com` pointing to ALB or Global Accelerator
- **Apex Domain**: Create `example.com` pointing to Minecraft server endpoint
- **IPv4 Address**: Create A record pointing to static IPv4 address
- **IPv6 Address**: Create AAAA record pointing to IPv6 address

**Module Interface**:

**Inputs** (`modules/route53-dns/variables.tf`):
- `domain_name`: Root domain name (required, e.g., "example.com")
- `subdomain`: Subdomain prefix (optional, null for apex domain)
- `record_type`: Record type - "alias", "A", or "AAAA" (required)
- `target_endpoint`: Endpoint to point to - DNS name or IP (required)
- `hosted_zone_id`: Explicit hosted zone ID (optional, bypasses lookup)
- `ttl`: TTL in seconds for A/AAAA records (default: 300)
- `evaluate_target_health_override`: Override for alias evaluate_target_health (optional)
- `zone_id_override`: Override for alias zone_id (optional)

**Outputs** (`modules/route53-dns/outputs.tf`):
- `fqdn`: Fully-qualified domain name (e.g., `mc.example.com` or `example.com`)
- `record_name`: Route 53 record name (may include trailing dot)

**Integration Example**:

```hcl
module "minecraft_dns" {
  source = "./modules/route53-dns"

  domain_name     = "example.com"
  subdomain       = "mc"
  record_type     = "alias"
  target_endpoint = var.enable_global_accelerator ? aws_globalaccelerator_accelerator.main[0].dns_name : module.networking.alb_dns_name

  tags = var.tags
}

# Output FQDN for player connections
output "minecraft_server_hostname" {
  description = "Minecraft server hostname for player connections"
  value       = module.minecraft_dns.fqdn
}
```

**Error Handling**:

- **No Hosted Zone**: Clear error message with instructions to create zone or provide explicit `hosted_zone_id`
- **Multiple Hosted Zones**: Error requiring explicit `hosted_zone_id` to disambiguate
- **Format Mismatch**: Validation error when `target_endpoint` format doesn't match `record_type`
- **Missing Zone ID**: Error when alias record cannot determine zone_id (requires recognized AWS resource or override)

---

### Root Module (`terraform/main.tf`)

**Purpose**: Orchestrates all modules and manages cross-module dependencies and integrations.

**Responsibilities**:
- Provider configuration with default tags
- Module instantiation in correct order
- Dependency management via `depends_on`
- Global Accelerator configuration
- Security group rule cross-references
- Data source queries (availability zones, region)

**Module Orchestration**:

1. **VPC Module** (created first):
   - All other modules depend on VPC
   - Provides network foundation

2. **Storage, Cache, Networking Modules** (created in parallel after VPC):
   - Can be created simultaneously (no dependencies on each other)
   - All depend only on VPC

3. **ECS Module** (created last):
   - Depends on VPC, Storage, Cache, and Networking
   - Requires outputs from all other modules

**Dependency Management**:

Explicit `depends_on` clauses ensure correct creation order:
- Storage depends on VPC
- Cache depends on VPC
- Networking depends on VPC
- ECS depends on VPC, Storage, Cache, Networking

**Global Accelerator Configuration**:

Configured at root level (not in networking module) because:
- Global Accelerator is optional (controlled by variable)
- Simplifies networking module (focuses on ALB)
- Easier to manage conditional creation

**Security Group Cross-References**:

Security group rules are created at root level to avoid circular dependencies:
- EFS security group rule: Allows NFS from ECS tasks
- Redis security group rule: Allows Redis from ECS tasks
- ECS security group rules: Allows Minecraft port from ALB, egress to Redis

**Default Tags Configuration**:

Provider-level `default_tags` ensure all resources are tagged:
- `Project`: "minecraft-server"
- `Environment`: Variable value (default: "production")
- `ManagedBy`: "terraform"
- Additional tags: Merged from `tags` variable

**Data Sources**:

- `aws_availability_zones`: Queries available AZs in region
- Used to determine subnet placement
- Ensures only available AZs are used

## Data Flow and Network Architecture

### Player Connection Flow

```
Player (Internet)
  │
  │ DNS Query: mc.example.com
  ▼
Route 53 DNS (if DNS module used)
  │ Resolves hostname to ALB DNS or Global Accelerator DNS
  │ Alias record (no TTL, always current)
  ▼
Global Accelerator (if enabled)
  │ Static IP addresses, optimal routing via AWS backbone
  │ Routes to nearest healthy endpoint
  ▼
Application Load Balancer (Public Subnet)
  │ Health checks, traffic distribution
  │ TCP listener on port 25565
  ▼
Target Group
  │ Registers ECS task IPs
  │ Routes to healthy targets only
  ▼
ECS Fargate Task (Private Subnet)
  │ Container: minecraft-server
  │ Port: 25565
  │ Network: awsvpc mode
  ▼
Minecraft Server Process
```

**Key Points**:
- Route 53 DNS provides friendly hostnames (optional, e.g., `mc.example.com`)
- DNS alias records point to ALB or Global Accelerator (no TTL, always current)
- Global Accelerator provides stable IP addresses and optimal routing
- ALB performs health checks and distributes traffic
- ECS tasks receive traffic on private IPs (no public IPs)
- All traffic flows through security groups at each layer

### Container Storage Access Flow

```
ECS Fargate Task
  │
  │ NFS Protocol (TCP 2049)
  │ Transit Encryption: Enabled
  │ IAM Authorization: Enabled
  ▼
EFS Mount Target (Private Subnet, same AZ)
  │ Network interface in same subnet as task
  │ Low latency for local AZ access
  ▼
EFS File System
  │ Encrypted at rest (AES-256)
  │ Shared across all containers
  │ Automatic scaling
  ▼
/data directory in container
  │ World files, mods, plugins, configs
```

**Key Points**:
- EFS mount targets placed in same AZs as ECS tasks for low latency
- Transit encryption ensures data security in-flight
- IAM authorization provides access control
- Shared storage allows multiple containers to access same data

### Cache Access Flow

```
ECS Fargate Task
  │
  │ Redis Protocol (TCP 6379)
  │ TLS Encryption: Enabled
  │ Auth Token: From Secrets Manager
  ▼
Redis Security Group
  │ Allows TCP 6379 from ECS task security group only
  ▼
ElastiCache Redis Cluster (Private Subnet)
  │ Cluster Mode Enabled
  │ Primary + Replica nodes
  │ Encryption at rest and in transit
  ▼
Redis Data Store
  │ Cached state, session data
```

**Key Points**:
- Redis only accessible from ECS tasks (not from internet)
- TLS encryption for all Redis communications
- Auth token required for all connections
- High availability via replication

### Administrative Access Flow

```
DevOps Engineer
  │
  │ AWS CLI / Console
  │ IAM Authentication
  ▼
AWS Systems Manager Session Manager
  │ IAM-based access control
  │ Audit logging enabled
  │ No open ports required
  ▼
ECS Exec Service
  │ enable_execute_command = true
  │ SSM agent in container
  ▼
ECS Fargate Task Container
  │ /bin/sh or custom command
  │ Full container access
```

**Key Points**:
- No SSH ports required (improves security)
- IAM-based access control (who can access)
- All sessions logged for audit
- Works with Fargate containers via SSM agent

### Outbound Internet Flow

```
ECS Fargate Task (Private Subnet)
  │
  │ Outbound traffic (container image pulls, updates, API calls)
  │ No public IP assigned
  ▼
Private Route Table
  │ Routes 0.0.0.0/0 → NAT Gateway
  ▼
NAT Gateway (Public Subnet)
  │ Elastic IP address
  │ One per Availability Zone
  ▼
Internet Gateway
  │ Attached to VPC
  ▼
Internet
```

**Key Points**:
- Containers have no public IPs (improves security)
- All outbound traffic routed via NAT Gateway
- NAT Gateway provides stable outbound IP
- One NAT Gateway per AZ for high availability

### Network Isolation Boundaries

**Public Subnet Isolation**:
- Resources: NAT Gateway, ALB
- Internet Access: Direct via Internet Gateway
- Inbound Access: Controlled by security groups
- Purpose: Edge services that need internet connectivity

**Private Subnet Isolation**:
- Resources: ECS tasks, Redis, EFS mount targets
- Internet Access: Outbound only via NAT Gateway
- Inbound Access: None from internet (only from ALB or internal)
- Purpose: Application workloads that should not be directly accessible

**Security Group Isolation**:
- ALB: Allows TCP 25565 from internet
- ECS Tasks: Allows TCP 25565 from ALB only
- Redis: Allows TCP 6379 from ECS tasks only
- EFS: Allows NFS from ECS tasks only

### Security Group Interaction Diagram

```
Internet (0.0.0.0/0)
  │
  │ TCP 25565
  ▼
[ALB Security Group]
  │ Allows: TCP 25565 from 0.0.0.0/0
  │
  │ TCP 25565
  ▼
[ECS Task Security Group]
  │ Allows: TCP 25565 from ALB security group
  │ Egress: TCP 6379 to Redis security group
  │ Egress: All to 0.0.0.0/0 (via NAT Gateway)
  │
  ├─ TCP 6379 ──────────────────┐
  │                              │
  │ NFS 2049                     │
  ▼                              ▼
[EFS Security Group]    [Redis Security Group]
  │ Allows: NFS from ECS        │ Allows: TCP 6379 from ECS
  │ Egress: All                 │ Egress: None
```

## Module Organization

### Module Design Principles

1. **Single Responsibility**: Each module has one clear purpose
   - VPC: Network infrastructure
   - Storage: Persistent storage
   - Cache: Caching layer
   - Networking: Traffic distribution
   - ECS: Container orchestration
   - Route 53 DNS: DNS record management

2. **Encapsulation**: Modules hide implementation details
   - Callers only need to provide inputs and consume outputs
   - Internal resource configuration is abstracted away

3. **Reusability**: Modules can be reused in other projects
   - Well-defined interfaces (variables and outputs)
   - No hard-coded values
   - Configurable via variables

4. **Composability**: Modules can be combined to build complex infrastructure
   - Clear dependency relationships
   - Outputs from one module feed inputs to another

5. **Testability**: Modules can be tested independently
   - Each module is self-contained
   - Can be instantiated in isolation for testing

### Module Responsibilities and Boundaries

**VPC Module**:
- **Owns**: VPC, subnets, gateways, route tables
- **Provides**: Network foundation for all other modules
- **Does Not Own**: Security groups for application resources (those belong to respective modules)

**Storage Module**:
- **Owns**: EFS file system, mount targets, EFS security group
- **Provides**: Persistent storage capability
- **Does Not Own**: ECS task security group (needed for EFS security group rule)

**Cache Module**:
- **Owns**: ElastiCache Redis cluster, subnet group, parameter group, Redis security group
- **Provides**: Caching and state management
- **Does Not Own**: ECS task security group (needed for Redis security group rule)

**Networking Module**:
- **Owns**: ALB, target group, listener, ALB security group
- **Provides**: Public entry point and load balancing
- **Does Not Own**: Global Accelerator (configured at root level for flexibility)

**ECS Module**:
- **Owns**: ECS cluster, task definition, service, IAM roles, ECS task security group, CloudWatch log group
- **Provides**: Container orchestration and execution
- **Does Not Own**: ALB or target group (receives ARN as input)

**Route 53 DNS Module**:
- **Owns**: Route 53 DNS record
- **Provides**: DNS record management for friendly hostnames
- **Does Not Own**: Hosted zone (assumes existing zone or requires explicit zone ID)

### Module Dependencies and Execution Order

**Dependency Graph**:

```
VPC Module
  │
  ├─→ Storage Module
  ├─→ Cache Module
  ├─→ Networking Module
  │
  ├─→ ECS Module
  │     │
  │     ├─→ Depends on Storage Module (EFS ID, security group)
  │     ├─→ Depends on Cache Module (Redis endpoint, security group)
  │     └─→ Depends on Networking Module (Target group ARN, ALB security group)
  │
  └─→ Route 53 DNS Module (optional)
        │
        └─→ Depends on Networking Module (ALB DNS name) or Global Accelerator (DNS name)
```

**Execution Order** (Terraform automatically handles this via dependencies):

1. **VPC Module**: Created first (foundation)
2. **Storage, Cache, Networking Modules**: Created in parallel (independent)
3. **ECS Module**: Created after Storage, Cache, and Networking (requires their outputs)
4. **Route 53 DNS Module**: Created after Networking or Global Accelerator (optional, requires endpoint DNS name)
5. **Security Group Rules**: Created at root level after all modules (cross-references)

### Module Interface (Inputs/Outputs)

Each module follows a consistent interface pattern:

**Inputs** (`modules/*/variables.tf`):
- Required variables: No defaults, must be provided
- Optional variables: Sensible defaults provided
- Type validation: Terraform validates types automatically
- Custom validation: Some variables have validation blocks (e.g., task_cpu must be valid Fargate value)

**Outputs** (`modules/*/outputs.tf`):
- Resource IDs: For reference and integration
- Endpoints: For connection information
- Security Group IDs: For cross-module security group rules
- ARNs: For IAM policies and integrations

**Example - VPC Module Interface**:

```hcl
# Inputs
module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr            = "10.0.0.0/16"           # Required
  availability_zones  = ["sa-east-1a", "sa-east-1b"]  # Required
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]  # Required
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]  # Required
  tags                = {}                     # Optional
}

# Outputs (used by other modules)
module.vpc.vpc_id
module.vpc.public_subnet_ids
module.vpc.private_subnet_ids
```

### Module Reusability

**Why Modular Design**:

1. **Separation of Concerns**: Each module focuses on one aspect of infrastructure
2. **Maintainability**: Changes to one module don't affect others
3. **Testability**: Modules can be tested independently
4. **Reusability**: Modules can be used in other projects
5. **Clarity**: Clear boundaries make the codebase easier to understand

**Reusability Examples**:

- **VPC Module**: Can be reused for any AWS project needing VPC with public/private subnets
- **Storage Module**: Can be reused for any project needing EFS storage
- **Cache Module**: Can be reused for any project needing Redis caching
- **Networking Module**: Can be reused for any project needing ALB
- **ECS Module**: Can be adapted for other containerized applications
- **Route 53 DNS Module**: Can be reused for any project needing DNS records for AWS resources or IP addresses

**Adaptation for Other Projects**:

To adapt this infrastructure for another game server or application:
1. Modify ECS module task definition template (container configuration)
2. Update networking module target group port (if different)
3. Adjust security group ports as needed
4. Keep VPC, Storage, Cache modules largely unchanged

## Variables

### Variable Categories

**Required Variables** (must be provided):
- `container_image`: Docker image URI for Minecraft server

**Optional Variables with Defaults**:
- `aws_region`: AWS region (default: "sa-east-1")
- `vpc_cidr`: VPC CIDR block (default: "10.0.0.0/16")
- `environment`: Environment name (default: "production")
- `desired_count`: ECS task count (default: 1)
- `task_cpu`: CPU units (default: 2048 = 2 vCPU)
- `task_memory`: Memory MB (default: 4096 = 4GB)
- `redis_node_type`: Redis instance type (default: "cache.t3.micro")
- `redis_replica_count`: Redis replicas (default: 1)
- `efs_performance_mode`: EFS performance mode (default: "generalPurpose")
- `enable_global_accelerator`: Enable Global Accelerator (default: true)
- `minecraft_server_port`: Minecraft port (default: 25565)
- `enable_deletion_protection`: ALB deletion protection (default: false)
- `tags`: Additional tags (default: {})

**Computed Variables** (derived from other variables or data sources):
- Availability zones: Queried from AWS via data source
- Subnet CIDRs: Calculated from VPC CIDR using `cidrsubnet()`

### Variable Validation Rules Explained

**task_cpu Validation**:
```hcl
validation {
  condition     = contains([256, 512, 1024, 2048, 4096], var.task_cpu)
  error_message = "Task CPU must be one of: 256, 512, 1024, 2048, 4096."
}
```
- **Why**: Fargate only supports specific CPU values
- **Values**: 256 (0.25 vCPU), 512 (0.5 vCPU), 1024 (1 vCPU), 2048 (2 vCPU), 4096 (4 vCPU)
- **Impact**: Invalid values cause Terraform plan/apply to fail with clear error

**task_memory Validation**:
```hcl
validation {
  condition     = var.task_memory >= 512 && var.task_memory <= 30720
  error_message = "Task memory must be between 512 and 30720 MB."
}
```
- **Why**: Fargate memory limits (512 MB minimum, 30 GB maximum)
- **Additional Constraint**: Memory must be compatible with CPU (see AWS Fargate documentation)
- **Impact**: Prevents invalid configurations

**desired_count Validation**:
```hcl
validation {
  condition     = var.desired_count > 0 && var.desired_count <= 100
  error_message = "Desired count must be between 1 and 100."
}
```
- **Why**: Prevents invalid scaling configurations
- **Lower Bound**: At least 1 task required for service to run
- **Upper Bound**: 100 tasks maximum (can be increased if needed)

**efs_performance_mode Validation**:
```hcl
validation {
  condition     = contains(["generalPurpose", "maxIO"], var.efs_performance_mode)
  error_message = "EFS performance mode must be 'generalPurpose' or 'maxIO'."
}
```
- **Why**: EFS only supports these two performance modes
- **generalPurpose**: Recommended for most workloads (small files, metadata)
- **maxIO**: For high-throughput workloads (not typically needed for Minecraft)

### Default Values Rationale

**aws_region = "sa-east-1"**:
- São Paulo, Brazil region
- Optimal latency for players in Brazil/South America
- Can be changed for other regions

**vpc_cidr = "10.0.0.0/16"**:
- Standard private IP range
- Provides 65,536 IP addresses (more than enough)
- Can be changed if conflicts with existing networks

**task_cpu = 2048 (2 vCPU)**:
- Balanced cost/performance
- Suitable for 20-50 concurrent players
- Can be scaled up/down as needed

**task_memory = 4096 (4GB)**:
- Sufficient for Minecraft server + JVM overhead
- Matches 2 vCPU configuration
- Can be increased for larger player counts

**redis_node_type = "cache.t3.micro"**:
- Cost-effective for initial deployment
- Suitable for caching/state management
- Can be upgraded to larger instances if needed

**enable_global_accelerator = true**:
- Provides optimal latency for South America
- Can be disabled to reduce costs (~$7/month)

### Configuration Examples for Different Scenarios

**Small Server (10-20 players)**:
```hcl
desired_count   = 1
task_cpu        = 1024      # 1 vCPU
task_memory     = 2048      # 2GB
redis_node_type = "cache.t3.micro"
```

**Medium Server (20-50 players)**:
```hcl
desired_count   = 1
task_cpu        = 2048      # 2 vCPU (default)
task_memory     = 4096      # 4GB (default)
redis_node_type = "cache.t3.micro"
```

**Large Server (50-100+ players)**:
```hcl
desired_count   = 2         # Multiple containers
task_cpu        = 4096      # 4 vCPU per container
task_memory     = 8192      # 8GB per container
redis_node_type = "cache.t3.small"
```

**Development/Testing Environment**:
```hcl
environment     = "development"
desired_count   = 1
task_cpu        = 1024      # Lower cost
task_memory     = 2048      # Lower cost
enable_global_accelerator = false  # Save costs
enable_deletion_protection = false  # Allow easy cleanup
```

**Production Environment**:
```hcl
environment     = "production"
desired_count   = 2         # High availability
task_cpu        = 2048
task_memory     = 4096
enable_global_accelerator = true   # Optimal latency
enable_deletion_protection = true  # Prevent accidental deletion
redis_replica_count = 1    # High availability
```

### Environment-Specific Configurations

**Development**:
- Lower resource allocation (cost savings)
- Global Accelerator disabled (cost savings)
- Deletion protection disabled (easy cleanup)
- Single AZ acceptable (cost savings)

**Staging**:
- Similar to production but smaller scale
- Global Accelerator optional
- Deletion protection optional
- Multi-AZ for testing HA

**Production**:
- Full resource allocation
- Global Accelerator enabled (optimal latency)
- Deletion protection enabled (safety)
- Multi-AZ required (high availability)
- Redis replication enabled (high availability)

### Secrets Management Workflow

**Step 1: Create Secret in Secrets Manager**:
```bash
aws secretsmanager create-secret \
  --name minecraft/redis/auth-token \
  --secret-string "$(openssl rand -base64 32)" \
  --region sa-east-1
```

**Step 2: Reference in Terraform**:
```hcl
redis_auth_token_secret_name = "minecraft/redis/auth-token"
```

**Step 3: Terraform Retrieves Secret**:
- Data source queries Secrets Manager at apply time
- Secret value retrieved and passed to Redis cluster configuration
- Secret value never appears in Terraform state or logs

**Step 4: ECS Task Retrieves Secret**:
- Task definition references secret ARN
- ECS agent retrieves secret at task start time
- Secret injected as environment variable in container
- Secret value never appears in task definition JSON

**Security Benefits**:
- No hard-coded secrets in code
- Secrets encrypted at rest in Secrets Manager
- Access controlled via IAM
- Audit trail of secret access
- Can rotate secrets without code changes

### Backend Configuration (S3/DynamoDB)

**Purpose**: Remote state storage for team collaboration and state locking.

**Configuration** (`backend.tf.example`):
```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "minecraft/infrastructure.tfstate"
    region         = "sa-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

**S3 Bucket**:
- Stores Terraform state file
- Versioning enabled (for state history)
- Encryption enabled (for security)
- Access controlled via IAM

**DynamoDB Table**:
- Provides state locking
- Prevents concurrent terraform apply operations
- Pay-per-request billing (cost-effective)

**Setup Steps**:
1. Create S3 bucket with versioning
2. Create DynamoDB table for locking
3. Copy `backend.tf.example` to `backend.tf`
4. Update bucket name and region
5. Run `terraform init` (will migrate state to S3)

## Configuration Deep Dive

### Variable Reference

See `terraform.tfvars.example` for all available variables. Key variables:

**Required**:
- `container_image` (required): Docker image for Minecraft server
  - Example: `"itzg/minecraft-server:latest"`
  - Example: `"123456789012.dkr.ecr.sa-east-1.amazonaws.com/minecraft:1.20.1"`

**Optional - Infrastructure**:
- `aws_region` (default: sa-east-1): AWS region for deployment
- `vpc_cidr` (default: 10.0.0.0/16): VPC CIDR block
- `environment` (default: production): Environment name (used for resource naming)

**Optional - Compute**:
- `desired_count` (default: 1): Number of ECS tasks
- `task_cpu` (default: 2048): CPU units (2 vCPU)
- `task_memory` (default: 4096): Memory in MB (4GB)

**Optional - Storage**:
- `efs_performance_mode` (default: generalPurpose): EFS performance mode

**Optional - Cache**:
- `redis_node_type` (default: cache.t3.micro): ElastiCache Redis node type
- `redis_replica_count` (default: 1): Number of Redis replica nodes
- `redis_auth_token_secret_name` (default: null): Secrets Manager secret name

**Optional - Networking**:
- `minecraft_server_port` (default: 25565): Minecraft server port
- `enable_global_accelerator` (default: true): Enable Global Accelerator
- `enable_deletion_protection` (default: false): Enable ALB deletion protection

**Optional - Tags**:
- `tags` (default: {}): Additional tags to apply to all resources

### Complete Variable List

See `terraform/variables.tf` for complete variable definitions with types, defaults, descriptions, and validation rules.

## Outputs

**Connection Information**:
- `minecraft_endpoint`: Public endpoint for players to connect (Global Accelerator IP or ALB DNS)
- `global_accelerator_dns_name`: Global Accelerator DNS name (if enabled)
- `minecraft_server_hostname`: Route 53 DNS hostname (if DNS module is used, e.g., `mc.example.com`)
- `redis_endpoint`: ElastiCache Redis cluster endpoint
- `efs_dns_name`: EFS DNS name for mounting

**Resource IDs**:
- `vpc_id`: VPC ID
- `ecs_cluster_id`: ECS cluster ID/ARN
- `ecs_service_id`: ECS service ID
- `alb_arn`: Application Load Balancer ARN
- `redis_cluster_id`: ElastiCache Redis cluster ID
- `efs_id`: EFS file system ID

**Network Information**:
- `public_subnet_ids`: List of public subnet IDs
- `private_subnet_ids`: List of private subnet IDs
- `security_group_ids`: Map of security group IDs by name (alb, ecs, redis, efs)

**Usage Examples**:
```bash
# Get Minecraft server endpoint
terraform output -raw minecraft_endpoint

# Get all outputs
terraform output

# Get specific output
terraform output vpc_id

# Use in scripts
ENDPOINT=$(terraform output -raw minecraft_endpoint)
echo "Connect to: $ENDPOINT:25565"
```

## Scaling

### Horizontal Scaling (Adding More Containers)

To scale the infrastructure horizontally (add more container instances):

1. Edit `terraform.tfvars`:
   ```hcl
   desired_count = 3  # Increase number of containers
   ```

2. Apply changes:
   ```bash
   terraform apply
   ```

**How It Works**:
- ECS service creates additional tasks
- Tasks are distributed across Availability Zones automatically
- ALB target group registers all task IPs
- Traffic distributed across all healthy tasks
- Zero-downtime scaling (new tasks started before old ones stopped if reducing)

**Considerations**:
- EFS is shared storage (all containers access same world data)
- Redis is shared cache (all containers use same cache)
- More containers = more cost (linear scaling)
- ALB automatically distributes traffic

### Vertical Scaling (Increasing Container Resources)

To scale vertically (increase CPU/memory per container):

1. Edit `terraform.tfvars`:
   ```hcl
   task_cpu = 4096    # Increase CPU (4 vCPU)
   task_memory = 8192 # Increase memory (8GB)
   ```

2. Apply changes:
   ```bash
   terraform apply
   ```

**How It Works**:
- ECS creates new task definition with updated CPU/memory
- ECS service performs rolling update
- Old tasks stopped, new tasks started with new resources
- Zero-downtime deployment (maintains desired count during update)

**Considerations**:
- Fargate CPU/memory combinations must be valid (see AWS documentation)
- Higher resources = higher cost (per task)
- May require container image optimization for larger memory

### Storage Scaling

EFS automatically scales storage capacity:
- No manual provisioning required
- Scales from GB to PB automatically
- Pay only for storage used
- Performance scales with size (larger = more baseline throughput)

**Monitoring Storage**:
```bash
# Check EFS size via AWS CLI
aws efs describe-file-systems --file-system-id $(terraform output -raw efs_id)
```

### Redis Scaling

**Horizontal Scaling (Adding Shards)**:
- Increase `num_cache_nodes` to 4, 6, 8, etc. (must be even for Cluster Mode)
- Each pair = 1 shard (1 primary + 1 replica)
- More shards = more capacity and throughput

**Vertical Scaling (Larger Node Type)**:
- Change `redis_node_type` to larger instance (e.g., cache.t3.small, cache.t3.medium)
- More CPU/memory per node = better performance
- Requires cluster recreation (downtime)

## Updating Container Image

1. Edit `terraform.tfvars`:
   ```hcl
   container_image = "itzg/minecraft-server:1.20.1"
   ```

2. Apply changes:
   ```bash
   terraform apply
   ```

**How ECS Rolling Update Works**:
- ECS creates new task definition with updated image
- ECS service starts new tasks with new image
- New tasks must pass health checks before old tasks stopped
- Maximum 200% capacity during deployment (allows 2x desired count)
- Minimum 100% healthy capacity maintained
- Circuit breaker rolls back if new tasks fail

**Zero-Downtime Guarantee**:
- Old tasks remain running until new tasks healthy
- ALB routes traffic to healthy tasks only
- No player disconnections during update
- Automatic rollback if update fails

## Accessing Containers

Use AWS Systems Manager Session Manager (no SSH ports required):

```bash
# Get cluster name from outputs
CLUSTER_NAME=$(terraform output -raw ecs_cluster_id | cut -d'/' -f2)

# Get task ID
TASK_ID=$(aws ecs list-tasks \
  --cluster $CLUSTER_NAME \
  --region sa-east-1 \
  --query 'taskArns[0]' \
  --output text | cut -d'/' -f3)

# Start session
aws ecs execute-command \
  --cluster $CLUSTER_NAME \
  --task $TASK_ID \
  --container minecraft-server \
  --command "/bin/sh" \
  --interactive \
  --region sa-east-1
```

**Prerequisites**:
- AWS CLI configured with appropriate credentials
- IAM user/role must have `ssm:StartSession` permission
- ECS Exec must be enabled (configured in ECS service)

**What You Can Do**:
- Execute shell commands in container
- View container filesystem
- Check logs, processes, network connections
- Debug issues, modify configurations (if mounted from EFS)

**Security**:
- No SSH ports required (improves security)
- IAM-based access control
- All sessions logged to CloudTrail
- Can restrict access to specific IAM users/roles

## Cleanup

**⚠️ WARNING**: Running `terraform destroy` will delete ALL resources including persistent storage (world data, mods, plugins, configurations). Make sure to backup important data before destroying.

### Backup Before Destruction

To preserve world data, backup EFS before destroying:
```bash
# Get EFS ID from outputs
EFS_ID=$(terraform output -raw efs_id)

# Create backup
aws efs create-backup --file-system-id $EFS_ID --region sa-east-1
```

### Destroy Infrastructure

```bash
terraform destroy
```

### Verify Cleanup

After destruction completes, verify no orphaned resources remain:

1. **Check AWS Console**:
   - VPC: No VPCs with name "minecraft-vpc"
   - ECS: No clusters with name "minecraft-cluster-*"
   - EFS: No file systems with name "minecraft-efs"
   - ElastiCache: No clusters with name "minecraft-redis-*"
   - ALB: No load balancers with name "minecraft-alb"
   - NAT Gateway: No NAT gateways in the VPC

2. **Check Billing**:
   - AWS Cost Explorer should show no charges for destroyed resources
   - Verify no ongoing charges for NAT Gateways, ALB, or Global Accelerator

### Cleanup Order

Terraform automatically handles destruction order:
1. ECS Service (stops tasks)
2. ECS Cluster
3. ALB and Global Accelerator
4. ElastiCache Redis
5. EFS (mount targets, then file system)
6. NAT Gateways
7. VPC (subnets, route tables, gateways)

## Cost Estimation

Approximate monthly costs for default configuration (sa-east-1):

- NAT Gateway: ~$32/month (per AZ, ~$0.045/hour × 730 hours)
- Application Load Balancer: ~$16/month (~$0.0225/hour × 730 hours)
- Global Accelerator: ~$7/month (fixed fee + data transfer)
- ECS Fargate (2 vCPU, 4GB): ~$60/month (1 task, 730 hours)
- EFS (General Purpose): ~$3/month (10GB, $0.30/GB-month)
- ElastiCache Redis (cache.t3.micro): ~$15/month (~$0.020/hour × 730 hours)

**Total**: ~$133/month (varies with usage)

**Cost Optimization Tips**:
- Disable Global Accelerator for development (~$7/month savings)
- Use smaller instance types for development
- Stop ECS tasks when not in use (Fargate charges only when running)
- Use EFS Infrequent Access storage class for old world backups (50% cost reduction)

## Monitoring and Observability

### CloudWatch Logs

**Log Group**: `/ecs/minecraft-server`

**Access Logs**:
```bash
# Tail logs in real-time
aws logs tail /ecs/minecraft-server --follow --region sa-east-1

# View recent logs
aws logs tail /ecs/minecraft-server --since 1h --region sa-east-1

# Search logs
aws logs filter-log-events \
  --log-group-name /ecs/minecraft-server \
  --filter-pattern "ERROR" \
  --region sa-east-1
```

**Log Retention**: 7 days (configurable in ECS module)

### CloudWatch Metrics

**ECS Service Metrics**:
- `CPUUtilization`: Container CPU usage
- `MemoryUtilization`: Container memory usage
- `RunningTaskCount`: Number of running tasks
- `DesiredTaskCount`: Desired number of tasks

**ALB Metrics**:
- `RequestCount`: Number of requests
- `TargetResponseTime`: Response time from targets
- `HealthyHostCount`: Number of healthy targets
- `UnHealthyHostCount`: Number of unhealthy targets

**EFS Metrics**:
- `StorageBytes`: Total storage used
- `DataReadIOBytes`: Data read from file system
- `DataWriteIOBytes`: Data written to file system

**ElastiCache Metrics**:
- `CPUUtilization`: Redis CPU usage
- `NetworkBytesIn`: Network bytes received
- `NetworkBytesOut`: Network bytes sent
- `CacheHits`: Cache hit count
- `CacheMisses`: Cache miss count

**Access Metrics**:
```bash
# Get ECS service metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=minecraft-server-production \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --region sa-east-1
```

### Container Insights

ECS Container Insights enabled in cluster configuration provides:
- Detailed container-level metrics
- Performance data for troubleshooting
- Resource utilization trends
- Available in CloudWatch Container Insights dashboard

### Health Checks

**ALB Target Group Health Checks**:
- Protocol: TCP
- Port: 25565
- Interval: 30 seconds
- Timeout: 5 seconds
- Healthy threshold: 2 consecutive successes
- Unhealthy threshold: 2 consecutive failures

**Monitoring Health**:
```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --region sa-east-1
```

## Troubleshooting

### NAT Gateway Creation Fails

**Error**: `InsufficientAddressesInSubnet`

**Solution**: Ensure public subnet has available IP addresses. Use smaller CIDR blocks or create additional subnets.

**Prevention**: Use /24 subnets (256 IPs) which provides plenty of addresses for NAT Gateway and ALB.

### ElastiCache Creation Takes Too Long

**Solution**: Normal - ElastiCache can take 10-15 minutes. Wait for completion or check AWS Console.

**Why**: ElastiCache performs extensive setup including encryption, replication, and multi-AZ configuration.

**Monitoring**:
```bash
# Check ElastiCache status
aws elasticache describe-replication-groups \
  --replication-group-id minecraft-redis-production \
  --region sa-east-1
```

### ECS Task Fails to Start

**Solution**:
1. Check CloudWatch Logs: `aws logs tail /ecs/minecraft-server --follow`
2. Verify container image exists and is accessible
3. Check EFS mount: Ensure EFS security group allows NFS from ECS security group
4. Verify task has sufficient CPU/memory
5. Check IAM roles have required permissions

**Common Issues**:
- **Image pull failure**: Container image doesn't exist or ECR permissions missing
- **EFS mount failure**: Security group rule missing or IAM permissions insufficient
- **Secrets retrieval failure**: Secrets Manager permissions missing or secret doesn't exist
- **Insufficient resources**: Task CPU/memory too low for container requirements

### Cannot Connect to Minecraft Server

**Solution**:
1. Verify ALB security group allows inbound TCP 25565 from 0.0.0.0/0
2. Check ECS task is running: `aws ecs describe-tasks --cluster <cluster> --tasks <task-id>`
3. Verify target group health: Check ALB target group in AWS Console
4. Check Global Accelerator status (if enabled)
5. Verify security group rules are applied correctly

**Debugging Steps**:
```bash
# Check ECS service status
aws ecs describe-services \
  --cluster minecraft-cluster-production \
  --services minecraft-server-production \
  --region sa-east-1

# Check running tasks
aws ecs list-tasks \
  --cluster minecraft-cluster-production \
  --region sa-east-1

# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --region sa-east-1
```

### EFS Mount Issues

**Symptoms**: Container cannot access `/data` directory, permission denied errors

**Solution**:
1. Verify EFS security group allows NFS (2049) from ECS task security group
2. Check EFS mount target is in same subnet as ECS task
3. Verify IAM role has EFS permissions (`efs:ClientMount`, `efs:ClientWrite`)
4. Check EFS file system exists and is accessible

### Redis Connection Issues

**Symptoms**: Container cannot connect to Redis, authentication errors

**Solution**:
1. Verify Redis security group allows TCP 6379 from ECS task security group
2. Check Redis auth token secret exists in Secrets Manager
3. Verify IAM role has Secrets Manager permissions
4. Check Redis cluster is in "available" state
5. Verify Redis endpoint is correct in container environment variables

### Terraform State Issues

**Symptoms**: Terraform plan shows unexpected changes, state out of sync

**Solution**:
1. Refresh state: `terraform refresh`
2. Verify no manual changes made in AWS Console
3. Check for state file corruption
4. Use remote state backend (S3) for team collaboration
5. Enable state locking (DynamoDB) to prevent concurrent modifications

### High Latency Issues

**Symptoms**: Players experience high latency despite Global Accelerator

**Solution**:
1. Verify Global Accelerator is enabled and active
2. Check player location (Global Accelerator optimizes for AWS edge locations)
3. Verify ALB health checks are passing (unhealthy targets increase latency)
4. Check ECS task CPU/memory utilization (resource constraints cause lag)
5. Monitor CloudWatch metrics for bottlenecks

## Security

### Secrets Management

**No Hard-Coded Secrets**:
- All secrets stored in AWS Secrets Manager
- Redis auth token retrieved at runtime
- ECS task definition uses `secrets` block for secure injection
- No passwords, API keys, or tokens in Terraform code or state

**Secret Lifecycle**:
1. Create secret in Secrets Manager (manual or automated)
2. Reference secret name in Terraform variable
3. Terraform retrieves secret ARN (not value) at apply time
4. ECS agent retrieves secret value at task start time
5. Secret injected as environment variable in container
6. Secret value never appears in logs, state, or task definition JSON

**Secret Rotation**:
- Can rotate secrets in Secrets Manager without Terraform changes
- New tasks automatically use new secret value
- Old tasks continue using old value until replaced
- No downtime required for secret rotation

### Security Groups

**ALB Security Group**:
- **Ingress**: TCP 25565 from 0.0.0.0/0 (internet)
  - Allows players to connect from anywhere
  - Port 25565 is Minecraft standard port
- **Egress**: All traffic (for forwarding to targets)

**ECS Task Security Group**:
- **Ingress**: TCP 25565 from ALB security group only
  - Containers not directly accessible from internet
  - Only ALB can reach containers
- **Egress**: 
  - TCP 6379 to Redis security group (for cache access)
  - All traffic to 0.0.0.0/0 (for internet access via NAT Gateway)

**Redis Security Group**:
- **Ingress**: TCP 6379 from ECS task security group only
  - Redis not accessible from internet
  - Only ECS tasks can access Redis
- **Egress**: None (Redis doesn't initiate connections)

**EFS Security Group**:
- **Ingress**: NFS (2049) from ECS task security group only
  - EFS not accessible from internet
  - Only ECS tasks can mount EFS
- **Egress**: All (required for NFS protocol)

**Security Group Rule Management**:
- Rules created at root module level to avoid circular dependencies
- Uses `aws_security_group_rule` resources for cross-module references
- All rules have descriptions for clarity

### Network Isolation

**Private Subnet Isolation**:
- Containers have no public IPs (cannot be directly accessed from internet)
- Outbound internet access only via NAT Gateway
- Inbound access only from ALB (via security groups)
- Internal services (Redis, EFS) accessible only from ECS tasks

**Public Subnet Isolation**:
- Only edge services (ALB, NAT Gateway) in public subnets
- ALB is only public-facing component
- NAT Gateway provides outbound connectivity only

**VPC Isolation**:
- All resources within single VPC
- No peering or VPN connections (can be added if needed)
- Complete network isolation from other VPCs

### Encryption

**Encryption at Rest**:
- EFS: AES-256 encryption enabled
- ElastiCache Redis: AES-256 encryption enabled
- ECS task definitions: Stored encrypted in ECS service
- Secrets Manager: AES-256 encryption (AWS managed keys)

**Encryption in Transit**:
- EFS: Transit encryption enabled (TLS)
- ElastiCache Redis: Transit encryption enabled (TLS)
- ALB to ECS: TCP (Minecraft protocol doesn't support TLS, but traffic stays within AWS network)
- Global Accelerator: All traffic encrypted via AWS backbone

### Administrative Access

**Systems Manager Session Manager**:
- No SSH ports required (improves security posture)
- IAM-based access control (who can access)
- All sessions logged to CloudTrail (audit trail)
- Works with Fargate containers via SSM agent

**Access Control**:
- IAM users/roles must have `ssm:StartSession` permission
- ECS Exec must be enabled (configured in service)
- Can restrict access to specific IAM principals
- Can require MFA for sensitive operations

### Threat Model

**Protected Against**:
- **DDoS Attacks**: ALB provides DDoS protection, Global Accelerator adds additional layer
- **Unauthorized Access**: Security groups restrict access to necessary ports only
- **Data Exfiltration**: Private subnets prevent direct internet access from containers
- **Credential Theft**: No hard-coded secrets, all from Secrets Manager
- **Network Scanning**: Security groups block unauthorized port access
- **Man-in-the-Middle**: Encryption in-transit for all sensitive communications

**Security Best Practices Followed**:
- Defense in depth (multiple security layers)
- Least privilege (minimum necessary access)
- Encryption everywhere (at rest and in transit)
- Audit logging (CloudTrail, Session Manager logs)
- No hard-coded secrets
- Network isolation
- Regular security updates (via container image updates)

## Contribution Guidelines

### Code Organization Principles

1. **Modular Design**: Each module is self-contained with clear responsibilities
2. **DRY (Don't Repeat Yourself)**: Shared logic extracted to reusable modules
3. **Clear Naming**: Resources, variables, and outputs use descriptive names
4. **Documentation**: All modules include README with usage examples
5. **Consistency**: Follow Terraform style guide and AWS naming conventions

### Module Development Guidelines

**When Creating a New Module**:

1. **Define Interface First**:
   - List all required inputs (variables)
   - List all outputs needed by other modules
   - Document purpose and responsibilities

2. **Follow Module Structure**:
   ```
   modules/new-module/
   ├── main.tf          # Resource definitions
   ├── variables.tf     # Input variables
   ├── outputs.tf       # Output values
   └── README.md        # Documentation
   ```

3. **Resource Naming**:
   - Use descriptive names: `minecraft-{component}-{identifier}`
   - Include environment in names when appropriate
   - Use consistent naming patterns across modules

4. **Tagging**:
   - All resources must support tags variable
   - Merge module-specific tags with provided tags
   - Use default_tags at provider level for consistency

5. **Outputs**:
   - Export all resource IDs needed by other modules
   - Export connection information (endpoints, DNS names)
   - Export security group IDs for cross-module rules

### Testing Approach

**Manual Testing**:
1. Run `terraform init` to initialize
2. Run `terraform validate` to check syntax
3. Run `terraform plan` to review changes
4. Run `terraform apply` in test environment
5. Verify resources created correctly
6. Test functionality (connect to server, verify storage, etc.)
7. Run `terraform destroy` to verify clean teardown

**Integration Testing** (Future):
- Use Terratest or kitchen-terraform for automated testing
- Test module in isolation
- Test module integration
- Test error scenarios

### Documentation Standards

**Module README Requirements**:
- Purpose and responsibilities
- Usage example with all variables
- Inputs table (name, description, type, default, required)
- Outputs table (name, description)
- Resources created list
- Notes section with important details

**Code Comments**:
- Comment complex logic or non-obvious decisions
- Explain why, not what (code should be self-documenting)
- Use HCL comments (`#` for single line, `/* */` for multi-line)

**Variable Descriptions**:
- All variables must have descriptions
- Include units where applicable (MB, GB, etc.)
- Explain validation rules if present
- Provide examples for complex variables

### Pull Request Process

1. **Create Feature Branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make Changes**:
   - Follow code style guidelines
   - Update documentation
   - Test changes locally

3. **Commit Changes**:
   ```bash
   git add .
   git commit -m "Description of changes"
   ```

4. **Push and Create PR**:
   - Push branch to remote
   - Create pull request with description
   - Link to related issues if applicable

5. **Code Review**:
   - Address review comments
   - Ensure all checks pass
   - Update documentation if needed

6. **Merge**:
   - Squash and merge preferred
   - Delete feature branch after merge

### Code Review Checklist

**Functionality**:
- [ ] Changes work as intended
- [ ] No breaking changes (or documented if intentional)
- [ ] Backward compatibility maintained

**Code Quality**:
- [ ] Follows Terraform best practices
- [ ] No hard-coded values
- [ ] Proper error handling
- [ ] Resource dependencies correct

**Documentation**:
- [ ] README updated if needed
- [ ] Variables documented
- [ ] Outputs documented
- [ ] Examples updated if needed

**Security**:
- [ ] No secrets in code
- [ ] Security groups follow least privilege
- [ ] Encryption enabled where applicable
- [ ] IAM permissions minimal

**Testing**:
- [ ] Tested in development environment
- [ ] terraform validate passes
- [ ] terraform plan shows expected changes
- [ ] No unexpected resource changes

### Terraform Best Practices Followed

1. **State Management**: Use remote state (S3) for team collaboration
2. **State Locking**: Use DynamoDB for state locking
3. **Modularity**: Code organized into reusable modules
4. **Variables**: All configurable values exposed as variables
5. **Outputs**: Important values exposed as outputs
6. **Tags**: Consistent tagging strategy across all resources
7. **Validation**: Variable validation prevents invalid configurations
8. **Documentation**: Comprehensive documentation for all components
9. **Versioning**: Provider versions constrained for stability
10. **Idempotency**: Terraform operations are idempotent (safe to run multiple times)

## Development Workflow

### Local Development Setup

1. **Clone Repository**:
   ```bash
   git clone <repository-url>
   cd minecraft/terraform
   ```

2. **Configure AWS Credentials**:
   ```bash
   aws configure
   # Or use environment variables
   export AWS_ACCESS_KEY_ID="your-key"
   export AWS_SECRET_ACCESS_KEY="your-secret"
   ```

3. **Create Development Variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars.dev
   # Edit with development values (lower costs, single AZ acceptable)
   ```

4. **Initialize Terraform**:
   ```bash
   terraform init
   ```

5. **Plan Changes**:
   ```bash
   terraform plan -var-file=terraform.tfvars.dev
   ```

### Testing Infrastructure Changes

**Before Making Changes**:
1. Backup current state (if using remote state, it's versioned in S3)
2. Create feature branch
3. Make changes incrementally

**Testing Process**:
1. **Validate Syntax**:
   ```bash
   terraform validate
   ```

2. **Format Code**:
   ```bash
   terraform fmt -recursive
   ```

3. **Review Plan**:
   ```bash
   terraform plan -var-file=terraform.tfvars.dev
   ```

4. **Apply in Development**:
   ```bash
   terraform apply -var-file=terraform.tfvars.dev
   ```

5. **Verify Functionality**:
   - Connect to Minecraft server
   - Verify storage persistence
   - Check logs
   - Test scaling

6. **Destroy Test Environment**:
   ```bash
   terraform destroy -var-file=terraform.tfvars.dev
   ```

### Module Development Workflow

**Creating a New Module**:

1. **Create Module Directory**:
   ```bash
   mkdir -p modules/new-module
   ```

2. **Create Module Files**:
   - `main.tf`: Resource definitions
   - `variables.tf`: Input variables
   - `outputs.tf`: Output values
   - `README.md`: Documentation

3. **Develop Module**:
   - Start with variables (define interface)
   - Implement resources in main.tf
   - Define outputs
   - Write documentation

4. **Test Module in Isolation**:
   ```bash
   cd modules/new-module
   # Create test main.tf that calls module
   terraform init
   terraform plan
   ```

5. **Integrate into Root Module**:
   - Add module block to root main.tf
   - Pass required variables
   - Use module outputs
   - Update root outputs if needed

### Debugging Tips

**Terraform Debugging**:
```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform plan

# Check specific resource
terraform state show module.ecs.aws_ecs_service.main

# List all resources
terraform state list

# Refresh state (sync with AWS)
terraform refresh
```

**AWS Resource Debugging**:
```bash
# Check ECS task status
aws ecs describe-tasks \
  --cluster <cluster-name> \
  --tasks <task-id> \
  --region sa-east-1

# Check CloudWatch Logs
aws logs tail /ecs/minecraft-server --follow

# Check security group rules
aws ec2 describe-security-groups \
  --group-ids <security-group-id> \
  --region sa-east-1
```

**Common Issues**:
- **State out of sync**: Run `terraform refresh`
- **Dependency issues**: Check `depends_on` clauses
- **Permission errors**: Verify IAM permissions
- **Resource conflicts**: Check for naming conflicts

### Common Development Tasks

**Adding a New Variable**:
1. Add variable to `terraform/variables.tf`
2. Add to `terraform.tfvars.example`
3. Pass to appropriate module(s)
4. Update module variables if needed
5. Update documentation

**Modifying a Module**:
1. Make changes in module directory
2. Test module in isolation if possible
3. Update module README if interface changes
4. Test integration in root module
5. Update root module if needed

**Adding a New Output**:
1. Add output to module `outputs.tf`
2. Add output to root `outputs.tf`
3. Update documentation
4. Test output value

**Updating Resource Configuration**:
1. Modify resource in appropriate module
2. Run `terraform plan` to see changes
3. Review changes carefully
4. Apply in development first
5. Test functionality

### State Management Best Practices

**Remote State**:
- Always use S3 backend for production
- Enable versioning on S3 bucket
- Use DynamoDB for state locking
- Never commit state files to git

**State File Security**:
- Encrypt state file in S3
- Restrict S3 bucket access via IAM
- Use least privilege for state access
- Rotate access keys regularly

**State File Organization**:
- Use different state files for different environments
- Use state file prefixes for organization
- Example: `minecraft/production.tfstate`, `minecraft/development.tfstate`

**State Operations**:
```bash
# List resources in state
terraform state list

# Show specific resource
terraform state show <resource-address>

# Move resource (rename)
terraform state mv <old-address> <new-address>

# Remove resource from state (doesn't delete in AWS)
terraform state rm <resource-address>

# Import existing resource
terraform import <resource-address> <aws-resource-id>
```

## Documentation

- [Quick Start Guide](../specs/001-aws-minecraft-infrastructure/quickstart.md)
- [Data Model](../specs/001-aws-minecraft-infrastructure/data-model.md)
- [Variable Schema](../specs/001-aws-minecraft-infrastructure/contracts/variables-schema.md)
- [Research & Decisions](../specs/001-aws-minecraft-infrastructure/research.md)
- [Implementation Plan](../specs/001-aws-minecraft-infrastructure/plan.md)

## License

See repository LICENSE file.
