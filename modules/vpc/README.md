# VPC Module

Creates a VPC with public and private subnets across multiple Availability Zones, including Internet Gateway, NAT Gateways, and route tables.

## Usage

```hcl
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr            = "10.0.0.0/16"
  availability_zones   = ["sa-east-1a", "sa-east-1b"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
  project_name        = "minecraft"
  environment         = "production"
  tags                 = {}
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| vpc_cidr | CIDR block for VPC | `string` | n/a | yes |
| availability_zones | List of availability zones to use | `list(string)` | n/a | yes |
| public_subnet_cidrs | List of CIDR blocks for public subnets (one per AZ) | `list(string)` | n/a | yes |
| private_subnet_cidrs | List of CIDR blocks for private subnets (one per AZ) | `list(string)` | n/a | yes |
| project_name | Project name used for resource naming (e.g., 'minecraft') | `string` | n/a | yes |
| environment | Environment name used for resource naming and tagging (e.g., 'production', 'staging') | `string` | n/a | yes |
| tags | Additional tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | VPC ID |
| public_subnet_ids | List of public subnet IDs |
| private_subnet_ids | List of private subnet IDs |
| nat_gateway_id | NAT Gateway ID (first one) |
| nat_gateway_ids | List of all NAT Gateway IDs |
| internet_gateway_id | Internet Gateway ID |

## Resources Created

- 1 VPC
- 2+ Public Subnets (one per AZ)
- 2+ Private Subnets (one per AZ)
- 1 Internet Gateway
- 2+ NAT Gateways (one per AZ)
- 1 Public Route Table
- 2+ Private Route Tables (one per AZ)
- Route Table Associations

## Notes

- Public subnets route traffic via Internet Gateway
- Private subnets route traffic via NAT Gateway
- Minimum 2 Availability Zones required for high availability
- NAT Gateways are created in public subnets


