# Data Model: Route 53 DNS Module

**Feature**: Route 53 DNS Module for Minecraft Server  
**Date**: 2024-12-19

## Overview

This document defines the data structures, entities, and relationships for the Route 53 DNS module. The module manages DNS records in Route 53 hosted zones, mapping hostnames to Minecraft server endpoints.

## Entities

### DNS Record

**Description**: A Route 53 DNS record that maps a hostname (subdomain + domain or apex domain) to a Minecraft server endpoint.

**Attributes**:
- `name` (string): The DNS record name (e.g., "mc.example.com" or "example.com")
- `type` (string): Record type - "A" (IPv4), "AAAA" (IPv6), or "ALIAS" (AWS resource)
- `ttl` (number, optional): Time-to-live in seconds (only for A/AAAA records, default: 300)
- `target` (string): Target endpoint (DNS name for alias, IPv4 for A, IPv6 for AAAA)
- `alias` (object, optional): Alias configuration (only for alias records)
  - `name` (string): DNS name of the AWS resource
  - `zone_id` (string): Hosted zone ID for the AWS resource
  - `evaluate_target_health` (bool): Whether to evaluate target health

**Relationships**:
- Belongs to: Hosted Zone (via `hosted_zone_id`)
- References: Target Endpoint (via `target`)

**Validation Rules**:
- `name` must be valid DNS name (RFC 1123 compliant)
- `type` must be one of: "A", "AAAA", "ALIAS"
- `target` format must match `type`:
  - ALIAS: DNS name format (contains dots, not IP)
  - A: IPv4 address format (xxx.xxx.xxx.xxx)
  - AAAA: IPv6 address format
- `ttl` must be between 60 and 2147483647 (only for A/AAAA)
- `alias` attributes required when `type = "ALIAS"`

**State Transitions**:
- Created: DNS record created in Route 53
- Updated: DNS record modified (target, TTL, alias config changed)
- Deleted: DNS record removed from Route 53

### Hosted Zone

**Description**: An existing Route 53 hosted zone that contains DNS records for a domain. The module looks up or accepts this zone to create records within it.

**Attributes**:
- `id` (string): Route 53 hosted zone ID (e.g., "Z1234567890ABC")
- `name` (string): Domain name (e.g., "example.com")
- `type` (string): Zone type - "public" or "private"
- `name_servers` (list(string)): List of name servers for the zone

**Relationships**:
- Contains: DNS Records (one-to-many)
- Referenced by: DNS Record (via `hosted_zone_id`)

**Lookup Logic**:
- When `hosted_zone_id` not provided: Look up by `domain_name`, filter `private_zone = false`
- When multiple public zones exist: Error requiring explicit `hosted_zone_id`
- When no zones found: Error with clear message

**Validation Rules**:
- `name` must match provided `domain_name` (normalized, no trailing dot)
- `type` must be "public" (private zones not supported)

### Target Endpoint

**Description**: The Minecraft server's public endpoint that players connect to. Can be an AWS resource DNS name or an IP address.

**Types**:
1. **ALB DNS Name**: `minecraft-alb-123456789.us-east-1.elb.amazonaws.com`
   - Record Type: `alias`
   - Alias Config: `evaluate_target_health = true`, ALB zone_id
2. **Global Accelerator DNS Name**: `a1234567890-1234567890.awsglobalaccelerator.com`
   - Record Type: `alias`
   - Alias Config: `evaluate_target_health = false`, Global Accelerator zone_id
3. **Global Accelerator IP**: `203.0.113.10` (IPv4) or `2001:0db8::1` (IPv6)
   - Record Type: `A` or `AAAA`
   - Requires TTL
4. **CloudFront DNS Name**: `d1234567890.cloudfront.net`
   - Record Type: `alias`
   - Alias Config: `evaluate_target_health = false`, CloudFront zone_id

**Attributes**:
- `value` (string): The endpoint value (DNS name or IP address)
- `type` (string): Endpoint type - "alb", "global_accelerator_dns", "global_accelerator_ip", "cloudfront", "ipv4", "ipv6"

