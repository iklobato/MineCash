# Quick Start Guide: AWS Minecraft Server Infrastructure

**Date**: 2024-12-19  
**Feature**: AWS Minecraft Server Infrastructure  
**Purpose**: Step-by-step guide to deploy the Minecraft server infrastructure

## Prerequisites

### Required Tools
- **Terraform** >= 1.0 installed ([Installation Guide](https://developer.hashicorp.com/terraform/downloads))
- **AWS CLI** >= 2.0 installed and configured ([Installation Guide](https://aws.amazon.com/cli/))
- **AWS Account** with appropriate permissions
- **Git** (for cloning repository)

### AWS Permissions Required
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

### AWS Service Quotas
Ensure your AWS account has sufficient quotas:
- VPCs per region: At least 1
- NAT Gateways per AZ: At least 1
- ECS tasks: At least 10 (for scaling)
- ElastiCache clusters: At least 1

---

## Step 1: Clone and Navigate

```bash
# Clone the repository (if applicable)
git clone <repository-url>
cd minecraft/terraform

# Or navigate to terraform directory if already cloned
cd terraform
```

---

## Step 2: Configure AWS Credentials

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

---

## Step 3: Configure Terraform Backend (Optional but Recommended)

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

---

## Step 4: Create Redis Auth Token Secret

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

---

## Step 5: Configure Variables

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

---

## Step 6: Initialize Terraform

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

---

## Step 7: Review Plan

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

---

## Step 8: Deploy Infrastructure

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

---

## Step 9: Verify Deployment

### Check Terraform Outputs

```bash
terraform output
```

**Expected outputs**:
- `minecraft_endpoint`: Public endpoint for players
- `redis_endpoint`: Redis cluster endpoint
- `efs_dns_name`: EFS DNS name
- `vpc_id`: VPC ID
- `ecs_cluster_id`: ECS cluster ID

### Verify ECS Service

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

### Test Minecraft Server Connection

```bash
# Get endpoint
ENDPOINT=$(terraform output -raw minecraft_endpoint)

# Test connection (Minecraft uses TCP port 25565)
nc -zv $ENDPOINT 25565

# Or use Minecraft client to connect
# Server Address: $ENDPOINT
# Port: 25565
```

---

## Step 10: Access Container (Troubleshooting)

### Using AWS Systems Manager Session Manager

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

---

## Common Issues and Solutions

### Issue: NAT Gateway Creation Fails

**Error**: `Error creating NAT Gateway: InsufficientAddressesInSubnet`

**Solution**: Ensure public subnet has available IP addresses. Use smaller CIDR blocks or create additional subnets.

---

### Issue: ElastiCache Creation Takes Too Long

**Error**: ElastiCache cluster creation times out

**Solution**: This is normal - ElastiCache can take 10-15 minutes. Wait for completion or check AWS Console.

---

### Issue: ECS Task Fails to Start

**Error**: Task stops immediately after starting

**Solution**:
1. Check CloudWatch Logs: `aws logs tail /ecs/minecraft-server --follow`
2. Verify container image exists and is accessible
3. Check EFS mount: Ensure EFS security group allows NFS from ECS security group
4. Verify task has sufficient CPU/memory

---

### Issue: Cannot Connect to Minecraft Server

**Error**: Connection timeout

**Solution**:
1. Verify ALB security group allows inbound TCP 25565 from 0.0.0.0/0
2. Check ECS task is running: `aws ecs describe-tasks --cluster <cluster> --tasks <task-id>`
3. Verify target group health: Check ALB target group in AWS Console
4. Check Global Accelerator status (if enabled)

---

## Next Steps

### Configure Minecraft Server

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

### Monitor Infrastructure

- **CloudWatch Logs**: `/ecs/minecraft-server`
- **CloudWatch Metrics**: ECS service metrics, ALB metrics
- **Cost Monitoring**: AWS Cost Explorer, tag-based filtering

### Scale Infrastructure

Edit `terraform.tfvars`:
```hcl
desired_count = 3  # Increase number of containers
```

Apply changes:
```bash
terraform apply
```

---

## Cleanup (Destroy Infrastructure)

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

---

## Additional Resources

- **Terraform AWS Provider Documentation**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- **ECS Fargate Documentation**: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html
- **Minecraft Server Docker Image**: https://hub.docker.com/r/itzg/minecraft-server
- **AWS Global Accelerator**: https://docs.aws.amazon.com/global-accelerator/

---

## Support

For issues or questions:
1. Check Terraform plan output for errors
2. Review AWS CloudWatch Logs
3. Verify AWS service quotas
4. Consult Terraform and AWS documentation


