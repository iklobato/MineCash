# Route 53 DNS Module

Creates Route 53 DNS records for Minecraft server endpoints. Supports alias records (for AWS resources like ALB, Global Accelerator, CloudFront) and A/AAAA records (for IPv4/IPv6 addresses). Automatically looks up hosted zones or accepts explicit zone IDs.

## Usage

### Subdomain with ALB

```hcl
module "minecraft_dns" {
  source = "./modules/route53-dns"

  domain_name     = "example.com"
  subdomain       = "mc"
  record_type     = "alias"
  target_endpoint = module.networking.alb_dns_name

  tags = {
    Environment = "production"
    Project     = "minecraft"
  }
}
```

### Apex Domain with Global Accelerator

```hcl
module "minecraft_dns" {
  source = "./modules/route53-dns"

  domain_name     = "example.com"
  subdomain       = null  # Apex domain
  record_type     = "alias"
  target_endpoint = module.networking.global_accelerator_dns_name
}
```

### IPv4 Address (A Record)

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

### IPv6 Address (AAAA Record)

```hcl
module "minecraft_dns" {
  source = "./modules/route53-dns"

  domain_name     = "example.com"
  subdomain       = "mc"
  record_type     = "AAAA"
  target_endpoint = "2001:0db8:85a3:0000:0000:8a2e:0370:7334"
  ttl             = 300
}
```

### Explicit Hosted Zone ID

```hcl
module "minecraft_dns" {
  source = "./modules/route53-dns"

  domain_name     = "example.com"
  subdomain       = "mc"
  record_type     = "alias"
  target_endpoint = module.networking.alb_dns_name
  hosted_zone_id  = "Z1234567890ABC"  # Explicit zone ID when multiple zones exist
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| domain_name | Root domain name for DNS record creation (e.g., example.com) | `string` | n/a | yes |
| subdomain | Subdomain prefix (e.g., 'mc' creates 'mc.example.com'). When null or empty, creates apex domain record | `string` | `null` | no |
| record_type | Type of DNS record: 'alias' (AWS resources), 'A' (IPv4), or 'AAAA' (IPv6) | `string` | n/a | yes |
| target_endpoint | Minecraft server endpoint: DNS name for alias, IPv4 for A, IPv6 for AAAA | `string` | n/a | yes |
| hosted_zone_id | Explicit Route 53 hosted zone ID. When provided, bypasses automatic lookup | `string` | `null` | no |
| ttl | Time-to-live in seconds for A/AAAA records (alias records don't use TTL) | `number` | `300` | no |
| evaluate_target_health_override | Override for alias evaluate_target_health (overrides auto-configuration) | `bool` | `null` | no |
| zone_id_override | Override for alias zone_id (overrides auto-configuration) | `string` | `null` | no |
| tags | Additional tags to apply to the DNS record resource | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| fqdn | Fully-qualified domain name (FQDN) of the created DNS record (e.g., mc.example.com or example.com) |
| record_name | Route 53 record name (may include trailing dot, as Route 53 stores it) |

## Resources Created

- 1 Route 53 DNS Record (alias, A, or AAAA type)

## Features

- **Automatic Hosted Zone Lookup**: Automatically finds public hosted zones for your domain
- **Alias Record Auto-Configuration**: Automatically configures alias attributes based on endpoint pattern (ALB, Global Accelerator, CloudFront)
- **Multiple Record Types**: Supports alias (AWS resources), A (IPv4), and AAAA (IPv6) records
- **Domain Normalization**: Automatically normalizes domain names (removes trailing dots, lowercases)
- **Comprehensive Validation**: Validates domain names, record types, and endpoint formats
- **Error Handling**: Clear error messages for missing zones, ambiguous zones, and format mismatches

## Alias Record Auto-Configuration

The module automatically configures alias record attributes based on the `target_endpoint` pattern:

- **ALB endpoints** (`.elb.amazonaws.com`): `evaluate_target_health = true`, uses ALB zone_id (looked up by region)
- **Global Accelerator endpoints** (`.awsglobalaccelerator.com`): `evaluate_target_health = false`, uses Global Accelerator zone_id (`Z2BJ6XQ5FK7U4H`)
- **CloudFront endpoints** (`.cloudfront.net`): `evaluate_target_health = false`, uses CloudFront zone_id (`Z2FDTNDATAQYW2`)

Override variables (`evaluate_target_health_override`, `zone_id_override`) allow advanced customization when auto-configuration is insufficient.

## Hosted Zone Lookup

When `hosted_zone_id` is not provided, the module automatically looks up public hosted zones for the domain:

- Queries Route 53 for zones matching `domain_name`
- Filters to public zones only (`private_zone = false`)
- If exactly one public zone exists: Uses it automatically
- If multiple public zones exist: Errors with clear message requiring explicit `hosted_zone_id`
- If no public zones exist: Errors with clear message

## Integration with Minecraft Infrastructure

The module integrates seamlessly with the existing Minecraft infrastructure module:

```hcl
# Existing Minecraft infrastructure
module "minecraft" {
  source = "./modules/minecraft-infrastructure"
  
