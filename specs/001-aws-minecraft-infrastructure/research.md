# Research: AWS Minecraft Server Infrastructure

**Date**: 2024-12-19  
**Feature**: AWS Minecraft Server Infrastructure  
**Purpose**: Resolve technical unknowns and document architectural decisions

## Research Tasks

### 1. ECS Fargate vs EC2 Launch Type

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

**References**:
- AWS ECS Fargate documentation
- EFS integration with Fargate (fully supported)

---

### 2. Public Entrypoint: Global Accelerator + ALB vs Alternatives

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

**References**:
- AWS Global Accelerator documentation
- ALB integration with ECS Fargate
- Minecraft server protocol (TCP-based)

---

### 3. Storage: EFS vs EBS for Fargate

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

**References**:
- AWS EFS with ECS Fargate integration
- EFS performance modes documentation

---

### 4. Redis Cluster Configuration

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

**References**:
- AWS ElastiCache Redis documentation
- Redis Cluster Mode best practices

---

### 5. Container Resource Sizing

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

**References**:
- AWS Fargate pricing
- Minecraft server resource requirements
- ECS task sizing best practices

---

### 6. Administrative Access Method

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

**References**:
- AWS Systems Manager Session Manager documentation
- ECS integration with SSM

---

### 7. Terraform Module Structure

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

**References**:
- Terraform module best practices
- AWS provider documentation

---

### 8. Secret Management Strategy

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

**References**:
- AWS Secrets Manager documentation
- AWS Systems Manager Parameter Store documentation
- Terraform AWS provider secrets data sources

---

### 9. Resource Tagging Strategy

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

**References**:
- AWS Tagging Best Practices
- Terraform default_tags feature

---

### 10. Terraform State Management

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

**References**:
- Terraform S3 backend documentation
- Terraform state locking best practices

---

## Summary

All technical decisions have been made based on AWS best practices, cost optimization, security requirements, and operational simplicity. The architecture leverages managed AWS services (Fargate, EFS, ElastiCache, ALB, Global Accelerator) to minimize operational overhead while ensuring scalability, security, and low latency for players in South America.


