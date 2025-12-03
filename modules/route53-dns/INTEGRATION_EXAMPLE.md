# Integration Example: Route 53 DNS Module with Minecraft Infrastructure

This document shows how to integrate the Route 53 DNS module with the existing Minecraft infrastructure.

## Basic Integration

Add the Route 53 DNS module to your root Terraform configuration (`main.tf`):

```hcl
# Route 53 DNS Module - Creates DNS record for Minecraft server
module "minecraft_dns" {
  source = "./modules/route53-dns"

  domain_name     = var.domain_name  # e.g., "example.com"
  subdomain       = var.minecraft_subdomain  # e.g., "mc" (optional, null for apex)
  record_type     = "alias"
  target_endpoint = var.enable_global_accelerator ? aws_globalaccelerator_accelerator.main[0].dns_name : module.networking.alb_dns_name

  tags = var.tags
}
```

## Output Integration

Add DNS outputs to your root `outputs.tf`:

```hcl
output "minecraft_server_hostname" {
  description = "Minecraft server hostname for player connections"
  value       = module.minecraft_dns.fqdn
}

output "minecraft_dns_record_name" {
  description = "Route 53 DNS record name"
  value       = module.minecraft_dns.record_name
}
```

## Variable Integration

Add DNS-related variables to your root `variables.tf`:

```hcl
variable "domain_name" {
  description = "Root domain name for DNS record (e.g., example.com)"
  type        = string
  default     = null  # Optional - only needed if using DNS module
}

variable "minecraft_subdomain" {
  description = "Subdomain for Minecraft server (e.g., 'mc' creates 'mc.example.com'). Set to null for apex domain."
  type        = string
  default     = null
}
```

## Conditional Integration

Only create DNS record if domain_name is provided:

```hcl
# Route 53 DNS Module - Only create if domain_name is provided
module "minecraft_dns" {
  source = "./modules/route53-dns"

  count = var.domain_name != null ? 1 : 0

  domain_name     = var.domain_name
  subdomain       = var.minecraft_subdomain
  record_type     = "alias"
  target_endpoint = var.enable_global_accelerator ? aws_globalaccelerator_accelerator.main[0].dns_name : module.networking.alb_dns_name

  tags = var.tags
}

# Conditional output
output "minecraft_server_hostname" {
  description = "Minecraft server hostname for player connections"
  value       = var.domain_name != null ? module.minecraft_dns[0].fqdn : module.networking.alb_dns_name
}
```

## Complete Example

See `main.tf` for a complete integration example with all modules.

