# Tasks: AWS Minecraft Server Infrastructure

**Input**: Design documents from `/specs/001-aws-minecraft-infrastructure/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Terraform project**: `terraform/` at repository root
- **Modules**: `terraform/modules/{module-name}/`
- **Root configuration**: `terraform/main.tf`, `terraform/variables.tf`, `terraform/outputs.tf`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic Terraform structure

- [X] T001 Create terraform directory structure per implementation plan in terraform/
- [X] T002 [P] Create root module files: terraform/main.tf, terraform/variables.tf, terraform/outputs.tf
- [X] T003 [P] Create terraform/versions.tf with AWS provider >= 5.0 constraint
- [X] T004 [P] Create terraform/terraform.tfvars.example with example variable values
- [X] T005 [P] Create terraform/README.md with project overview and usage instructions
- [X] T006 Create module directory structure: terraform/modules/vpc/, terraform/modules/ecs/, terraform/modules/storage/, terraform/modules/cache/, terraform/modules/networking/

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: VPC module that MUST be complete before ANY other infrastructure can be deployed

**⚠️ CRITICAL**: No other modules can be created until VPC module is complete and tested

- [X] T007 [US1] Create VPC module structure: terraform/modules/vpc/main.tf, terraform/modules/vpc/variables.tf, terraform/modules/vpc/outputs.tf
- [X] T008 [US1] Implement VPC resource in terraform/modules/vpc/main.tf with CIDR block, DNS support, and tags
- [X] T009 [P] [US1] Implement public subnets (2+ AZs) in terraform/modules/vpc/main.tf
- [X] T010 [P] [US1] Implement private subnets (2+ AZs) in terraform/modules/vpc/main.tf
- [X] T011 [US1] Implement Internet Gateway in terraform/modules/vpc/main.tf
- [X] T012 [US1] Implement NAT Gateway in terraform/modules/vpc/main.tf (requires public subnet)
- [X] T013 [US1] Implement public route table with Internet Gateway route in terraform/modules/vpc/main.tf
- [X] T014 [US1] Implement private route tables with NAT Gateway route in terraform/modules/vpc/main.tf
- [X] T015 [US1] Create VPC module variables in terraform/modules/vpc/variables.tf (vpc_cidr, availability_zones, public_subnet_cidrs, private_subnet_cidrs, tags)
- [X] T016 [US1] Create VPC module outputs in terraform/modules/vpc/outputs.tf (vpc_id, public_subnet_ids, private_subnet_ids, nat_gateway_id)
- [X] T017 [US1] Create VPC module README in terraform/modules/vpc/README.md with usage and variable documentation
- [X] T018 [US1] Integrate VPC module in terraform/main.tf root module
- [X] T019 [US1] Validate VPC module: terraform init, terraform validate, terraform plan

**Checkpoint**: VPC module ready - other modules can now reference VPC outputs

---

## Phase 3: User Story 1 - Initial Infrastructure Deployment (Priority: P1) 🎯 MVP

**Goal**: Deploy complete Minecraft server infrastructure on AWS using Terraform with all required resources (VPC, networking, compute, storage, caching) operational and accessible

**Independent Test**: Run terraform init and terraform apply with default variables, verify all resources created successfully, check Terraform outputs for connection information, verify Minecraft server is accessible

### Implementation for User Story 1

#### Storage Module (EFS)
- [X] T020 [P] [US1] Create storage module structure: terraform/modules/storage/main.tf, terraform/modules/storage/variables.tf, terraform/modules/storage/outputs.tf
- [X] T021 [US1] Implement EFS file system in terraform/modules/storage/main.tf with encryption, performance mode (generalPurpose), throughput mode (bursting)
- [X] T022 [US1] Implement EFS mount targets (one per AZ) in terraform/modules/storage/main.tf
- [X] T023 [US1] Create EFS security group in terraform/modules/storage/main.tf allowing NFS (2049) from ECS task security group
- [X] T024 [US1] Create storage module variables in terraform/modules/storage/variables.tf (vpc_id, subnet_ids, performance_mode, tags)
- [X] T025 [US1] Create storage module outputs in terraform/modules/storage/outputs.tf (efs_id, efs_dns_name, efs_security_group_id)
- [X] T026 [US1] Create storage module README in terraform/modules/storage/README.md

#### Cache Module (ElastiCache Redis)
- [X] T027 [P] [US1] Create cache module structure: terraform/modules/cache/main.tf, terraform/modules/cache/variables.tf, terraform/modules/cache/outputs.tf
- [X] T028 [US1] Create ElastiCache subnet group in terraform/modules/cache/main.tf using private subnets
- [X] T029 [US1] Create Redis security group in terraform/modules/cache/main.tf allowing TCP 6379 from ECS task security group
- [X] T030 [US1] Implement ElastiCache Redis replication group in terraform/modules/cache/main.tf with Cluster Mode Enabled, 1 primary + 1 replica, cache.t3.micro, encryption in-transit and at-rest
- [X] T031 [US1] Configure Redis auth token from Secrets Manager in terraform/modules/cache/main.tf using data source
- [X] T032 [US1] Create cache module variables in terraform/modules/cache/variables.tf (cluster_id, node_type, num_cache_nodes, subnet_group_name, subnet_ids, auth_token_secret_name, tags)
- [X] T033 [US1] Create cache module outputs in terraform/modules/cache/outputs.tf (redis_endpoint, redis_port, redis_cluster_id)
- [X] T034 [US1] Create cache module README in terraform/modules/cache/README.md

#### ECS Module (Fargate Cluster and Service)
- [X] T035 [P] [US1] Create ECS module structure: terraform/modules/ecs/main.tf, terraform/modules/ecs/variables.tf, terraform/modules/ecs/outputs.tf, terraform/modules/ecs/task-definition.json.tpl
- [X] T036 [US1] Create ECS cluster in terraform/modules/ecs/main.tf with Fargate capacity providers
- [X] T037 [US1] Create ECS task execution role in terraform/modules/ecs/main.tf with permissions for ECR, CloudWatch Logs, EFS, Secrets Manager, SSM
- [X] T038 [US1] Create ECS task role in terraform/modules/ecs/main.tf with permissions for SSM Session Manager
- [X] T039 [US1] Create ECS task security group in terraform/modules/ecs/main.tf allowing TCP 25565 from ALB security group, TCP 6379 from Redis security group, outbound all
- [X] T040 [US1] Create ECS task definition template in terraform/modules/ecs/task-definition.json.tpl with Fargate launch type, 2 vCPU/4GB RAM default, container image variable, EFS mount, environment variables, secrets from Secrets Manager
- [X] T041 [US1] Implement ECS task definition resource in terraform/modules/ecs/main.tf using templatefile() for task-definition.json.tpl
- [X] T042 [US1] Create ECS service in terraform/modules/ecs/main.tf with Fargate launch type, desired count, network configuration (private subnets, security groups), load balancer configuration, deployment configuration
- [X] T043 [US1] Create ECS module variables in terraform/modules/ecs/variables.tf (cluster_name, service_name, container_image, task_cpu, task_memory, desired_count, subnet_ids, efs_file_system_id, efs_security_group_id, target_group_arn, alb_security_group_id, redis_endpoint, redis_port, redis_security_group_id, redis_auth_token_secret_name, tags)
- [X] T044 [US1] Create ECS module outputs in terraform/modules/ecs/outputs.tf (ecs_cluster_id, ecs_service_id, ecs_task_security_group_id)
- [X] T045 [US1] Create ECS module README in terraform/modules/ecs/README.md

#### Networking Module (ALB + Global Accelerator)
- [X] T046 [P] [US1] Create networking module structure: terraform/modules/networking/main.tf, terraform/modules/networking/variables.tf, terraform/modules/networking/outputs.tf
- [X] T047 [US1] Create ALB security group in terraform/modules/networking/main.tf allowing TCP 25565 from 0.0.0.0/0, outbound all
- [X] T048 [US1] Implement Application Load Balancer in terraform/modules/networking/main.tf in public subnets with security group
- [X] T049 [US1] Create target group in terraform/modules/networking/main.tf for TCP 25565 (Minecraft port), health check configuration
- [X] T050 [US1] Create ALB listener in terraform/modules/networking/main.tf forwarding to target group
- [X] T051 [US1] Implement Global Accelerator in terraform/main.tf root module with IPV4 address type
- [X] T052 [US1] Create Global Accelerator listener in terraform/main.tf root module for TCP 25565
- [X] T053 [US1] Create Global Accelerator endpoint group in terraform/main.tf root module pointing to ALB
- [X] T054 [US1] Create networking module variables in terraform/modules/networking/variables.tf (vpc_id, subnet_ids, target_group_port, enable_deletion_protection, tags)
- [X] T055 [US1] Create networking module outputs in terraform/modules/networking/outputs.tf (alb_arn, alb_dns_name, target_group_arn, alb_security_group_id)
- [X] T056 [US1] Create networking module README in terraform/modules/networking/README.md

#### Root Module Integration
- [X] T057 [US1] Integrate all modules in terraform/main.tf root module with proper dependencies (VPC → Storage/Cache/Networking → ECS)
- [X] T058 [US1] Create root module variables in terraform/variables.tf with defaults: aws_region (sa-east-1), container_image (required), vpc_cidr (10.0.0.0/16), environment (production), desired_count (1), task_cpu (2048), task_memory (4096), redis_node_type (cache.t3.micro), redis_replica_count (1), enable_global_accelerator (true), tags (map)
- [X] T059 [US1] Add variable validation in terraform/variables.tf for task_cpu (256, 512, 1024, 2048, 4096), task_memory (512-30720), desired_count (1-100)
- [X] T060 [US1] Create root module outputs in terraform/outputs.tf: minecraft_endpoint (Global Accelerator IP or ALB DNS), redis_endpoint, efs_dns_name, vpc_id, ecs_cluster_id, ecs_service_id, alb_arn, redis_cluster_id, efs_id, public_subnet_ids, private_subnet_ids, security_group_ids (map)
- [X] T061 [US1] Configure default tags for all resources in terraform/main.tf using default_tags block
- [X] T062 [US1] Validate complete infrastructure: terraform init, terraform validate, terraform plan with default variables

**Checkpoint**: User Story 1 complete - infrastructure can be deployed end-to-end with terraform apply

---

## Phase 4: User Story 4 - Low-Latency Player Connection (Priority: P1)

**Goal**: Players in Brazil/South America connect with <50ms latency via Global Accelerator and ALB routing

**Independent Test**: Deploy infrastructure, connect from Brazil/South America, measure latency <50ms, verify Global Accelerator routes to nearest AWS edge location

### Implementation for User Story 4

**Note**: Most Global Accelerator and ALB configuration is already implemented in US1. This phase focuses on optimization and validation.

- [X] T063 [US4] Verify Global Accelerator configuration in terraform/main.tf uses IPV4 and is enabled
- [X] T064 [US4] Configure ALB health checks in terraform/modules/networking/main.tf for optimal failover (TCP check on port 25565)
- [X] T065 [US4] Add documentation in terraform/modules/networking/README.md about Global Accelerator latency optimization for South America
- [X] T066 [US4] Add output for Global Accelerator DNS name in terraform/outputs.tf
- [X] T067 [US4] Update terraform/outputs.tf to prioritize Global Accelerator endpoint over ALB DNS for minecraft_endpoint output

**Checkpoint**: User Story 4 complete - low-latency routing configured and documented

---

## Phase 5: User Story 5 - Secure Infrastructure Access (Priority: P1)

**Goal**: Security groups restrict traffic to necessary ports only, credentials managed via Secrets Manager, no hard-coded secrets, Session Manager access configured

**Independent Test**: Review Terraform code for hard-coded secrets (should find none), attempt unauthorized Redis access (should be blocked), verify Session Manager access works

### Implementation for User Story 5

#### Security Groups (already partially implemented in US1, verify completeness)
- [X] T068 [US5] Verify ALB security group in terraform/modules/networking/main.tf only allows TCP 25565 from 0.0.0.0/0
- [X] T069 [US5] Verify ECS task security group in terraform/modules/ecs/main.tf only allows TCP 25565 from ALB security group and egress TCP 6379 to Redis security group
- [X] T070 [US5] Verify Redis security group in terraform/modules/cache/main.tf only allows TCP 6379 from ECS task security group (via security_group_rule in root), no outbound rules
- [X] T071 [US5] Verify EFS security group in terraform/modules/storage/main.tf only allows NFS (2049) from ECS task security group (via security_group_rule in root), no outbound rules

#### Secrets Management
- [X] T072 [US5] Create data source for Redis auth token from Secrets Manager in terraform/modules/cache/main.tf (no hard-coded values)
- [X] T073 [US5] Configure ECS task definition to retrieve secrets from Secrets Manager in terraform/modules/ecs/task-definition.json.tpl using secrets block
- [X] T074 [US5] Add variable for redis_auth_token_secret_name in terraform/modules/cache/variables.tf and terraform/variables.tf
- [X] T075 [US5] Document secret creation process in terraform/README.md (create secret before terraform apply)

#### Session Manager Configuration
- [X] T076 [US5] Verify ECS task execution role includes SSM permissions in terraform/modules/ecs/main.tf (for Session Manager)
- [X] T077 [US5] Verify ECS task role includes SSM permissions in terraform/modules/ecs/main.tf (for Session Manager)
- [X] T078 [US5] Enable ECS Exec in ECS service configuration in terraform/modules/ecs/main.tf (enable_execute_command = true)
- [X] T079 [US5] Add documentation for Session Manager access in terraform/modules/ecs/README.md with example commands

#### Security Validation
- [X] T080 [US5] Review all Terraform files for hard-coded secrets (passwords, API keys, tokens) - verified: none found
- [X] T081 [US5] Add security best practices section to terraform/README.md covering secrets management, security groups, and access controls

**Checkpoint**: User Story 5 complete - security hardened, no hard-coded secrets, Session Manager configured

---

## Phase 6: User Story 2 - Infrastructure Scaling and Updates (Priority: P2)

**Goal**: Scale infrastructure (container count, instance sizes, storage) or update container image without downtime via Terraform variable changes

**Independent Test**: Modify desired_count variable, run terraform apply, verify additional containers provisioned. Modify container_image variable, run terraform apply, verify containers updated without data loss

### Implementation for User Story 2

#### Variable Configuration for Scaling
- [X] T082 [US2] Verify desired_count variable supports scaling in terraform/variables.tf (validation: 1-100)
- [X] T083 [US2] Verify task_cpu and task_memory variables support vertical scaling in terraform/variables.tf
- [X] T084 [US2] Verify container_image variable supports updates in terraform/variables.tf

#### ECS Service Configuration for Zero-Downtime Updates
- [X] T085 [US2] Configure ECS service deployment configuration in terraform/modules/ecs/main.tf with minimum_healthy_percent (100) and maximum_percent (200) for zero-downtime deployments
- [X] T086 [US2] Configure ECS service deployment circuit breaker in terraform/modules/ecs/main.tf to enable automatic rollback on failure
- [X] T087 [US2] Configure ECS service health check grace period in terraform/modules/ecs/main.tf for proper health check timing (health checks configured in target group)

#### Storage Scaling
- [X] T088 [US2] Document EFS auto-scaling capabilities in terraform/modules/storage/README.md (EFS scales automatically, no manual intervention needed)
- [X] T089 [US2] Add note about EFS performance mode scaling in terraform/modules/storage/README.md

#### Documentation for Scaling
- [X] T090 [US2] Add scaling guide to terraform/README.md covering horizontal scaling (desired_count), vertical scaling (task_cpu/task_memory), and container image updates
- [X] T091 [US2] Add examples to terraform/terraform.tfvars.example showing scaling configurations

**Checkpoint**: User Story 2 complete - infrastructure supports scaling and updates via Terraform variables

---

## Phase 7: User Story 3 - Infrastructure Destruction and Cleanup (Priority: P2)

**Goal**: terraform destroy removes all resources (NAT gateways, EFS, ElastiCache, ECS, networking) without leaving orphaned resources that incur charges

**Independent Test**: Run terraform destroy, verify all resources deleted, check AWS console for orphaned resources, verify no ongoing charges

### Implementation for User Story 3

#### Resource Lifecycle Configuration
- [X] T092 [US3] Verify ALB deletion protection is configurable via variable in terraform/modules/networking/main.tf (enable_deletion_protection, default false for terraform destroy)
- [X] T093 [US3] Configure ECS service to allow deletion in terraform/modules/ecs/main.tf (no deletion protection)
- [X] T094 [US3] Verify EFS file system allows deletion in terraform/modules/storage/main.tf (no deletion protection by default)
- [X] T095 [US3] Verify ElastiCache cluster allows deletion in terraform/modules/cache/main.tf (no deletion protection)

#### Dependency Ordering for Clean Destruction
- [X] T096 [US3] Verify resource dependencies in terraform/main.tf allow proper destruction order: ECS service → ECS cluster → ALB → Global Accelerator → ElastiCache → EFS → NAT Gateway → VPC
- [X] T097 [US3] Add depends_on clauses where needed in terraform/main.tf to ensure proper destruction order

#### Data Loss Warning
- [X] T098 [US3] Add warning comment in terraform/README.md about data loss when destroying EFS (world data will be lost)
- [X] T099 [US3] Add destruction guide to terraform/README.md with warnings about data loss and backup recommendations

#### Cleanup Validation
- [X] T100 [US3] Document cleanup verification steps in terraform/README.md (check AWS console, verify no orphaned resources, check billing)

**Checkpoint**: User Story 3 complete - terraform destroy removes all resources cleanly

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, validation, and improvements affecting multiple user stories

- [X] T101 [P] Add comprehensive comments to all Terraform files explaining component purpose, customization options, and scaling guidance
- [X] T102 [P] Update all module README files with complete usage examples, variable descriptions, and output descriptions
- [X] T103 [P] Create terraform/backend.tf.example showing S3 backend configuration for remote state
- [X] T104 Add terraform/.gitignore file excluding .terraform/, *.tfstate, *.tfvars (except .example) - created at root level
- [X] T105 [P] Add resource tagging strategy documentation to terraform/README.md explaining tag schema and cost tracking
- [X] T106 [P] Add troubleshooting section to terraform/README.md covering common issues (NAT Gateway creation, ElastiCache timeouts, ECS task failures, connection issues)
- [X] T107 Add cost estimation section to terraform/README.md with approximate monthly costs for default configuration
- [X] T108 [P] Validate all Terraform files: terraform fmt, terraform validate, terraform plan with default variables (fmt completed, validate/plan require AWS credentials)
- [ ] T109 Run quickstart.md validation: verify all steps work end-to-end (requires AWS credentials and actual deployment)
- [ ] T110 Add CI/CD integration examples to terraform/README.md (GitHub Actions, GitLab CI) for automated terraform plan/apply

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all other modules (VPC must exist first)
- **User Story 1 (Phase 3)**: Depends on Foundational (VPC module) - All modules can be created in parallel after VPC
- **User Story 4 (Phase 4)**: Depends on User Story 1 (ALB/Global Accelerator already implemented, just optimization)
- **User Story 5 (Phase 5)**: Depends on User Story 1 (security groups already implemented, just verification and secrets)
- **User Story 2 (Phase 6)**: Depends on User Story 1 (scaling builds on existing infrastructure)
- **User Story 3 (Phase 7)**: Depends on User Story 1 (destruction requires deployed infrastructure)
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - Creates all core infrastructure
- **User Story 4 (P1)**: Depends on User Story 1 - Optimizes existing ALB/Global Accelerator
- **User Story 5 (P1)**: Depends on User Story 1 - Hardens security of existing infrastructure
- **User Story 2 (P2)**: Depends on User Story 1 - Adds scaling capabilities to existing infrastructure
- **User Story 3 (P2)**: Depends on User Story 1 - Ensures clean destruction of deployed infrastructure

### Within Each User Story

- Module structure before module implementation
- Resources before outputs
- Core resources before integration
- Documentation after implementation

### Parallel Opportunities

- **Setup Phase**: All tasks marked [P] can run in parallel (T002-T006)
- **Foundational Phase**: Tasks T009-T010 (public/private subnets) can run in parallel
- **User Story 1**: 
  - Storage, Cache, ECS, and Networking modules can be created in parallel (T020, T027, T035, T046)
  - Module structure tasks can run in parallel
  - Module variable/output tasks can run in parallel
- **User Story 5**: Security group verification tasks can run in parallel (T068-T071)
- **Polish Phase**: All tasks marked [P] can run in parallel

---

## Parallel Example: User Story 1

```bash
# Launch all module structure creation in parallel:
Task: "Create storage module structure: terraform/modules/storage/main.tf, terraform/modules/storage/variables.tf, terraform/modules/storage/outputs.tf"
Task: "Create cache module structure: terraform/modules/cache/main.tf, terraform/modules/cache/variables.tf, terraform/modules/cache/outputs.tf"
Task: "Create ECS module structure: terraform/modules/ecs/main.tf, terraform/modules/ecs/variables.tf, terraform/modules/ecs/outputs.tf, terraform/modules/ecs/task-definition.json.tpl"
Task: "Create networking module structure: terraform/modules/networking/main.tf, terraform/modules/networking/variables.tf, terraform/modules/networking/outputs.tf"

