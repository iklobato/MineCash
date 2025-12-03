# Variables Schema: Route 53 DNS Module

**Feature**: Route 53 DNS Module for Minecraft Server  
**Date**: 2024-12-19

## Overview

This document defines the input and output variable schemas for the Route 53 DNS Terraform module. All variables include type information, descriptions, defaults, validation rules, and usage examples.

## Input Variables

### domain_name

**Type**: `string`  
**Required**: Yes  
**Description**: Root domain name for DNS record creation (e.g., "example.com"). The module will create a record in the hosted zone for this domain.

**Validation**:
- Must be 1-253 characters
- Must comply with RFC 1123 (valid DNS name format)
- Cannot contain trailing dots (will be normalized)
- Cannot start or end with hyphen or dot

**Example**:
```hcl
domain_name = "example.com"
```

**Normalization**: Trailing dots are automatically removed.

---

### subdomain

**Type**: `string`  
**Required**: No  
**Default**: `null`  
**Description**: Subdomain prefix to prepend to the domain name. When provided, creates a subdomain record (e.g., "mc" creates "mc.example.com"). When omitted or empty, creates an apex domain record (e.g., "example.com").

**Validation**:
- Must be 1-63 characters per label
- Must comply with RFC 1123 (valid DNS name format)
- Cannot contain trailing dots (will be normalized)
- Cannot start or end with hyphen or dot

**Example**:
```hcl
subdomain = "mc"  # Creates mc.example.com
subdomain = null  # Creates example.com (apex)
subdomain = ""    # Creates example.com (apex)
```

---

### record_type

**Type**: `string`  
**Required**: Yes  
**Description**: Type of DNS record to create. Must be one of:
- `"alias"`: Alias record for AWS resources (ALB, Global Accelerator, CloudFront)
- `"A"`: A record for IPv4 addresses
- `"AAAA"`: AAAA record for IPv6 addresses

**Validation**:
- Must be exactly one of: `"alias"`, `"A"`, `"AAAA"`
- Case-sensitive (lowercase required)

**Example**:
```hcl
record_type = "alias"  # For ALB or Global Accelerator DNS names
record_type = "A"      # For IPv4 addresses
record_type = "AAAA"   # For IPv6 addresses
```

---

### target_endpoint

**Type**: `string`  
**Required**: Yes  
**Description**: The Minecraft server endpoint to which the DNS record should point. Format must match `record_type`:
- For `record_type = "alias"`: DNS name (e.g., ALB DNS name, Global Accelerator DNS name)
- For `record_type = "A"`: IPv4 address (e.g., "203.0.113.10")
- For `record_type = "AAAA"`: IPv6 address (e.g., "2001:0db8::1")

**Validation**:
- For alias: Must be DNS name format (contains dots, not IP format)
- For A: Must be valid IPv4 address format (xxx.xxx.xxx.xxx)
- For AAAA: Must be valid IPv6 address format

**Example**:
```hcl
# Alias record
target_endpoint = "minecraft-alb-123456789.us-east-1.elb.amazonaws.com"
target_endpoint = "a1234567890-1234567890.awsglobalaccelerator.com"

# A record (IPv4)
target_endpoint = "203.0.113.10"

# AAAA record (IPv6)
target_endpoint = "2001:0db8:85a3:0000:0000:8a2e:0370:7334"
```

---

### hosted_zone_id

**Type**: `string`  
**Required**: No  
**Default**: `null`  
**Description**: Explicit Route 53 hosted zone ID. When provided, bypasses automatic hosted zone lookup. Required when multiple public hosted zones exist for the same domain.

**Validation**:
- Must be valid Route 53 hosted zone ID format (starts with "Z")
- If provided, must correspond to a hosted zone for `domain_name`

**Example**:
```hcl
hosted_zone_id = "Z1234567890ABC"
```

**Usage**: Provide when:
- Multiple public hosted zones exist for the domain
- Cross-account hosted zone access
- Explicit zone control is needed

---

### ttl

**Type**: `number`  
**Required**: No  
**Default**: `300`  
**Description**: Time-to-live (TTL) in seconds for A and AAAA records. Alias records do not use TTL (they are always evaluated dynamically by Route 53).

**Validation**:
- Must be between 60 and 2147483647 (Route 53 limits)
- Only applicable when `record_type = "A"` or `record_type = "AAAA"`

**Example**:
```hcl
ttl = 300   # 5 minutes (default)
ttl = 60    # 1 minute (faster updates, more DNS queries)
ttl = 3600  # 1 hour (longer caching, fewer DNS queries)
```

---

### evaluate_target_health_override

**Type**: `bool`  
**Required**: No  
**Default**: `null`  
**Description**: Override for alias record `evaluate_target_health` attribute. When provided, overrides auto-configuration based on endpoint pattern. Only applicable when `record_type = "alias"`.

