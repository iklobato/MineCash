# Quick Start: Route 53 DNS Module

**Feature**: Route 53 DNS Module for Minecraft Server  
**Date**: 2024-12-19

## Prerequisites

- Terraform >= 1.0 installed
- AWS Provider >= 5.0 configured
- AWS credentials configured (via AWS CLI, environment variables, or IAM role)
- Existing Route 53 hosted zone for your domain
- IAM permissions: `route53:GetHostedZone`, `route53:ListHostedZones`, `route53:ChangeResourceRecordSets`, `route53:GetChange`

## Quick Start

### Step 1: Add Module to Your Terraform Configuration

Add the Route 53 DNS module to your root Terraform configuration (e.g., `terraform/main.tf`):

```hcl
module "minecraft_dns" {
  source = "./modules/route53-dns"

  domain_name     = "example.com"
  subdomain       = "mc"
  record_type     = "alias"
  target_endpoint = module.networking.global_accelerator_dns_name

  tags = {
    Environment = "production"
    Project     = "minecraft"
  }
}
```

### Step 2: Initialize Terraform

```bash
cd terraform
terraform init
```

### Step 3: Review Plan

```bash
terraform plan
```

Verify that:
- Hosted zone is found (or provide `hosted_zone_id` if multiple zones exist)
- DNS record will be created with correct name and target
- No errors or warnings

### Step 4: Apply Configuration

```bash
terraform apply
```

### Step 5: Verify DNS Record

```bash
# Get the FQDN output
terraform output -json | jq -r '.minecraft_dns_fqdn.value'

# Test DNS resolution
dig mc.example.com
nslookup mc.example.com
```

## Common Use Cases

### Use Case 1: Subdomain with ALB

Create `mc.example.com` pointing to an Application Load Balancer:

```hcl
module "minecraft_dns" {
  source = "./modules/route53-dns"

  domain_name     = "example.com"
  subdomain       = "mc"
  record_type     = "alias"
  target_endpoint = module.networking.alb_dns_name
}
```

### Use Case 2: Apex Domain with Global Accelerator

Create `example.com` pointing to Global Accelerator:

```hcl
module "minecraft_dns" {
  source = "./modules/route53-dns"

  domain_name     = "example.com"
  subdomain       = null  # Apex domain
  record_type     = "alias"
  target_endpoint = module.networking.global_accelerator_dns_name
}
```

### Use Case 3: IPv4 Address (A Record)

Create `mc.example.com` pointing to a static IPv4 address:

```hcl
module "minecraft_dns" {
  source = "./modules/route53-dns"

  domain_name     = "example.com"
  subdomain       = "mc"
  record_type     = "A"
  target_endpoint = "203.0.113.10"
  ttl             = 300
}
```

### Use Case 4: Multiple Environments

Create DNS records for dev, staging, and production:

```hcl
# Development
module "minecraft_dns_dev" {
  source = "./modules/route53-dns"

  domain_name     = "example.com"
  subdomain       = "mc-dev"
  record_type     = "alias"
  target_endpoint = module.networking_dev.alb_dns_name

  tags = {
    Environment = "development"
  }
}

# Staging
module "minecraft_dns_staging" {
  source = "./modules/route53-dns"

  domain_name     = "example.com"
  subdomain       = "mc-staging"
  record_type     = "alias"
  target_endpoint = module.networking_staging.alb_dns_name

  tags = {
    Environment = "staging"
  }
}

# Production
module "minecraft_dns_prod" {
  source = "./modules/route53-dns"

  domain_name     = "example.com"
  subdomain       = "mc"
  record_type     = "alias"
  target_endpoint = module.networking_prod.global_accelerator_dns_name

  tags = {
    Environment = "production"
  }
}
```

## Integration with Existing Infrastructure

### Using with Minecraft Infrastructure Module

The Route 53 DNS module integrates seamlessly with the existing Minecraft infrastructure:

```hcl
# Existing Minecraft infrastructure
module "minecraft" {
  source = "./modules/minecraft-infrastructure"
  
  # ... existing configuration ...
}

# Add DNS record
module "minecraft_dns" {
  source = "./modules/route53-dns"

  domain_name     = var.domain_name
  subdomain       = var.minecraft_subdomain
  record_type     = "alias"
  target_endpoint = module.minecraft.global_accelerator_dns_name

  tags = var.tags
}

# Output FQDN for player connections
output "minecraft_server_hostname" {
  description = "Minecraft server hostname for player connections"
  value       = module.minecraft_dns.fqdn
}
```

## Troubleshooting

### Error: "No public hosted zone found for domain"

**Cause**: No Route 53 hosted zone exists for the domain, or only private zones exist.

**Solution**:
1. Create a public hosted zone in Route 53 for your domain
2. Or provide explicit `hosted_zone_id` if zone exists in another account

```hcl
module "minecraft_dns" {
  # ...
  hosted_zone_id = "Z1234567890ABC"  # Explicit zone ID
}
```

### Error: "Multiple public hosted zones found"

**Cause**: Multiple public hosted zones exist for the same domain.

**Solution**: Provide explicit `hosted_zone_id`:

```hcl
module "minecraft_dns" {
  # ...
  hosted_zone_id = "Z1234567890ABC"  # Choose the correct zone
}
```

### Error: "target_endpoint format does not match record_type"

**Cause**: The `target_endpoint` format doesn't match the specified `record_type`.

**Solution**: Ensure correct combination:
- `record_type = "alias"` → DNS name (e.g., ALB DNS name)
- `record_type = "A"` → IPv4 address (e.g., "203.0.113.10")
- `record_type = "AAAA"` → IPv6 address (e.g., "2001:0db8::1")

### DNS Not Resolving

**Cause**: DNS propagation delay or incorrect configuration.

**Solution**:
1. Wait 60 seconds for DNS propagation (Route 53 typically propagates quickly)
2. Verify record was created: `aws route53 list-resource-record-sets --hosted-zone-id Z1234567890ABC`
3. Check DNS resolution: `dig mc.example.com` or `nslookup mc.example.com`
4. Verify target endpoint is correct and accessible

## Next Steps

- Review [data-model.md](./data-model.md) for detailed entity definitions
- Review [contracts/variables-schema.md](./contracts/variables-schema.md) for complete variable documentation
- Review [research.md](./research.md) for technical decisions and rationale
- See module README for detailed usage examples and advanced configuration

