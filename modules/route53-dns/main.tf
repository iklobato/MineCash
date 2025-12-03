# Route 53 DNS Module
# Creates DNS records for Minecraft server endpoints

# Local values for normalization, record name construction, and alias configuration
locals {
  # Step 1: Normalize domain name (remove trailing dots, convert to lowercase)
  # Route 53 stores domains without trailing dots, so we normalize for consistency
  normalized_domain_name = lower(trim(var.domain_name, "."))

  # Step 2: Normalize subdomain (remove trailing dots, lowercase, handle null/empty for apex domain)
  # When subdomain is null or empty, we create an apex domain record (e.g., example.com)
  normalized_subdomain = var.subdomain != null && var.subdomain != "" ? lower(trim(var.subdomain, ".")) : null

  # Step 3: Construct record name (subdomain.domain_name or domain_name for apex)
  # Examples: "mc.example.com" (with subdomain) or "example.com" (apex domain)
  record_name = local.normalized_subdomain != null ? "${local.normalized_subdomain}.${local.normalized_domain_name}" : local.normalized_domain_name

  # Step 4: Detect endpoint pattern for alias records to auto-configure zone_id and evaluate_target_health
  # ALB endpoints end with .elb.amazonaws.com (Application or Classic Load Balancer)
  is_alb_endpoint = var.record_type == "alias" && can(regex("\\.elb\\.amazonaws\\.com$", var.target_endpoint))
  # Global Accelerator endpoints end with .awsglobalaccelerator.com
  is_global_accelerator_endpoint = var.record_type == "alias" && can(regex("\\.awsglobalaccelerator\\.com$", var.target_endpoint))
  # CloudFront endpoints end with .cloudfront.net
  is_cloudfront_endpoint = var.record_type == "alias" && can(regex("\\.cloudfront\\.net$", var.target_endpoint))

  # Step 5: Auto-configure evaluate_target_health (true for ALB, false for Global Accelerator/CloudFront)
  # Override variable takes precedence if provided
  evaluate_target_health = var.evaluate_target_health_override != null ? var.evaluate_target_health_override : (local.is_alb_endpoint ? true : false)

  # Step 6: Auto-configure zone_id based on endpoint pattern
  # ALB: Look up zone_id by region (varies by region)
  # Global Accelerator: Use constant zone_id Z2BJ6XQ5FK7U4H (same for all regions)
  # CloudFront: Use constant zone_id Z2FDTNDATAQYW2 (same for all regions)
  # Override variable takes precedence if provided
  alias_zone_id = var.zone_id_override != null ? var.zone_id_override : (
    local.is_alb_endpoint ? data.aws_lb_hosted_zone_id.main[0].id :
    local.is_global_accelerator_endpoint ? "Z2BJ6XQ5FK7U4H" :
    local.is_cloudfront_endpoint ? "Z2FDTNDATAQYW2" :
    null
  )
}

# Look up hosted zone when hosted_zone_id is not provided
# This data source will error if multiple public zones exist for the same domain (desired behavior)
# Users must provide explicit hosted_zone_id when multiple zones exist
data "aws_route53_zone" "main" {
  count        = var.hosted_zone_id == null ? 1 : 0
  name         = local.normalized_domain_name
  private_zone = false # Only look up public hosted zones (private zones not supported)
}

# Get current AWS region for ALB zone ID lookup
data "aws_region" "current" {
  count = var.record_type == "alias" && local.is_alb_endpoint && var.zone_id_override == null ? 1 : 0
}

# Look up ALB hosted zone ID for ALB endpoints (Application Load Balancer)
data "aws_lb_hosted_zone_id" "main" {
  count  = var.record_type == "alias" && local.is_alb_endpoint && var.zone_id_override == null ? 1 : 0
  region = data.aws_region.current[0].id
}

# Precondition: Validate that hosted zone exists or is provided
check "hosted_zone_exists" {
  assert {
    condition     = var.hosted_zone_id != null || length(data.aws_route53_zone.main) > 0
    error_message = "No public hosted zone found for domain '${local.normalized_domain_name}'. Create a hosted zone or provide explicit hosted_zone_id."
  }
}

# Precondition: Validate that record_type and target_endpoint match
check "endpoint_format_matches_record_type" {
  assert {
    condition = (
      var.record_type == "alias" && can(regex("\\.", var.target_endpoint)) && !can(regex("^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.target_endpoint)) ||
      var.record_type == "A" && can(regex("^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.target_endpoint)) ||
      var.record_type == "AAAA" && can(regex("^(([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]+|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\\.){3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\\.){3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$", var.target_endpoint))
    )
    error_message = "target_endpoint format does not match record_type '${var.record_type}'. Expected ${var.record_type == "alias" ? "DNS name" : var.record_type == "A" ? "IPv4 address" : "IPv6 address"}, got: '${var.target_endpoint}'."
  }
}

# Precondition: Validate alias zone_id is configured when record_type is alias
check "alias_zone_id_configured" {
  assert {
    condition     = var.record_type != "alias" || local.alias_zone_id != null
    error_message = "Unable to determine zone_id for alias record. Ensure target_endpoint is a recognized AWS resource (ALB, Global Accelerator, or CloudFront) or provide zone_id_override."
  }
}

# Route 53 DNS Record
# Creates the actual DNS record in Route 53
resource "aws_route53_record" "main" {
  # Use provided hosted_zone_id or lookup result
  zone_id = var.hosted_zone_id != null ? var.hosted_zone_id : data.aws_route53_zone.main[0].zone_id
  name    = local.record_name
  # Alias records use type "A" in Route 53 (Route 53 alias is not a separate type)
  type = var.record_type == "alias" ? "A" : var.record_type

  # Alias record configuration (only when record_type = "alias")
  # Alias records point to AWS resources and don't use TTL (always evaluated dynamically)
  dynamic "alias" {
    for_each = var.record_type == "alias" ? [1] : []
    content {
      name                   = var.target_endpoint
      zone_id                = local.alias_zone_id
      evaluate_target_health = local.evaluate_target_health
    }
  }

  # A/AAAA record configuration (only when record_type = "A" or "AAAA")
  # Standard DNS records use TTL and records list
  records = var.record_type != "alias" ? [var.target_endpoint] : null
  ttl     = var.record_type != "alias" ? var.ttl : null
}
