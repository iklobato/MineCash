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

### Root Module (`main.tf`)

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

See `variables.tf` for complete variable definitions with types, defaults, descriptions, and validation rules.

## Minecraft Server Configuration

This section documents all possible Minecraft server configuration parameters. The infrastructure uses the `itzg/minecraft-server` Docker image, which supports extensive configuration via environment variables and the `server.properties` file.

### Introduction

The Minecraft server can be configured in two ways:

1. **Environment Variables**: Passed via ECS task definition, automatically applied by the container image
2. **Direct File Editing**: Edit `server.properties` file stored in EFS at `/data/server.properties` (persists across container restarts)

**Configuration File Location**: `/data/server.properties` (mounted from EFS, accessible from all containers)

**Important**: Changes to `server.properties` require a server restart to take effect. Environment variables are applied when the container starts.

### Currently Configured Parameters

The following parameters are currently set in the ECS task definition (see `modules/ecs/task-definition.json.tpl`):

**Required Configuration**:
- `EULA=TRUE`: Accepts Minecraft End User License Agreement (required for server to start)

**Infrastructure Integration**:
- `REDIS_HOST`: Redis cluster endpoint hostname (from infrastructure)
- `REDIS_PORT`: Redis port (default: 6379, from infrastructure)
- `REDIS_AUTH`: Redis authentication token (from AWS Secrets Manager)

### Environment Variables Reference

The `itzg/minecraft-server` Docker image supports many environment variables for server configuration. These override `server.properties` settings when provided.

#### Server Type & Version

| Variable | Description | Example Values | Default |
|----------|-------------|----------------|---------|
| `TYPE` | Server type/implementation | `VANILLA`, `SPIGOT`, `PAPER`, `FORGE`, `FABRIC`, `QUILT` | `VANILLA` |
| `VERSION` | Minecraft version | `LATEST`, `1.20.1`, `1.19.4`, `1.18.2` | `LATEST` |
| `PAPERBUILD` | Paper build number (if TYPE=PAPER) | `latest`, `1234` | `latest` |
| `FORGEVERSION` | Forge version (if TYPE=FORGE) | `latest`, `43.2.0` | `latest` |

**Example**:
```hcl
# Use Paper server for better performance
environment = [
  { name = "TYPE", value = "PAPER" },
  { name = "VERSION", value = "1.20.1" }
]
```

#### Server Properties (Override server.properties)

| Variable | Description | Example Values | Default |
|----------|-------------|----------------|---------|
| `MOTD` | Message of the Day (displayed in server list) | `"Welcome to My Server!"` | `"A Minecraft Server"` |
| `SERVER_NAME` | Server name | `"My Minecraft Server"` | `"Minecraft Server"` |
| `MAX_PLAYERS` | Maximum number of players | `20`, `50`, `100` | `20` |
| `VIEW_DISTANCE` | View distance in chunks | `8`, `10`, `12`, `16` | `10` |
| `SIMULATION_DISTANCE` | Simulation distance in chunks | `8`, `10`, `12` | `10` |
| `DIFFICULTY` | Difficulty level | `peaceful`, `easy`, `normal`, `hard` | `easy` |
| `GAMEMODE` | Default gamemode | `survival`, `creative`, `adventure`, `spectator` | `survival` |
| `FORCE_GAMEMODE` | Force gamemode on join | `true`, `false` | `false` |
| `PVP` | Enable player vs player | `true`, `false` | `true` |
| `ONLINE_MODE` | Verify players with Mojang | `true`, `false` | `true` |
| `WHITELIST` | Enable whitelist | `true`, `false` | `false` |
| `ENABLE_COMMAND_BLOCK` | Enable command blocks | `true`, `false` | `false` |
| `MAX_WORLD_SIZE` | Maximum world size | `29999984` | `29999984` |
| `ALLOW_NETHER` | Allow Nether dimension | `true`, `false` | `true` |
| `GENERATE_STRUCTURES` | Generate structures | `true`, `false` | `true` |
| `GENERATOR_SETTINGS` | Generator settings (JSON) | `"{}"` | `""` |
| `LEVEL_SEED` | World seed | `"1234567890"`, `""` (random) | `""` |
| `LEVEL_TYPE` | World type | `DEFAULT`, `FLAT`, `LARGEBIOMES`, `AMPLIFIED`, `CUSTOMIZED` | `DEFAULT` |
| `LEVEL_NAME` | World name/directory | `"world"`, `"myworld"` | `"world"` |
| `MAX_TICK_TIME` | Maximum tick time (ms) | `60000` | `60000` |
| `MAX_BUILD_HEIGHT` | Maximum build height | `320` | `320` |
| `SPAWN_MONSTERS` | Spawn monsters | `true`, `false` | `true` |
| `SPAWN_ANIMALS` | Spawn animals | `true`, `false` | `true` |
| `SPAWN_NPCS` | Spawn NPCs | `true`, `false` | `true` |
| `ALLOW_FLIGHT` | Allow flight | `true`, `false` | `false` |
| `ENABLE_RCON` | Enable RCON (remote console) | `true`, `false` | `false` |
| `RCON_PASSWORD` | RCON password | `"mypassword"` | `""` |
| `RCON_PORT` | RCON port | `25575` | `25575` |
| `ENABLE_QUERY` | Enable query protocol | `true`, `false` | `false` |
| `QUERY_PORT` | Query port | `25565` | `25565` |
| `SERVER_PORT` | Server port | `25565` | `25565` |
| `RESOURCE_PACK` | Resource pack URL | `"https://example.com/pack.zip"` | `""` |
| `RESOURCE_PACK_PROMPT` | Resource pack prompt | `"Install resource pack?"` | `""` |
| `RESOURCE_PACK_SHA1` | Resource pack SHA1 hash | `"abc123..."` | `""` |

#### Performance & Resource Management

| Variable | Description | Example Values | Default |
|----------|-------------|----------------|---------|
| `MEMORY` | JVM memory allocation | `"2G"`, `"4096M"`, `"8G"` | `"1G"` |
| `JVM_OPTS` | Additional JVM options | `"-XX:+UseG1GC"` | `""` |
| `JVM_XX_OPTS` | Additional JVM XX options | `"-XX:MaxGCPauseMillis=200"` | `""` |
| `USE_AIKAR_FLAGS` | Use Aikar's optimized JVM flags | `true`, `false` | `false` |

**Memory Configuration**:
- `MEMORY` sets JVM heap size (e.g., `"4G"` = 4GB heap)
- ECS `task_memory` must be larger than `MEMORY` (leave ~512MB-1GB for OS and JVM overhead)
- Recommended: `MEMORY = (task_memory - 1024)M` (leave 1GB headroom)

**Example**:
```hcl
# For task_memory = 4096 (4GB), use MEMORY = "3G"
environment = [
  { name = "MEMORY", value = "3G" },
  { name = "USE_AIKAR_FLAGS", value = "true" }
]
```