  # ... configuration ...
}

# Add DNS record pointing to Global Accelerator
module "minecraft_dns" {
  source = "./modules/route53-dns"

  domain_name     = "example.com"
  subdomain       = "mc"
  record_type     = "alias"
  target_endpoint = module.minecraft.global_accelerator_dns_name

  tags = {
    Environment = "production"
  }
}

# Output FQDN for player connections
output "minecraft_server_hostname" {
  description = "Minecraft server hostname for player connections"
  value       = module.minecraft_dns.fqdn
}
```

## Validation

The module validates all inputs:

- **Domain Name**: RFC 1123 compliant, 1-253 characters, cannot start/end with hyphen or dot
- **Subdomain**: RFC 1123 compliant, 1-63 characters per label, cannot start/end with hyphen
- **Record Type**: Must be exactly one of: `"alias"`, `"A"`, `"AAAA"`
- **Target Endpoint**: Format must match record_type (DNS name for alias, IPv4 for A, IPv6 for AAAA)
- **TTL**: Must be between 60 and 2147483647 seconds (Route 53 limits)
- **Hosted Zone ID**: Must be valid Route 53 zone ID format (starts with "Z")

## Error Handling

The module provides clear error messages for common scenarios:

- **No hosted zone found**: "No public hosted zone found for domain 'example.com'. Create a hosted zone or provide explicit hosted_zone_id."
- **Multiple hosted zones**: Terraform will error if multiple public zones exist (provide explicit `hosted_zone_id`)
- **Format mismatch**: "target_endpoint format does not match record_type 'alias'. Expected DNS name, got: '203.0.113.10'."
- **Missing alias zone_id**: "Unable to determine zone_id for alias record. Ensure target_endpoint is a recognized AWS resource (ALB, Global Accelerator, or CloudFront) or provide zone_id_override."

## Notes

- Domain names are automatically normalized (trailing dots removed, lowercased)
- Alias records don't use TTL (they are always evaluated dynamically by Route 53)
- The module assumes hosted zones are managed outside this module (created manually or via other Terraform)
- Route 53 DNS propagation typically completes within 60 seconds
- For cross-account hosted zones, provide explicit `hosted_zone_id`

## Troubleshooting

### Error: "No public hosted zone found"

**Solution**: Create a public hosted zone in Route 53 for your domain, or provide explicit `hosted_zone_id` if the zone exists in another account.

### Error: Multiple public hosted zones found

**Solution**: Provide explicit `hosted_zone_id` to disambiguate:

```hcl
hosted_zone_id = "Z1234567890ABC"
```

### Error: "target_endpoint format does not match record_type"

**Solution**: Ensure correct combination:
- `record_type = "alias"` → DNS name (e.g., ALB DNS name)
- `record_type = "A"` → IPv4 address (e.g., "203.0.113.10")
- `record_type = "AAAA"` → IPv6 address (e.g., "2001:0db8::1")

### DNS Not Resolving

**Solution**:
1. Wait 60 seconds for DNS propagation
2. Verify record exists: `aws route53 list-resource-record-sets --hosted-zone-id Z1234567890ABC`
3. Test DNS resolution: `dig mc.example.com` or `nslookup mc.example.com`
4. Verify target endpoint is correct and accessible