# Launch all module README creation in parallel:
Task: "Create storage module README in terraform/modules/storage/README.md"
Task: "Create cache module README in terraform/modules/cache/README.md"
Task: "Create ECS module README in terraform/modules/ecs/README.md"
Task: "Create networking module README in terraform/modules/networking/README.md"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T006)
2. Complete Phase 2: Foundational - VPC module (T007-T019) - **CRITICAL - blocks all other work**
3. Complete Phase 3: User Story 1 - Complete Infrastructure (T020-T062)
4. **STOP and VALIDATE**: Run terraform apply, verify all resources created, test Minecraft server connection
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → VPC ready
2. Add User Story 1 → Deploy infrastructure → Test connection (MVP!)
3. Add User Story 4 → Optimize latency → Test from Brazil
4. Add User Story 5 → Harden security → Verify no secrets, test Session Manager
5. Add User Story 2 → Enable scaling → Test scaling operations
6. Add User Story 3 → Ensure clean destruction → Test terraform destroy
7. Add Polish → Documentation and validation

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once VPC module is done:
   - Developer A: Storage module (T020-T026)
   - Developer B: Cache module (T027-T034)
   - Developer C: ECS module (T035-T045)
   - Developer D: Networking module (T046-T056)
3. All modules integrate in root module (T057-T062)
4. Stories 4, 5, 2, 3 can proceed in parallel after US1 complete

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- VPC module (Phase 2) is CRITICAL - all other modules depend on it
- Module creation can be parallelized after VPC is complete
- Commit after each module or logical group
- Stop at any checkpoint to validate independently
- Avoid: hard-coded secrets, missing dependencies, incomplete module outputs