**Auto-Configuration**:
- ALB endpoints: `true` (default)
- Global Accelerator endpoints: `false` (default)
- CloudFront endpoints: `false` (default)

**Example**:
```hcl
evaluate_target_health_override = true   # Force health evaluation
evaluate_target_health_override = false  # Disable health evaluation
```

---

### zone_id_override

**Type**: `string`  
**Required**: No  
**Default**: `null`  
**Description**: Override for alias record `zone_id` attribute. When provided, overrides auto-configuration based on endpoint pattern. Only applicable when `record_type = "alias"`.

**Auto-Configuration**:
- ALB endpoints: Uses ALB hosted zone ID (looked up by region)
- Global Accelerator endpoints: Uses Global Accelerator zone ID (`Z2BJ6XQ5FK7U4H`)
- CloudFront endpoints: Uses CloudFront zone ID (`Z2FDTNDATAQYW2`)

**Example**:
```hcl
zone_id_override = "Z1234567890ABC"  # Custom zone ID
```

---

### tags

**Type**: `map(string)`  
**Required**: No  
**Default**: `{}`  
**Description**: Additional tags to apply to the Route 53 DNS record resource. Useful for cost tracking, resource organization, and filtering.

**Example**:
```hcl
tags = {
  Environment = "production"
  Project     = "minecraft"
  ManagedBy   = "terraform"
}
```

## Output Variables

### fqdn

**Type**: `string`  
**Description**: Fully-qualified domain name (FQDN) of the created DNS record. This is the hostname that players use to connect to the Minecraft server.

**Example**:
```hcl
fqdn = "mc.example.com"      # When subdomain provided
fqdn = "example.com"          # When apex domain
```

**Usage**:
- Player connection hostname
- Integration with other Terraform modules
- Documentation and user-facing output

---

### record_name

**Type**: `string`  
**Description**: Route 53 record name (may include trailing dot, as Route 53 stores it). Useful for reference in other Route 53 operations or debugging.

**Example**:
```hcl
record_name = "mc.example.com."     # With trailing dot
record_name = "example.com."       # Apex domain with trailing dot
```

**Usage**:
- Reference for Route 53 API operations
- Debugging and troubleshooting
- Integration with Route 53-specific tools

## Variable Dependencies

### Required Combinations

1. **Alias Record**:
   - `record_type = "alias"`
   - `target_endpoint` = DNS name (ALB, Global Accelerator, CloudFront)
   - `ttl` = ignored (not used for alias records)

2. **A Record**:
   - `record_type = "A"`
   - `target_endpoint` = IPv4 address
   - `ttl` = number (default: 300)

3. **AAAA Record**:
   - `record_type = "AAAA"`
   - `target_endpoint` = IPv6 address
   - `ttl` = number (default: 300)

### Validation Rules

- `target_endpoint` format must match `record_type`
- `ttl` only applicable for A/AAAA records
- `evaluate_target_health_override` and `zone_id_override` only applicable for alias records
- `hosted_zone_id` must correspond to `domain_name` if provided

## Usage Examples

### Example 1: Subdomain with ALB Alias

```hcl
module "minecraft_dns" {
  source = "./modules/route53-dns"

  domain_name     = "example.com"
  subdomain       = "mc"
  record_type     = "alias"
  target_endpoint = module.networking.alb_dns_name

  tags = {
    Environment = "production"
  }
}
```

### Example 2: Apex Domain with Global Accelerator

```hcl
module "minecraft_dns" {
  source = "./modules/route53-dns"

  domain_name     = "example.com"
  subdomain       = null  # Apex domain
  record_type     = "alias"
  target_endpoint = module.networking.global_accelerator_dns_name

  tags = {
    Environment = "production"
  }
}
```

### Example 3: IPv4 Address (A Record)

```hcl
module "minecraft_dns" {
  source = "./modules/route53-dns"

  domain_name     = "example.com"
  subdomain       = "mc"
  record_type     = "A"
  target_endpoint = "203.0.113.10"
  ttl             = 300

  tags = {
    Environment = "production"
  }
}
```

### Example 4: IPv6 Address (AAAA Record)

```hcl
module "minecraft_dns" {
  source = "./modules/route53-dns"

  domain_name     = "example.com"
  subdomain       = "mc"
  record_type     = "AAAA"
  target_endpoint = "2001:0db8:85a3:0000:0000:8a2e:0370:7334"
  ttl             = 300

  tags = {
    Environment = "production"
  }
}
```

### Example 5: Explicit Hosted Zone ID

```hcl
module "minecraft_dns" {
  source = "./modules/route53-dns"

  domain_name     = "example.com"
  subdomain       = "mc"
  record_type     = "alias"
  target_endpoint = module.networking.alb_dns_name
  hosted_zone_id  = "Z1234567890ABC"  # Explicit zone ID

  tags = {
    Environment = "production"
  }
}
```