#### World & Data Management

| Variable | Description | Example Values | Default |
|----------|-------------|----------------|---------|
| `WORLD` | World name/directory | `"world"`, `"myworld"` | `"world"` |
| `OVERRIDE_WORLD` | Override world on restart | `true`, `false` | `false` |
| `OVERRIDE_ICON` | Override server icon | `true`, `false` | `false` |
| `WORLD_BACKUP` | Enable world backups | `true`, `false` | `false` |
| `BACKUP_INTERVAL` | Backup interval (minutes) | `60`, `120`, `240` | `0` (disabled) |
| `BACKUP_RETENTION` | Number of backups to retain | `5`, `10`, `20` | `0` |

#### Plugins & Mods

| Variable | Description | Example Values | Default |
|----------|-------------|----------------|---------|
| `PLUGINS` | Comma-separated plugin URLs | `"https://example.com/plugin.jar"` | `""` |
| `MODS` | Comma-separated mod URLs | `"https://example.com/mod.jar"` | `""` |
| `REMOVE_OLD_MODS` | Remove old mods on update | `true`, `false` | `false` |
| `REMOVE_OLD_MODS_DEPTH` | Depth to search for old mods | `1`, `2` | `1` |

#### Backup & Maintenance

| Variable | Description | Example Values | Default |
|----------|-------------|----------------|---------|
| `ENABLE_AUTOPAUSE` | Pause server when no players | `true`, `false` | `false` |
| `AUTOPAUSE_TIMEOUT_EST` | Estimated autopause timeout (seconds) | `180` | `180` |
| `AUTOPAUSE_TIMEOUT_KN` | Known autopause timeout (seconds) | `120` | `120` |
| `AUTOPAUSE_TIMEOUT_INIT` | Initial autopause timeout (seconds) | `600` | `600` |

#### Advanced Configuration

| Variable | Description | Example Values | Default |
|----------|-------------|----------------|---------|
| `OVERRIDE_SERVER_PROPERTIES` | Override server.properties completely | `true`, `false` | `false` |
| `ENABLE_ROLLING_LOGS` | Enable rolling logs | `true`, `false` | `false` |
| `LOG_TIMESTAMP` | Add timestamps to logs | `true`, `false` | `false` |
| `REPLACE_ENV_VARIABLES` | Replace env vars in files | `true`, `false` | `false` |
| `REPLACE_ENV_VARIABLES_PREFIX` | Prefix for env var replacement | `"${"` | `"${"` |

### server.properties File Configuration

The `server.properties` file is stored in EFS at `/data/server.properties` and persists across container restarts. You can edit this file directly or use environment variables (which override file settings).

**File Location**: `/data/server.properties` (accessible via EFS mount)

**Key Settings**:

**Server Identification**:
- `server-name`: Server name displayed in server list
- `motd`: Message of the Day shown to players
- `server-port`: Port the server listens on (default: 25565)

**World Settings**:
- `level-name`: World directory name (default: "world")
- `level-seed`: World generation seed (empty = random)
- `level-type`: World type (DEFAULT, FLAT, LARGEBIOMES, AMPLIFIED, CUSTOMIZED)
- `generate-structures`: Generate structures like villages (true/false)
- `generator-settings`: JSON generator settings

**Gameplay Settings**:
- `gamemode`: Default gamemode (survival, creative, adventure, spectator)
- `force-gamemode`: Force gamemode on join (true/false)
- `difficulty`: Difficulty level (peaceful, easy, normal, hard)
- `pvp`: Enable player vs player (true/false)
- `max-players`: Maximum players allowed
- `view-distance`: View distance in chunks (4-32, default: 10)
- `simulation-distance`: Simulation distance in chunks (4-32, default: 10)
- `spawn-monsters`: Spawn monsters (true/false)
- `spawn-animals`: Spawn animals (true/false)
- `spawn-npcs`: Spawn NPCs (true/false)

**Performance Settings**:
- `max-tick-time`: Maximum milliseconds per tick (default: 60000)
- `max-world-size`: Maximum world size (default: 29999984)
- `max-build-height`: Maximum build height (default: 320)
- `network-compression-threshold`: Packet compression threshold (default: 256)

**Network Settings**:
- `online-mode`: Verify players with Mojang (true/false)
- `server-ip`: IP address to bind to (empty = all interfaces)
- `enable-query`: Enable query protocol (true/false)
- `query.port`: Query port (default: 25565)
- `enable-rcon`: Enable RCON (true/false)
- `rcon.port`: RCON port (default: 25575)
- `rcon.password`: RCON password

**Access Control**:
- `white-list`: Enable whitelist (true/false)
- `enforce-whitelist`: Enforce whitelist (true/false)
- `op-permission-level`: OP permission level (1-4, default: 4)
- `function-permission-level`: Function permission level (1-4, default: 2)

**Other Settings**:
- `allow-flight`: Allow flight (true/false)
- `allow-nether`: Allow Nether dimension (true/false)
- `enable-command-block`: Enable command blocks (true/false)
- `resource-pack`: Resource pack URL
- `resource-pack-prompt`: Resource pack prompt message
- `resource-pack-sha1`: Resource pack SHA1 hash
- `spawn-protection`: Spawn protection radius (default: 16)

**Editing server.properties**:

1. **Access Container** (see "Accessing Containers" section):
   ```bash
   aws ecs execute-command \
     --cluster <cluster-name> \
     --task <task-id> \
     --container minecraft-server \
     --command "/bin/sh" \
     --interactive
   ```

2. **Edit File**:
   ```bash
   # View current configuration
   cat /data/server.properties
   
   # Edit with nano or vi
   nano /data/server.properties
   ```

3. **Restart Server**: Changes require server restart to take effect
   - Restart ECS service: `aws ecs update-service --cluster <cluster> --service <service> --force-new-deployment`

### JVM Options Configuration

**Memory Allocation**:

The `MEMORY` environment variable sets JVM heap size. Relationship to ECS task memory:

- **ECS Task Memory**: Total memory allocated to container (includes OS, JVM, and heap)
- **JVM Heap Memory**: Memory available to Minecraft server (set via `MEMORY` variable)
- **Recommended**: Leave 512MB-1GB headroom for OS and JVM overhead

**Example Memory Configuration**:

| ECS task_memory | Recommended MEMORY | Headroom |
|-----------------|-------------------|----------|
| 2048 MB (2GB) | `"1536M"` or `"1.5G"` | 512 MB |
| 4096 MB (4GB) | `"3072M"` or `"3G"` | 1024 MB |
| 8192 MB (8GB) | `"7168M"` or `"7G"` | 1024 MB |

**JVM Flags**:

**Aikar's Flags** (Recommended):
- Set `USE_AIKAR_FLAGS=true` for optimized JVM flags
- Includes G1GC settings, optimized for Minecraft servers
- Automatically configured based on available memory

**Custom JVM Options**:
- `JVM_OPTS`: Additional JVM options (e.g., `"-XX:+UseG1GC"`)
- `JVM_XX_OPTS`: Additional JVM XX options (e.g., `"-XX:MaxGCPauseMillis=200"`)

**Performance Tuning**:

**Garbage Collector**:
- G1GC recommended for Minecraft (enabled by Aikar's flags)
- Tuned automatically when `USE_AIKAR_FLAGS=true`

**Memory Recommendations by Player Count**:

| Players | Recommended Memory | ECS task_memory |
|---------|-------------------|-----------------|
| 10-20 | 2GB | 3072 MB |
| 20-50 | 4GB | 5120 MB |
| 50-100 | 8GB | 9216 MB |
| 100+ | 12GB+ | 13312 MB+ |

### Configuration Methods

#### Method 1: Environment Variables (Terraform)

Add environment variables to the ECS task definition via Terraform:

**Step 1**: Modify task definition template (`modules/ecs/task-definition.json.tpl`):

```json
"environment": [
  {
    "name": "EULA",
    "value": "TRUE"
  },
  {
    "name": "REDIS_HOST",
    "value": "${redis_host}"
  },
  {
    "name": "REDIS_PORT",
    "value": "${redis_port}"
  },
  {
    "name": "MOTD",
    "value": "${motd}"
  },
  {
    "name": "MAX_PLAYERS",
    "value": "${max_players}"
  },
  {
    "name": "MEMORY",
    "value": "${memory}"
  },
  {
    "name": "USE_AIKAR_FLAGS",
    "value": "${use_aikar_flags}"
  }
]
```

**Step 2**: Add variables to ECS module (`modules/ecs/variables.tf`):

```hcl
variable "motd" {
  description = "Message of the Day for Minecraft server"
  type        = string
  default     = "A Minecraft Server"
}

variable "max_players" {
  description = "Maximum number of players"
  type        = number
  default     = 20
}

variable "memory" {
  description = "JVM memory allocation (e.g., '3G', '4096M')"
  type        = string
  default     = null  # Auto-calculated from task_memory
}

variable "use_aikar_flags" {
  description = "Use Aikar's optimized JVM flags"
  type        = bool
  default     = true
}
```

**Step 3**: Pass variables from root module (`main.tf`):

```hcl
module "ecs" {
  source = "./modules/ecs"
  
  # ... existing variables ...
  motd          = var.minecraft_motd
  max_players   = var.minecraft_max_players
  memory        = var.minecraft_memory
  use_aikar_flags = var.minecraft_use_aikar_flags
}
```

**Step 4**: Add root variables (`variables.tf`):

```hcl
variable "minecraft_motd" {
  description = "Minecraft server Message of the Day"
  type        = string
  default     = "A Minecraft Server"
}

variable "minecraft_max_players" {
  description = "Maximum number of players"
  type        = number
  default     = 20
}

variable "minecraft_memory" {
  description = "JVM memory allocation (e.g., '3G'). If null, auto-calculated from task_memory"
  type        = string
  default     = null
}

variable "minecraft_use_aikar_flags" {
  description = "Use Aikar's optimized JVM flags"
  type        = bool
  default     = true
}
```

**Step 5**: Update template file to use variables:

Modify `modules/ecs/main.tf` to calculate memory if not provided:

```hcl
locals {
  # Calculate memory from task_memory if not provided
  jvm_memory = var.memory != null ? var.memory : "${floor((var.task_memory - 1024) / 1024)}G"
}
```

Then update template file to use `jvm_memory` instead of hardcoded value.

#### Method 2: Direct File Editing (EFS)

Edit `server.properties` directly in the mounted EFS volume:

1. **Access Container** (see "Accessing Containers" section)

2. **Edit server.properties**:
   ```bash
   # View current configuration
   cat /data/server.properties
   
   # Edit with nano
   nano /data/server.properties
   
   # Example: Change max players
   # max-players=50
   ```

3. **Restart Server**:
   ```bash
   # Force new deployment to restart server
   aws ecs update-service \
     --cluster <cluster-name> \
     --service <service-name> \
     --force-new-deployment \
     --region sa-east-1
   ```

**Note**: Changes persist across container restarts because `/data` is mounted from EFS.

#### Method 3: Initial Configuration Files

You can provide initial configuration files by mounting them from EFS:

1. **Create Configuration Files Locally**:
   ```bash
   # Create server.properties
   cat > server.properties <<EOF
   max-players=50
   motd=Welcome to My Server!
   difficulty=normal
   gamemode=survival
   view-distance=12
   EOF
   ```

2. **Upload to EFS** (via container access or EFS mount):
   ```bash
   # Access container and copy file
   cp server.properties /data/server.properties
   ```

3. **Restart Server**: Configuration will be used on next start

### Common Configuration Examples

#### Small Server (10-20 players)

```hcl
# terraform.tfvars
task_memory = 3072  # 3GB

# Environment variables (add to task definition)
MOTD = "Small Friendly Server"
MAX_PLAYERS = 20
MEMORY = "2G"
VIEW_DISTANCE = 8
DIFFICULTY = "normal"
USE_AIKAR_FLAGS = "true"
```

**server.properties**:
```properties
max-players=20
view-distance=8
difficulty=normal
gamemode=survival
pvp=true
online-mode=true
```

#### Medium Server (20-50 players)

```hcl
# terraform.tfvars
task_memory = 5120  # 5GB

# Environment variables
MOTD = "Welcome to Our Server!"
MAX_PLAYERS = 50
MEMORY = "4G"
VIEW_DISTANCE = 10
DIFFICULTY = "normal"
USE_AIKAR_FLAGS = "true"
TYPE = "PAPER"  # Use Paper for better performance
VERSION = "1.20.1"
```

**server.properties**:
```properties
max-players=50
view-distance=10
simulation-distance=10
difficulty=normal
gamemode=survival
pvp=true
online-mode=true
spawn-protection=16
```

#### Large Server (50-100+ players)

```hcl
# terraform.tfvars
task_memory = 9216  # 9GB
desired_count = 2   # Multiple containers for load distribution

# Environment variables
MOTD = "High Performance Server"
MAX_PLAYERS = 100
MEMORY = "8G"
VIEW_DISTANCE = 12
SIMULATION_DISTANCE = 10
DIFFICULTY = "normal"
USE_AIKAR_FLAGS = "true"
TYPE = "PAPER"
VERSION = "1.20.1"
ENABLE_AUTOPAUSE = "false"  # Keep server running
```

**server.properties**:
```properties
max-players=100
view-distance=12
simulation-distance=10
difficulty=normal
gamemode=survival
pvp=true
online-mode=true
max-tick-time=60000
network-compression-threshold=256
```

#### Creative Server

```hcl
# Environment variables
GAMEMODE = "creative"
FORCE_GAMEMODE = "true"
ALLOW_FLIGHT = "true"
ENABLE_COMMAND_BLOCK = "true"
DIFFICULTY = "peaceful"
SPAWN_MONSTERS = "false"
```

**server.properties**:
```properties
gamemode=creative
force-gamemode=true
allow-flight=true
enable-command-block=true
difficulty=peaceful
spawn-monsters=false
pvp=false
```

#### Hardcore Server

```hcl
# Environment variables
DIFFICULTY = "hard"
GAMEMODE = "survival"
PVP = "true"
SPAWN_MONSTERS = "true"
```

**server.properties**:
```properties
difficulty=hard
gamemode=survival
pvp=true
spawn-monsters=true
hardcore=true  # Note: May require server type that supports hardcore mode
```

#### Paper Server (Performance Optimized)

```hcl
# Environment variables
TYPE = "PAPER"
VERSION = "1.20.1"
PAPERBUILD = "latest"
MEMORY = "4G"
USE_AIKAR_FLAGS = "true"
VIEW_DISTANCE = 10
SIMULATION_DISTANCE = 8  # Lower simulation distance for performance
```

**server.properties** (Paper-specific optimizations):
```properties
paper:
  chunk-loading:
    autoconfig-send-distance: true
  world-settings:
    default:
      entity-activation-range:
        animals: 16
        monsters: 24
        raiders: 48
        misc: 8
```

### Configuration Best Practices

#### Memory Management

**Relationship Between ECS Memory and JVM Memory**:
- ECS `task_memory`: Total container memory (OS + JVM + heap)
- JVM `MEMORY`: Heap memory for Minecraft server
- **Rule of Thumb**: `MEMORY = (task_memory - 1024)M` (leave 1GB for OS/JVM)

**Example**:
- `task_memory = 4096` (4GB) → `MEMORY = "3G"` (3GB heap, 1GB overhead)
- `task_memory = 8192` (8GB) → `MEMORY = "7G"` (7GB heap, 1GB overhead)

**Memory by Player Count**:
- **10-20 players**: 2GB heap (task_memory: 3GB)
- **20-50 players**: 4GB heap (task_memory: 5GB)
- **50-100 players**: 8GB heap (task_memory: 9GB)
- **100+ players**: 12GB+ heap (task_memory: 13GB+)

#### Performance Optimization

**Use Aikar's Flags**:
- Set `USE_AIKAR_FLAGS=true` for optimized JVM garbage collection
- Automatically configures G1GC with optimal settings
- Recommended for all server sizes

**View Distance**:
- **Small servers (10-20 players)**: 8 chunks
- **Medium servers (20-50 players)**: 10 chunks
- **Large servers (50-100+ players)**: 12 chunks
- **Very large servers**: 14-16 chunks (requires more memory)

**Simulation Distance**:
- Typically same or lower than view distance
- Lower values improve performance (fewer entities active)
- Recommended: 8-10 chunks for most servers

**Use Paper Server**:
- Set `TYPE=PAPER` for better performance than Vanilla
- Includes performance optimizations and additional features
- Recommended for servers with 20+ players

#### Security Considerations

**Online Mode**:
- `ONLINE_MODE=true`: Verify players with Mojang (recommended for public servers)
- `ONLINE_MODE=false`: Allow cracked/offline players (security risk)

**Whitelist**:
- Enable whitelist for private servers: `WHITELIST=true`
- Manage whitelist via `whitelist.json` in `/data/` directory

**RCON**:
- Enable RCON for remote administration: `ENABLE_RCON=true`
- Set strong password: `RCON_PASSWORD=<strong-password>`
- Store password in AWS Secrets Manager (not in Terraform)

#### Backup & Persistence

**World Backups**:
- Enable automatic backups: `WORLD_BACKUP=true`, `BACKUP_INTERVAL=60`
- Backups stored in `/data/backups/` directory (persists in EFS)
- Configure retention: `BACKUP_RETENTION=10` (keep 10 backups)

**EFS Persistence**:
- All data in `/data/` directory persists across container restarts
- Includes: world files, plugins, mods, configurations, backups
- EFS automatically backs up data (encrypted at rest)

### Troubleshooting Configuration Issues

#### Server Won't Start

**Symptoms**: Container starts but Minecraft server doesn't start

**Solutions**:
1. **Check EULA**: Ensure `EULA=TRUE` is set
2. **Check Logs**: `aws logs tail /ecs/minecraft-server --follow`
3. **Verify Memory**: Ensure `MEMORY` is less than `task_memory - 1024`
4. **Check Port**: Ensure `SERVER_PORT` matches infrastructure port (25565)
5. **Verify Image**: Ensure container image exists and is accessible

**Common Errors**:
- `EULA must be accepted`: Set `EULA=TRUE`
- `OutOfMemoryError`: Increase `task_memory` or decrease `MEMORY`
- `Port already in use`: Check if port conflicts (shouldn't happen in containers)

#### Configuration Not Applying

**Symptoms**: Changes to environment variables or server.properties not taking effect

**Solutions**:
1. **Restart Server**: Force new ECS deployment
2. **Check Environment Variables**: Verify variables are correctly set in task definition
3. **Check File Syntax**: Ensure `server.properties` has correct syntax (no typos)
4. **Verify File Location**: Ensure editing `/data/server.properties` (not `/tmp/`)

**Debugging**:
```bash
# Access container
aws ecs execute-command --cluster <cluster> --task <task> --container minecraft-server --command "/bin/sh" --interactive

# Check environment variables
env | grep -E "MOTD|MAX_PLAYERS|MEMORY"

# Check server.properties
cat /data/server.properties

# Check server logs
tail -f /data/logs/latest.log
```

#### Performance Issues

**Symptoms**: Server lag, high tick time, low TPS (ticks per second)

**Solutions**:
1. **Increase Memory**: Increase `task_memory` and `MEMORY`
2. **Reduce View Distance**: Lower `VIEW_DISTANCE` (reduces chunk loading)
3. **Reduce Simulation Distance**: Lower `SIMULATION_DISTANCE` (fewer active entities)
4. **Use Paper**: Switch to `TYPE=PAPER` for better performance
5. **Enable Aikar Flags**: Set `USE_AIKAR_FLAGS=true`
6. **Check CPU**: Ensure `task_cpu` is sufficient (2 vCPU minimum for 20+ players)

**Monitoring**:
```bash
# Check server TPS (via RCON or logs)
# Look for "Can't keep up! Is the server overloaded?" messages
aws logs tail /ecs/minecraft-server --follow | grep -i "overloaded\|tps\|tick"
```

#### Out of Memory Errors

**Symptoms**: Server crashes with `OutOfMemoryError`, high memory usage

**Solutions**:
1. **Increase ECS Memory**: Increase `task_memory` in Terraform
2. **Adjust JVM Memory**: Ensure `MEMORY` is appropriate for `task_memory`
3. **Enable Aikar Flags**: Better garbage collection
4. **Reduce View Distance**: Lower memory usage
5. **Check for Memory Leaks**: Monitor memory usage over time

**Memory Calculation**:
- If `task_memory = 4096` and getting OOM errors:
  - Try `MEMORY = "2.5G"` (leave more headroom)
  - Or increase `task_memory = 5120` and use `MEMORY = "4G"`

#### Players Cannot Connect

**Symptoms**: Players can't connect despite server running

**Solutions**:
1. **Check Online Mode**: Ensure `ONLINE_MODE` matches player authentication
2. **Check Whitelist**: Disable whitelist if not needed: `WHITELIST=false`
3. **Verify Port**: Ensure `SERVER_PORT=25565` matches infrastructure
4. **Check Firewall**: Verify ALB security group allows TCP 25565
5. **Check Server Status**: Verify server is accepting connections (check logs)

**Debugging**:
```bash
# Check if server is listening
netstat -tuln | grep 25565

# Check server logs for connection errors
aws logs tail /ecs/minecraft-server --follow | grep -i "connection\|login\|failed"
```

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
1. Add variable to `variables.tf`
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

### Quick Start Guide

**Date**: 2024-12-19  
**Feature**: AWS Minecraft Server Infrastructure  
**Purpose**: Step-by-step guide to deploy the Minecraft server infrastructure

#### Prerequisites

**Required Tools**:
- **Terraform** >= 1.0 installed ([Installation Guide](https://developer.hashicorp.com/downloads))
- **AWS CLI** >= 2.0 installed and configured ([Installation Guide](https://aws.amazon.com/cli/))
- **AWS Account** with appropriate permissions
- **Git** (for cloning repository)

**AWS Permissions Required**:
The AWS credentials must have permissions to create:
- VPC, Subnets, Route Tables, Internet Gateway, NAT Gateway
- ECS Cluster, Task Definitions, Services
- EFS File Systems, Mount Targets
- ElastiCache Redis Clusters
- Application Load Balancer, Target Groups, Listeners
- Global Accelerator
- Security Groups
- IAM Roles and Policies
- Secrets Manager secrets (if creating)

**AWS Service Quotas**:
Ensure your AWS account has sufficient quotas:
- VPCs per region: At least 1
- NAT Gateways per AZ: At least 1
- ECS tasks: At least 10 (for scaling)
- ElastiCache clusters: At least 1

#### Step 1: Clone and Navigate

```bash
# Clone the repository (if applicable)
git clone <repository-url>
cd minecraft/terraform

# Or navigate to terraform directory if already cloned
cd terraform
```

#### Step 2: Configure AWS Credentials

```bash
# Option 1: AWS CLI configuration
aws configure

# Option 2: Environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="sa-east-1"

# Option 3: AWS SSO (if using)
aws sso login --profile your-profile
export AWS_PROFILE="your-profile"
```

**Verify credentials**:
```bash
aws sts get-caller-identity
```

#### Step 3: Configure Terraform Backend (Optional but Recommended)

Edit `backend.tf` or create `backend.hcl`:

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

**Create S3 bucket and DynamoDB table** (if not exists):
```bash
# Create S3 bucket
aws s3 mb s3://your-terraform-state-bucket --region sa-east-1
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region sa-east-1
```

#### Step 4: Create Redis Auth Token Secret

```bash
# Generate a secure random token
REDIS_TOKEN=$(openssl rand -base64 32)

# Create secret in AWS Secrets Manager
aws secretsmanager create-secret \
  --name minecraft/redis/auth-token \
  --secret-string "$REDIS_TOKEN" \
  --region sa-east-1 \
  --description "Redis authentication token for Minecraft server"
```

**Note**: If you skip this step, Terraform will attempt to create the secret automatically (requires additional permissions).

#### Step 5: Configure Variables

Copy the example variables file:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
# Required: Docker image for Minecraft server
container_image = "itzg/minecraft-server:latest"

# Optional: Override defaults
aws_region      = "sa-east-1"
environment     = "production"
desired_count   = 1
task_cpu        = 2048      # 2 vCPU
task_memory     = 4096      # 4GB

# Redis configuration
redis_node_type     = "cache.t3.micro"
redis_replica_count = 1

# Redis auth token secret (created in Step 4)
redis_auth_token_secret_name = "minecraft/redis/auth-token"

# Tags
tags = {
  Project     = "minecraft"
  Environment = "production"
  ManagedBy   = "terraform"
  CostCenter  = "gaming"
}
```

#### Step 6: Initialize Terraform

```bash
terraform init
```

**Expected output**:
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.x.x...
...
Terraform has been successfully initialized!
```

#### Step 7: Review Plan

```bash
terraform plan
```

**Review the plan carefully**:
- Verify all resources to be created
- Check resource names and tags
- Verify CIDR blocks don't conflict with existing networks
- Note estimated costs (NAT Gateway, ALB, Global Accelerator have hourly charges)

**Save plan for review** (optional):
```bash
terraform plan -out=tfplan
terraform show tfplan
```

#### Step 8: Deploy Infrastructure

```bash
terraform apply
```

**Or use saved plan**:
```bash
terraform apply tfplan
```

**Terraform will prompt**:
```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```

**Deployment time**: Approximately 10-15 minutes
- VPC and networking: ~2 minutes
- EFS: ~3 minutes
- ElastiCache Redis: ~10 minutes (slowest)
- ECS cluster and service: ~5 minutes
- ALB and Global Accelerator: ~3 minutes

#### Step 9: Verify Deployment

**Check Terraform Outputs**:

```bash
terraform output
```

**Expected outputs**:
- `minecraft_endpoint`: Public endpoint for players
- `redis_endpoint`: Redis cluster endpoint
- `efs_dns_name`: EFS DNS name
- `vpc_id`: VPC ID
- `ecs_cluster_id`: ECS cluster ID

**Verify ECS Service**:

```bash
# Get ECS cluster name
CLUSTER_NAME=$(terraform output -raw ecs_cluster_id | cut -d'/' -f2)

# Check service status
aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services minecraft-server \
  --region sa-east-1

# Check running tasks
aws ecs list-tasks \
  --cluster $CLUSTER_NAME \
  --region sa-east-1
```

**Test Minecraft Server Connection**:

```bash
# Get endpoint
ENDPOINT=$(terraform output -raw minecraft_endpoint)

# Test connection (Minecraft uses TCP port 25565)
nc -zv $ENDPOINT 25565

# Or use Minecraft client to connect
# Server Address: $ENDPOINT
# Port: 25565
```

#### Step 10: Access Container (Troubleshooting)

**Using AWS Systems Manager Session Manager**:

```bash
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

**Note**: Requires ECS Exec enabled in task definition and proper IAM permissions.

#### Common Issues and Solutions

**Issue: NAT Gateway Creation Fails**

**Error**: `Error creating NAT Gateway: InsufficientAddressesInSubnet`

**Solution**: Ensure public subnet has available IP addresses. Use smaller CIDR blocks or create additional subnets.

**Issue: ElastiCache Creation Takes Too Long**

**Error**: ElastiCache cluster creation times out

**Solution**: This is normal - ElastiCache can take 10-15 minutes. Wait for completion or check AWS Console.

**Issue: ECS Task Fails to Start**

**Error**: Task stops immediately after starting

**Solution**:
1. Check CloudWatch Logs: `aws logs tail /ecs/minecraft-server --follow`
2. Verify container image exists and is accessible
3. Check EFS mount: Ensure EFS security group allows NFS from ECS security group
4. Verify task has sufficient CPU/memory

**Issue: Cannot Connect to Minecraft Server**

**Error**: Connection timeout

**Solution**:
1. Verify ALB security group allows inbound TCP 25565 from 0.0.0.0/0
2. Check ECS task is running: `aws ecs describe-tasks --cluster <cluster> --tasks <task-id>`
3. Verify target group health: Check ALB target group in AWS Console
4. Check Global Accelerator status (if enabled)

#### Next Steps

**Configure Minecraft Server**:

1. **Access server files** via EFS mount or Session Manager
2. **Edit server.properties** (if mounted)
3. **Add plugins/mods** to plugins/ or mods/ directory
4. **Restart ECS service** to apply changes:
   ```bash
   aws ecs update-service \
     --cluster $CLUSTER_NAME \
     --service minecraft-server \
     --force-new-deployment \
     --region sa-east-1
   ```

**Monitor Infrastructure**:

- **CloudWatch Logs**: `/ecs/minecraft-server`
- **CloudWatch Metrics**: ECS service metrics, ALB metrics
- **Cost Monitoring**: AWS Cost Explorer, tag-based filtering

**Scale Infrastructure**:

Edit `terraform.tfvars`:
```hcl
desired_count = 3  # Increase number of containers
```

Apply changes:
```bash
terraform apply
```

#### Cleanup (Destroy Infrastructure)

**Warning**: This will delete all resources including persistent storage (world data).

```bash
# Review what will be destroyed
terraform plan -destroy

# Destroy infrastructure
terraform destroy
```

**To preserve world data**:
1. Backup EFS before destroy: `aws efs create-backup --file-system-id <efs-id>`
2. Or manually copy files from EFS before destroy

#### Additional Resources

- **Terraform AWS Provider Documentation**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- **ECS Fargate Documentation**: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html
- **Minecraft Server Docker Image**: https://hub.docker.com/r/itzg/minecraft-server
- **AWS Global Accelerator**: https://docs.aws.amazon.com/global-accelerator/

---

### Data Model

**Date**: 2024-12-19  
**Feature**: AWS Minecraft Server Infrastructure  
**Purpose**: Define Terraform resource structures and data relationships

#### Overview

This infrastructure project uses Terraform to define AWS resources. The "data model" here represents the Terraform resource structures, variable schemas, and output definitions that compose the infrastructure.

#### Core Resource Entities

**VPC Network**:

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

**Subnets**:

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

**Security Groups**:

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

**ECS Cluster**:

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

**ECS Task Definition**:

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

**ECS Service**:

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

**EFS File System**:

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

**ElastiCache Redis Cluster**:

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

**Application Load Balancer**:

**Purpose**: Distributes player traffic to ECS tasks

**Terraform Resource**: `aws_lb`

**Attributes**:
- `name`: ALB name
- `internal`: false (public)
- `load_balancer_type`: application
- `subnets`: Public subnet IDs
- `security_groups`: ALB security group
- `enable_deletion_protection`: false (for terraform destroy)

**Global Accelerator**:

**Purpose**: Optimizes routing for low latency

**Terraform Resource**: `aws_globalaccelerator_accelerator`

**Attributes**:
- `name`: Accelerator name
- `ip_address_type`: IPV4
- `enabled`: true

#### Variable Schema

**Root Module Variables**:

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

#### Output Schema

**Root Module Outputs**:

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

#### Data Flow

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

### Variable Schema

**Date**: 2024-12-19  
**Feature**: AWS Minecraft Server Infrastructure  
**Purpose**: Define all Terraform input variables and their contracts

#### Root Module Variables

**`aws_region`**:
- **Type**: `string`
- **Default**: `"sa-east-1"`
- **Description**: AWS region for resource deployment
- **Constraints**: Must be valid AWS region identifier
- **Example**: `"sa-east-1"`, `"us-east-1"`

**`container_image`**:
- **Type**: `string`
- **Required**: Yes
- **Description**: Docker image URI for Minecraft server container
- **Constraints**: Must be valid Docker image reference (ECR, Docker Hub, etc.)
- **Example**: `"itzg/minecraft-server:latest"`, `"123456789012.dkr.ecr.sa-east-1.amazonaws.com/minecraft:1.20.1"`

**`vpc_cidr`**:
- **Type**: `string`
- **Default**: `"10.0.0.0/16"`
- **Description**: CIDR block for VPC
- **Constraints**: Must be valid IPv4 CIDR notation, /16 or larger
- **Example**: `"10.0.0.0/16"`, `"172.16.0.0/16"`

**`environment`**:
- **Type**: `string`
- **Default**: `"production"`
- **Description**: Environment name (used for resource naming and tagging)
- **Constraints**: Lowercase alphanumeric and hyphens only
- **Example**: `"production"`, `"staging"`, `"development"`

**`desired_count`**:
- **Type**: `number`
- **Default**: `1`
- **Description**: Desired number of ECS tasks to run
- **Constraints**: Integer >= 1
- **Example**: `1`, `3`, `10`

**`task_cpu`**:
- **Type**: `number`
- **Default**: `2048`
- **Description**: CPU units for ECS task (1024 = 1 vCPU)
- **Constraints**: Must be valid Fargate CPU value: 256, 512, 1024, 2048, 4096
- **Example**: `1024` (1 vCPU), `2048` (2 vCPU), `4096` (4 vCPU)

**`task_memory`**:
- **Type**: `number`
- **Default**: `4096`
- **Description**: Memory in MB for ECS task
- **Constraints**: Must be valid Fargate memory value, compatible with CPU
- **Example**: `2048` (2GB), `4096` (4GB), `8192` (8GB)

**`redis_node_type`**:
- **Type**: `string`
- **Default**: `"cache.t3.micro"`
- **Description**: ElastiCache Redis node instance type
- **Constraints**: Must be valid ElastiCache node type
- **Example**: `"cache.t3.micro"`, `"cache.t3.small"`, `"cache.t3.medium"`

**`redis_replica_count`**:
- **Type**: `number`
- **Default**: `1`
- **Description**: Number of Redis replica nodes
- **Constraints**: Integer >= 0 (0 = no replication, 1+ = high availability)
- **Example**: `0`, `1`, `2`

**`efs_performance_mode`**:
- **Type**: `string`
- **Default**: `"generalPurpose"`
- **Description**: EFS performance mode
- **Constraints**: Must be `"generalPurpose"` or `"maxIO"`
- **Example**: `"generalPurpose"` (recommended), `"maxIO"` (for high throughput)

**`enable_global_accelerator`**:
- **Type**: `bool`
- **Default**: `true`
- **Description**: Enable AWS Global Accelerator for low-latency routing
- **Constraints**: Boolean
- **Example**: `true` (recommended for South America), `false` (lower cost)

**`tags`**:
- **Type**: `map(string)`
- **Default**: `{}`
- **Description**: Additional tags to apply to all resources
- **Constraints**: Map of string key-value pairs
- **Example**: `{ CostCenter = "gaming", Team = "devops" }`

**`redis_auth_token_secret_name`**:
- **Type**: `string`
- **Default**: `null`
- **Description**: AWS Secrets Manager secret name containing Redis auth token
- **Constraints**: Must exist in Secrets Manager, or null to auto-generate
- **Example**: `"minecraft/redis/auth-token"`

**`minecraft_server_port`**:
- **Type**: `number`
- **Default**: `25565`
- **Description**: Minecraft server port
- **Constraints**: Integer between 1-65535
- **Example**: `25565` (standard), `25566` (custom)

**`enable_deletion_protection`**:
- **Type**: `bool`
- **Default**: `false`
- **Description**: Enable deletion protection on ALB (prevents accidental deletion)
- **Constraints**: Boolean
- **Example**: `true` (production), `false` (development, allows terraform destroy)

#### Output Contracts

**Root Module Outputs**:

**`minecraft_endpoint`**:
- **Type**: `string`
- **Description**: Public endpoint for Minecraft server connection
- **Format**: DNS name or IP address
- **Example**: `"minecraft.example.com"` or `"1.2.3.4"`

**`redis_endpoint`**:
- **Type**: `string`
- **Description**: ElastiCache Redis cluster endpoint
- **Format**: `{cluster-id}.cache.amazonaws.com:6379`
- **Example**: `"minecraft-redis.abc123.cache.sa-east-1.amazonaws.com:6379"`

**`efs_dns_name`**:
- **Type**: `string`
- **Description**: EFS DNS name for mounting
- **Format**: `{file-system-id}.efs.{region}.amazonaws.com`
- **Example**: `"fs-12345678.efs.sa-east-1.amazonaws.com"`

**`vpc_id`**:
- **Type**: `string`
- **Description**: VPC ID
- **Format**: `vpc-{hexadecimal}`
- **Example**: `"vpc-0123456789abcdef0"`

**`ecs_cluster_id`**:
- **Type**: `string`
- **Description**: ECS cluster ID/ARN
- **Format**: `arn:aws:ecs:{region}:{account}:cluster/{name}`
- **Example**: `"arn:aws:ecs:sa-east-1:123456789012:cluster/minecraft-cluster"`

---

### Research & Decisions

**Date**: 2024-12-19  
**Feature**: AWS Minecraft Server Infrastructure  
**Purpose**: Resolve technical unknowns and document architectural decisions

#### 1. ECS Fargate vs EC2 Launch Type

**Decision**: ECS Fargate

**Rationale**:
- Serverless container execution eliminates EC2 instance management overhead
- Automatic scaling and patching reduce operational burden
- Better cost efficiency for variable workloads
- No need to manage EC2 instances, AMIs, or instance types
- Fargate tasks can be placed in private subnets with NAT Gateway for outbound access
- Compatible with EFS for persistent storage

**Alternatives Considered**:
- EC2 launch type: Provides more control and potentially lower cost at scale, but requires instance management, patching, and capacity planning
- EKS: Overkill for single Minecraft server deployment, adds unnecessary complexity

#### 2. Public Entrypoint: Global Accelerator + ALB vs Alternatives

**Decision**: Application Load Balancer with AWS Global Accelerator

**Rationale**:
- Global Accelerator provides optimal routing via AWS backbone network for lowest latency
- Stable static IP addresses (anycast) improve connection reliability
- ALB provides health checks, SSL termination, and request routing
- ALB integrates seamlessly with ECS Fargate services
- Global Accelerator automatically routes to nearest healthy endpoint
- Cost-effective for gaming workloads with predictable traffic patterns

**Alternatives Considered**:
- ALB only: Simpler and lower cost, but lacks global routing optimization
- Network Load Balancer + Global Accelerator: Lower latency for UDP traffic, but ALB sufficient for Minecraft TCP connections
- Public IP directly on container: Simplest but no load balancing, less reliable, violates private subnet isolation

#### 3. Storage: EFS vs EBS for Fargate

**Decision**: Amazon EFS

**Rationale**:
- EFS is the only network-backed storage option compatible with Fargate
- EBS volumes cannot be directly attached to Fargate tasks
- EFS provides shared storage across multiple containers (useful for scaling)
- Automatic scaling without manual provisioning
- Supports concurrent access from multiple containers
- Pay-per-use pricing model

**Alternatives Considered**:
- EBS volumes: Not compatible with Fargate, would require EC2 launch type
- S3: Not suitable for file system access patterns required by Minecraft server

**EFS Configuration**:
- Performance mode: General Purpose (suitable for small files, metadata operations)
- Throughput mode: Bursting (cost-effective for variable workloads)
- Encryption: At-rest encryption enabled
- Lifecycle management: Not required for active game server data

#### 4. Redis Cluster Configuration

**Decision**: ElastiCache Redis Cluster Mode Enabled, 1 primary + 1 replica, cache.t3.micro

**Rationale**:
- Cluster Mode Enabled provides high availability and supports future scaling
- Replication ensures failover capability if primary node fails
- cache.t3.micro is cost-effective for initial deployments (can be scaled via variables)
- Cluster mode allows horizontal scaling by adding shards
- Encryption in-transit and at-rest for security compliance

**Alternatives Considered**:
- Single-node Redis: Simpler but no high availability, single point of failure
- Multi-shard cluster: Higher cost and complexity, not needed for initial deployment
- Redis Serverless: Newer offering, auto-scaling, but may have compatibility concerns with existing Redis clients

**Configuration Details**:
- Node type: cache.t3.micro (0.5 vCPU, 0.5GB RAM) - suitable for caching/state management
- Replication: 1 replica for high availability
- Cluster mode: Enabled for future scalability
- Auth token: Required, stored in AWS Secrets Manager
- Subnet group: Private subnets only

#### 5. Container Resource Sizing

**Decision**: 2 vCPU, 4GB RAM (default, configurable via variables)

**Rationale**:
- Balanced cost/performance ratio
- Suitable for 20-50 concurrent Minecraft players per container
- Fargate pricing is reasonable at this tier
- Can scale horizontally by adding more tasks
- Memory sufficient for Minecraft server + JVM overhead
- CPU allows for smooth gameplay without lag

**Alternatives Considered**:
- 1 vCPU, 2GB RAM: Lower cost but may struggle with 10+ concurrent players
- 4 vCPU, 8GB RAM: Higher performance but significantly higher cost, overkill for initial deployment

**Scaling Strategy**:
- Horizontal scaling via ECS service desired_count
- Vertical scaling via task definition CPU/memory changes
- Auto-scaling policies can be added later

#### 6. Administrative Access Method

**Decision**: AWS Systems Manager Session Manager

**Rationale**:
- No open SSH ports required (improves security posture)
- IAM-based access control (no SSH key management)
- Audit logging of all sessions
- Works with Fargate containers via SSM agent
- No need for bastion hosts or VPN
- Integrated with AWS CloudTrail for compliance

**Alternatives Considered**:
- Bastion host: Traditional approach but requires SSH key management and open ports
- No SSH access: Immutable containers, but limits troubleshooting capabilities
- VPN: Overkill for single infrastructure deployment

**Configuration Requirements**:
- ECS task execution role must have SSM permissions
- SSM agent installed in container image (or use AWS-provided base images)
- IAM policies for Session Manager access

#### 7. Terraform Module Structure

**Decision**: Separate modules for VPC, ECS, storage, cache, and networking

**Rationale**:
- Follows Terraform best practices for code organization
- Modules are independently testable and reusable
- Clear separation of concerns
- Easier to maintain and update individual components
- Supports composition and flexibility

**Module Responsibilities**:
- **vpc**: VPC, subnets, route tables, Internet Gateway, NAT Gateway, security groups
- **ecs**: ECS cluster, task definitions, services, IAM roles
- **storage**: EFS file system, mount targets, access points
- **cache**: ElastiCache subnet group, Redis cluster, parameter group
- **networking**: Application Load Balancer, target groups, Global Accelerator, listeners

#### 8. Secret Management Strategy

**Decision**: AWS Secrets Manager for sensitive data, Parameter Store for non-sensitive configuration

**Rationale**:
- Secrets Manager provides automatic rotation capabilities
- Encryption at rest and in transit
- IAM-based access control
- Audit trail via CloudTrail
- Parameter Store for non-sensitive config (lower cost)
- No hard-coded secrets in Terraform code

**Implementation**:
- Redis auth token: Secrets Manager
- Container image credentials: Secrets Manager (if using private registry)
- Minecraft server configuration: Parameter Store (non-sensitive)
- Terraform data sources to retrieve secrets at apply time

#### 9. Resource Tagging Strategy

**Decision**: Consistent tagging across all resources with project, environment, and cost-center tags

**Rationale**:
- Enables cost tracking and allocation
- Supports resource organization and filtering
- Required for compliance and governance
- Facilitates automated resource management

**Tag Schema**:
- `Project`: minecraft-server
- `Environment`: production/staging/dev
- `ManagedBy`: terraform
- `CostCenter`: [optional]
- `CreatedBy`: [user/CI system]

#### 10. Terraform State Management

**Decision**: Remote state backend (S3 + DynamoDB for state locking)

**Rationale**:
- Enables team collaboration
- State locking prevents concurrent modifications
- Backup and versioning via S3
- Required for production infrastructure

**Configuration**:
- S3 bucket for state storage (encrypted)
- DynamoDB table for state locking
- Backend configuration in terraform block

**Summary**: All technical decisions have been made based on AWS best practices, cost optimization, security requirements, and operational simplicity. The architecture leverages managed AWS services (Fargate, EFS, ElastiCache, ALB, Global Accelerator) to minimize operational overhead while ensuring scalability, security, and low latency for players in South America.

---

### Implementation Plan

**Branch**: `001-aws-minecraft-infrastructure` | **Date**: 2024-12-19

#### Summary

Deploy a production-ready, containerized Minecraft server infrastructure on AWS using Terraform. The infrastructure includes a VPC with public/private subnets across multiple AZs, ECS Fargate cluster running Minecraft containers, EFS for persistent storage, ElastiCache Redis cluster, Application Load Balancer with Global Accelerator for low-latency player connections, and comprehensive security controls. The Terraform project follows best practices with modular structure, parameterized variables, proper secret management, and clean resource lifecycle management.

**Research Complete**: All technical decisions documented. Key decisions: ECS Fargate (serverless), ALB + Global Accelerator (low latency), EFS (Fargate-compatible storage), Redis Cluster Mode with replication (HA), Systems Manager Session Manager (secure access).

#### Technical Context

**Language/Version**: Terraform >= 1.0, HCL2  
**Primary Dependencies**: AWS Provider >= 5.0, Terraform modules for VPC, ECS, EFS, ElastiCache, ALB, Global Accelerator  
**Storage**: Amazon EFS (for Fargate-compatible persistent storage), ElastiCache Redis (for caching/state)  
**Testing**: terraform validate, terraform plan (dry-run), terratest or kitchen-terraform for integration tests  
**Target Platform**: AWS (sa-east-1 region), Linux containers (Fargate)  
**Project Type**: Infrastructure-as-Code (Terraform modules)  
**Performance Goals**: <50ms latency for players in Brazil, 99.9% uptime during updates, support 20-50 concurrent players per container instance, scale to 10+ container instances  
**Constraints**: No hard-coded secrets, clean terraform destroy removes all resources, EFS storage supports up to 100GB growth, containers isolated in private subnets with NAT Gateway for outbound access  
**Scale/Scope**: Modular Terraform project with 5+ modules (VPC, ECS, storage, cache, networking), configurable via variables, reusable for other game server deployments

#### Project Structure

**Source Code (repository root)**:

```text
├── main.tf                 # Root module - orchestrates all sub-modules
├── variables.tf            # Input variables with defaults
├── outputs.tf              # Output values (endpoints, IDs, etc.)
├── terraform.tfvars.example # Example variable values
├── versions.tf             # Provider version constraints
│
├── modules/
│   ├── vpc/                # VPC module
│   ├── ecs/                # ECS Fargate module
│   ├── storage/            # EFS storage module
│   ├── cache/              # ElastiCache Redis module
│   └── networking/         # ALB + Global Accelerator module
```

**Structure Decision**: Modular Terraform project structure with separate modules for each major component (VPC, ECS, storage, cache, networking). This follows Terraform best practices for reusability, maintainability, and separation of concerns. Each module is independently testable and can be reused in other infrastructure projects.

## License

See repository LICENSE file.
