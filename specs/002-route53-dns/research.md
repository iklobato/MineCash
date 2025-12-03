# Research: Route 53 DNS Module

**Feature**: Route 53 DNS Module for Minecraft Server  
**Date**: 2024-12-19  
**Status**: Complete

## Overview

This document captures technical research and decisions for implementing a Terraform module that creates Route 53 DNS records for Minecraft server endpoints. Research covers hosted zone lookup, alias record configuration, DNS record types, TTL settings, domain validation, and error handling.

## Research Areas

### 1. Route 53 Hosted Zone Lookup

**Decision**: Use `data.aws_route53_zone` data source with name filter to look up hosted zones. When multiple public zones exist, error requiring explicit `hosted_zone_id`.

**Rationale**:
- `data.aws_route53_zone` provides simple lookup by domain name
- Filtering by `private_zone = false` ensures only public zones are considered
- Erroring on ambiguity prevents incorrect record placement
- Explicit `hosted_zone_id` variable allows override for cross-account or ambiguous cases

**Alternatives Considered**:
- Auto-selecting first public zone: Rejected - non-deterministic, could place records in wrong zone
- Requiring explicit zone_id always: Rejected - adds friction for common single-zone case
- Using `data.aws_route53_zones` with filtering: Considered but `data.aws_route53_zone` is simpler for single-zone lookup

**Implementation Notes**:
- Use `name` parameter with domain name (normalized, no trailing dot)
- Set `private_zone = false` to filter public zones
- Validate that exactly one zone exists, or error with clear message
- Support optional `hosted_zone_id` variable to bypass lookup

### 2. Alias Record Configuration

**Decision**: Auto-configure alias record attributes (evaluate_target_health, zone_id) based on `target_endpoint` pattern, with optional override variables for advanced use cases.

**Rationale**:
- ALB endpoints require `evaluate_target_health = true` and ALB-specific zone_id
- Global Accelerator endpoints require `evaluate_target_health = false` and Global Accelerator zone_id
- Auto-configuration reduces configuration errors and simplifies usage
- Override variables provide flexibility for edge cases

**Pattern Detection**:
- ALB: `.elb.amazonaws.com` suffix → `evaluate_target_health = true`, use ALB zone_id lookup
- Global Accelerator: `.awsglobalaccelerator.com` suffix → `evaluate_target_health = false`, use Global Accelerator zone_id
- CloudFront: `.cloudfront.net` suffix → `evaluate_target_health = false`, use CloudFront zone_id

**Zone ID Lookup**:
- ALB: Use `data.aws_elb_hosted_zone_id` or `data.aws_lb_hosted_zone_id` based on ALB type
- Global Accelerator: Use hardcoded zone ID `Z2BJ6XQ5FK7U4H` (Global Accelerator zone ID)
- CloudFront: Use hardcoded zone ID `Z2FDTNDATAQYW2` (CloudFront zone ID)

**Alternatives Considered**:
- Requiring all alias attributes explicitly: Rejected - too verbose, error-prone
- Pattern detection only, no overrides: Rejected - lacks flexibility for edge cases
- Using AWS SDK to query resource metadata: Rejected - adds complexity, Terraform data sources sufficient

**Implementation Notes**:
- Detect endpoint pattern using `regex` or `endswith` functions
- Use conditional logic to set alias attributes
- Support `evaluate_target_health_override` and `zone_id_override` variables
- Validate that override variables are only used when `record_type = "alias"`

### 3. DNS Record Types

**Decision**: Support three record types via explicit `record_type` variable: `"alias"` (for AWS resources), `"A"` (for IPv4), `"AAAA"` (for IPv6).

**Rationale**:
- Explicit record type prevents ambiguity and configuration errors
- Supports all common Minecraft server endpoint types
- IPv6 support enables future-proofing without adding complexity

**Record Type Details**:
- **alias**: For AWS resources (ALB, Global Accelerator, CloudFront). No TTL (always evaluated dynamically).
- **A**: For IPv4 addresses. Requires TTL. Format validation: IPv4 regex.
- **AAAA**: For IPv6 addresses. Requires TTL. Format validation: IPv6 regex.

**Alternatives Considered**:
- Auto-detection based on endpoint format: Rejected - explicit is clearer, reduces errors
- Supporting only A and alias: Rejected - IPv6 support is valuable for future-proofing
- Supporting CNAME records: Rejected - alias records preferred for AWS resources, CNAME not needed for apex domains

**Implementation Notes**:
- Validate `record_type` is one of `"alias"`, `"A"`, or `"AAAA"`
- Validate `target_endpoint` format matches record_type:
  - alias: DNS name format (contains dots, no IP format)
  - A: IPv4 format (xxx.xxx.xxx.xxx)
  - AAAA: IPv6 format (valid IPv6 address)
- Use `aws_route53_record` resource with appropriate `type` and configuration

### 4. TTL Configuration

