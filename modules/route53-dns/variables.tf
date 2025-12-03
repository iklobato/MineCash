variable "domain_name" {
  description = "Root domain name for DNS record creation (e.g., example.com). The module will create a record in the hosted zone for this domain."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?)*$", var.domain_name)) && length(var.domain_name) >= 1 && length(var.domain_name) <= 253
    error_message = "domain_name must be a valid DNS name (RFC 1123 compliant), 1-253 characters, and cannot start or end with hyphen or dot."
  }
}

variable "subdomain" {
  description = "Subdomain prefix to prepend to the domain name. When provided, creates a subdomain record (e.g., 'mc' creates 'mc.example.com'). When omitted or empty, creates an apex domain record (e.g., 'example.com')."
  type        = string
  default     = null

  validation {
    condition     = var.subdomain == null || var.subdomain == "" || (can(regex("^[a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?$", var.subdomain)) && length(var.subdomain) >= 1 && length(var.subdomain) <= 63)
    error_message = "subdomain must be a valid DNS label (RFC 1123 compliant), 1-63 characters, and cannot start or end with hyphen."
  }
}

variable "record_type" {
  description = "Type of DNS record to create. Must be one of: 'alias' (for AWS resources like ALB, Global Accelerator, CloudFront), 'A' (for IPv4 addresses), or 'AAAA' (for IPv6 addresses)."
  type        = string

  validation {
    condition     = contains(["alias", "A", "AAAA"], var.record_type)
    error_message = "record_type must be one of: 'alias', 'A', or 'AAAA'."
  }
}

variable "target_endpoint" {
  description = "The Minecraft server endpoint to which the DNS record should point. Format must match record_type: DNS name for alias, IPv4 address for A, IPv6 address for AAAA."
  type        = string

  validation {
    condition     = var.record_type == "alias" && can(regex("^[a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?)+$", var.target_endpoint)) || var.record_type == "A" && can(regex("^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.target_endpoint)) || var.record_type == "AAAA" && can(regex("^(([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]+|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\\.){3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\\.){3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$", var.target_endpoint))
    error_message = "target_endpoint format must match record_type: DNS name for alias, IPv4 address (xxx.xxx.xxx.xxx) for A, IPv6 address for AAAA."
  }
}

variable "hosted_zone_id" {
  description = "Explicit Route 53 hosted zone ID. When provided, bypasses automatic hosted zone lookup. Required when multiple public hosted zones exist for the same domain."
  type        = string
  default     = null

  validation {
    condition     = var.hosted_zone_id == null || can(regex("^Z[A-Z0-9]+$", var.hosted_zone_id))
    error_message = "hosted_zone_id must be a valid Route 53 hosted zone ID (starts with 'Z')."
  }
}

variable "ttl" {
  description = "Time-to-live (TTL) in seconds for A and AAAA records. Alias records do not use TTL (they are always evaluated dynamically by Route 53)."
  type        = number
  default     = 300

  validation {
    condition     = var.ttl >= 60 && var.ttl <= 2147483647
    error_message = "ttl must be between 60 and 2147483647 seconds (Route 53 limits)."
  }
}

variable "evaluate_target_health_override" {
  description = "Override for alias record evaluate_target_health attribute. When provided, overrides auto-configuration based on endpoint pattern. Only applicable when record_type = 'alias'."
  type        = bool
  default     = null
}

variable "zone_id_override" {
  description = "Override for alias record zone_id attribute. When provided, overrides auto-configuration based on endpoint pattern. Only applicable when record_type = 'alias'."
  type        = string
  default     = null

  validation {
    condition     = var.zone_id_override == null || can(regex("^Z[A-Z0-9]+$", var.zone_id_override))
    error_message = "zone_id_override must be a valid Route 53 hosted zone ID (starts with 'Z')."
  }
}