**Validation Rules**:
- DNS names: Must contain dots, valid DNS characters, not IP format
- IPv4: Must match IPv4 regex (xxx.xxx.xxx.xxx)
- IPv6: Must match IPv6 regex (valid IPv6 address format)

**Relationships**:
- Referenced by: DNS Record (via `target`)

## Data Flow

### Record Creation Flow

1. **Input**: `domain_name`, `subdomain` (optional), `record_type`, `target_endpoint`
2. **Normalization**: Remove trailing dots, lowercase, trim whitespace
3. **Validation**: Validate domain/subdomain format, record_type, target_endpoint format
4. **Hosted Zone Lookup**: Look up hosted zone by `domain_name` (or use provided `hosted_zone_id`)
5. **Record Name Construction**: Build record name (`subdomain.domain_name` or `domain_name` for apex)
6. **Alias Configuration** (if `record_type = "alias"`): Detect endpoint pattern, configure alias attributes
7. **Record Creation**: Create `aws_route53_record` resource with appropriate configuration
8. **Output**: Return FQDN and record name

### Hosted Zone Lookup Flow

1. **Input**: `domain_name`, `hosted_zone_id` (optional)
2. **If `hosted_zone_id` provided**: Use directly, validate it exists and matches domain
3. **If `hosted_zone_id` not provided**:
   - Query Route 53 for zones matching `domain_name`
   - Filter: `private_zone = false`
   - Count results:
     - 0 zones: Error "No public hosted zone found"
     - 1 zone: Use it
     - 2+ zones: Error "Multiple public hosted zones found, provide hosted_zone_id"

## Validation Rules Summary

### Domain Name Validation
- Length: 1-253 characters
- Format: RFC 1123 compliant
- Characters: Letters, numbers, hyphens, dots
- Cannot start/end with hyphen or dot
- Labels: 1-63 characters each

### Subdomain Validation
- Same rules as domain name
- Optional (null or empty string for apex domain)

### Record Type Validation
- Must be one of: `"alias"`, `"A"`, `"AAAA"`
- Case-sensitive (lowercase required)

### Target Endpoint Validation
- **For alias**: Must be DNS name format (contains dots, not IP)
- **For A**: Must be IPv4 format (xxx.xxx.xxx.xxx)
- **For AAAA**: Must be IPv6 format (valid IPv6 address)

### TTL Validation
- Only applicable for A and AAAA records
- Range: 60 to 2147483647 seconds
- Default: 300 seconds

## Terraform Resource Mapping

### aws_route53_record

**Resource**: `aws_route53_record.main`

**Configuration**:
```hcl
resource "aws_route53_record" "main" {
  zone_id = var.hosted_zone_id != null ? var.hosted_zone_id : data.aws_route53_zone.main[0].zone_id
  name    = local.record_name
  type    = var.record_type == "alias" ? "A" : var.record_type  # Alias records use type "A" in Route 53

  # For alias records
  dynamic "alias" {
    for_each = var.record_type == "alias" ? [1] : []
    content {
      name                   = var.target_endpoint
      zone_id                = local.alias_zone_id
      evaluate_target_health = local.evaluate_target_health
    }
  }

  # For A/AAAA records
  records = var.record_type != "alias" ? [var.target_endpoint] : null
  ttl     = var.record_type != "alias" ? var.ttl : null

  tags = var.tags
}
```

### data.aws_route53_zone

**Data Source**: `data.aws_route53_zone.main`

**Configuration**:
```hcl
data "aws_route53_zone" "main" {
  count        = var.hosted_zone_id == null ? 1 : 0
  name         = local.normalized_domain_name
  private_zone = false
}
```

## Output Schema

### fqdn (string)
- **Description**: Fully-qualified domain name of the created DNS record
- **Example**: `"mc.example.com"` or `"example.com"`
- **Usage**: Player connection hostname, integration with other modules

### record_name (string)
- **Description**: Route 53 record name (may include trailing dot)
- **Example**: `"mc.example.com."` or `"example.com."`
- **Usage**: Reference for other Route 53 operations