**Decision**: Configurable TTL variable with default of 300 seconds (5 minutes) for A and AAAA records. Alias records do not use TTL.

**Rationale**:
- 300 seconds balances DNS caching (reduces query load) with update responsiveness
- Configurable allows optimization for specific use cases (shorter for dynamic IPs, longer for static)
- Alias records are always evaluated dynamically by Route 53, so TTL doesn't apply

**TTL Best Practices**:
- Short TTL (60-300s): For frequently changing endpoints, faster propagation
- Medium TTL (300-3600s): For stable endpoints, balances caching and updates
- Long TTL (3600+): For very stable endpoints, reduces DNS query load

**Alternatives Considered**:
- Fixed TTL of 60 seconds: Rejected - too short, increases DNS query load
- Fixed TTL of 3600 seconds: Rejected - too long, slow updates
- No TTL variable (always use Route 53 default): Rejected - explicit control is better

**Implementation Notes**:
- Default `ttl = 300` in variables.tf
- Only apply TTL when `record_type = "A"` or `record_type = "AAAA"`
- Validate TTL is between 60 and 2147483647 (Route 53 limits)

### 5. Domain Name Normalization and Validation

**Decision**: Normalize domain names by removing trailing dots, validate format according to RFC 1123, validate subdomain format if provided.

**Rationale**:
- Trailing dots are valid in DNS but cause inconsistencies in Terraform
- RFC 1123 ensures compatibility with DNS standards
- Validation prevents invalid configurations before Terraform apply

**Normalization Rules**:
- Remove trailing dots from `domain_name` and `subdomain`
- Convert to lowercase (DNS is case-insensitive but consistency helps)
- Trim whitespace

**Validation Rules**:
- Domain name: 1-253 characters, valid DNS characters (letters, numbers, hyphens, dots), cannot start/end with hyphen or dot
- Subdomain: Same rules as domain name, 1-63 characters per label
- RFC 1123 compliance: Labels can contain letters, numbers, hyphens (not at start/end)

**Alternatives Considered**:
- No normalization: Rejected - trailing dots cause Terraform state issues
- Strict RFC 1035 validation: Rejected - RFC 1123 is more permissive and practical
- Allowing any string: Rejected - invalid domains cause Route 53 API errors

**Implementation Notes**:
- Use `trim` and `lower` functions for normalization
- Use `regex` validation in variables.tf
- Provide clear error messages for validation failures

### 6. Error Handling

**Decision**: Provide clear, actionable error messages for all failure scenarios: missing hosted zone, ambiguous zones, format mismatches, invalid configurations.

**Rationale**:
- Clear errors reduce debugging time and support burden
- Actionable messages tell users exactly what to fix
- Pre-validation prevents Terraform apply failures

**Error Scenarios**:
1. **Missing Hosted Zone**: "No public hosted zone found for domain 'example.com'. Create a hosted zone or provide explicit hosted_zone_id."
2. **Ambiguous Zones**: "Multiple public hosted zones found for domain 'example.com'. Provide explicit hosted_zone_id to disambiguate."
3. **Format Mismatch**: "target_endpoint format does not match record_type 'alias'. Expected DNS name, got IPv4 address."
4. **Invalid Record Type**: "record_type must be one of: alias, A, AAAA. Got: 'CNAME'."
5. **Invalid Domain Format**: "domain_name contains invalid characters. Must comply with RFC 1123."

**Alternatives Considered**:
- Generic Terraform errors: Rejected - unhelpful, increases support burden
- Warnings instead of errors: Rejected - invalid configs should fail fast
- No validation: Rejected - catches errors early, improves UX

**Implementation Notes**:
- Use Terraform `validation` blocks in variables.tf
- Use `precondition` blocks in main.tf for cross-variable validation
- Use `error` function for custom error messages
- Test error messages are clear and actionable

## Integration with Existing Infrastructure

### Input from Minecraft Infrastructure Module

The Route 53 DNS module can receive endpoints from the existing Minecraft infrastructure:

- **ALB DNS Name**: `module.networking.alb_dns_name`
- **Global Accelerator DNS Name**: `module.networking.global_accelerator_dns_name` or `aws_globalaccelerator_accelerator.main[0].dns_name`
- **Global Accelerator IP**: `aws_globalaccelerator_accelerator.main[0].ip_sets[0].ip_addresses[0]` (for A record)

### Usage Example

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

# Output FQDN for player connections
output "minecraft_server_hostname" {
  value = module.minecraft_dns.fqdn
}
```

## References

- [AWS Route 53 Documentation](https://docs.aws.amazon.com/route53/)
- [Terraform AWS Provider - Route 53](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record)
- [RFC 1123 - Requirements for Internet Hosts](https://tools.ietf.org/html/rfc1123)
- [Route 53 Hosted Zone IDs](https://docs.aws.amazon.com/general/latest/gr/elb.html)

