# Feature Specification: Route 53 DNS Module for Minecraft Server

**Feature Branch**: `002-route53-dns`  
**Created**: 2024-12-19  
**Status**: Draft  
**Input**: User description: "Generate a Terraform module that accepts a variable domain_name (e.g. asdasdasdasd.com) and optional subdomain (e.g. mc), looks up (or assumes existing) a public Amazon Route 53 hosted zone for that domain, and creates a DNS record (using aws_route53_record) so that the resulting hostname — either subdomain.domain_name or the apex domain — resolves to the public endpoint of my Minecraft server (for example the DNS name or IP of an AWS load-balancer or public IP). The record should use an alias if pointing to an AWS load-balancer (or public IP if direct) per best-practice, and the module should output the fully-qualified domain name (FQDN) to use for user connections. All domain and subdomain values must be parameterized through variables, and the code should follow Terraform best-practices with variables, outputs, and allow easy reuse in different environments."

## Clarifications

### Session 2024-12-19

- Q: How should the module detect whether target_endpoint is an ALB DNS name, Global Accelerator DNS name, or IP address? → A: Require explicit `record_type` variable (`alias` or `A`) from the caller, no auto-detection
- Q: What TTL value should be used for A records, and should it be configurable? → A: Configurable TTL variable with default of 300 seconds
- Q: What alias record attributes should be configured, and how should they differ for ALB vs Global Accelerator? → A: Auto-configure alias attributes based on target_endpoint pattern with optional override variables for advanced use cases
- Q: When multiple public hosted zones exist for the same domain, how should the module behave? → A: Error with clear message requiring explicit hosted_zone_id when multiple public zones exist
- Q: Should the module support IPv6 addresses with AAAA records, or only IPv4 with A records? → A: Support both IPv4 (A) and IPv6 (AAAA) records with explicit record_type including "AAAA" option

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Create DNS Record for Subdomain (Priority: P1)

As an infrastructure administrator, I want to create a DNS record for a subdomain (e.g., `mc.example.com`) that points to my Minecraft server's public endpoint, so that players can connect using a friendly domain name instead of an IP address or AWS-generated DNS name.

**Why this priority**: This is the primary use case - most Minecraft servers use subdomains (like `mc.example.com`) rather than apex domains. This enables the core functionality of providing a user-friendly connection endpoint.

**Independent Test**: Can be fully tested by creating a Route 53 record for a subdomain pointing to an ALB DNS name, verifying DNS resolution returns the correct endpoint, and confirming the FQDN output is correct. This delivers immediate value by enabling domain-based connections.

**Acceptance Scenarios**:

1. **Given** a Route 53 hosted zone exists for `example.com`, **When** I create a DNS record with `subdomain = "mc"` and `domain_name = "example.com"` pointing to an ALB DNS name, **Then** the record `mc.example.com` resolves to the ALB endpoint and the module outputs `mc.example.com` as the FQDN
2. **Given** a Route 53 hosted zone exists for `example.com`, **When** I create a DNS record with `subdomain = "minecraft"` and `domain_name = "example.com"` pointing to a Global Accelerator DNS name, **Then** the record `minecraft.example.com` resolves to the Global Accelerator endpoint and the module outputs `minecraft.example.com` as the FQDN
3. **Given** a Route 53 hosted zone exists for `example.com`, **When** I create a DNS record with `subdomain = "mc"` and `domain_name = "example.com"` pointing to a public IP address, **Then** the record `mc.example.com` resolves to the IP address using an A record and the module outputs `mc.example.com` as the FQDN

---

### User Story 2 - Create DNS Record for Apex Domain (Priority: P2)

As an infrastructure administrator, I want to create a DNS record for the apex domain (e.g., `example.com`) that points to my Minecraft server's public endpoint, so that players can connect using the root domain name.

**Why this priority**: Some administrators prefer using the apex domain directly. This is a common alternative to subdomains and provides the same core value but with different DNS configuration requirements.

**Independent Test**: Can be fully tested by creating a Route 53 record for the apex domain (no subdomain) pointing to an ALB DNS name, verifying DNS resolution works correctly, and confirming the FQDN output matches the domain name. This delivers value for administrators who prefer apex domain usage.

**Acceptance Scenarios**:

1. **Given** a Route 53 hosted zone exists for `example.com`, **When** I create a DNS record with `subdomain = null` (or empty) and `domain_name = "example.com"` pointing to an ALB DNS name, **Then** the record `example.com` resolves to the ALB endpoint and the module outputs `example.com` as the FQDN
2. **Given** a Route 53 hosted zone exists for `example.com`, **When** I create a DNS record with `subdomain = ""` and `domain_name = "example.com"` pointing to a Global Accelerator DNS name, **Then** the record `example.com` resolves to the Global Accelerator endpoint and the module outputs `example.com` as the FQDN

---

### User Story 3 - Look Up Existing Hosted Zone (Priority: P3)

As an infrastructure administrator, I want the module to automatically find an existing Route 53 hosted zone for my domain, so that I don't need to manually provide the hosted zone ID and the module integrates seamlessly with my existing DNS infrastructure.

**Why this priority**: This improves usability and reduces configuration errors. Most users will have existing hosted zones, and requiring manual zone ID lookup adds friction. However, the module can still function if zone lookup fails (with proper error handling), making this a nice-to-have enhancement.

**Independent Test**: Can be fully tested by providing only a domain name, verifying the module successfully looks up the hosted zone automatically, and confirming the DNS record is created in the correct zone. This delivers value by simplifying configuration and reducing manual steps.

**Acceptance Scenarios**:

1. **Given** a Route 53 hosted zone exists for `example.com` in the same AWS account, **When** I provide `domain_name = "example.com"` without a hosted zone ID, **Then** the module finds the hosted zone automatically and creates the DNS record successfully
2. **Given** multiple Route 53 hosted zones exist (public and private) for `example.com`, **When** I provide `domain_name = "example.com"` without a hosted zone ID, **Then** the module selects the public hosted zone (if only one public zone exists) and creates the DNS record successfully
3. **Given** no Route 53 hosted zone exists for `example.com`, **When** I provide `domain_name = "example.com"` without a hosted zone ID, **Then** the module provides a clear error message indicating the hosted zone must exist or be provided explicitly
4. **Given** multiple public Route 53 hosted zones exist for `example.com`, **When** I provide `domain_name = "example.com"` without a hosted zone ID, **Then** the module errors with a clear message requiring explicit `hosted_zone_id` to disambiguate

---

### Edge Cases

- What happens when the domain name contains a trailing dot (e.g., `example.com.`)? The module should normalize domain names by removing trailing dots.
- What happens when subdomain contains invalid characters or is too long? The module should validate subdomain format according to DNS naming rules (RFC 1123).
- What happens when the target endpoint is an invalid format or unreachable? The module should validate endpoint format but DNS resolution failures are handled by Route 53, not the module.
- What happens when multiple public hosted zones exist for the same domain? The module must error with a clear message requiring explicit `hosted_zone_id` to disambiguate (prevents incorrect record placement).
- What happens when the hosted zone ID is provided but doesn't match the domain name? The module should validate that the provided zone ID corresponds to the domain name or provide a clear warning.
- What happens when creating a DNS record that already exists? Terraform will update the existing record if the resource is managed, or error if it's not managed by this module.
- What happens when the target endpoint format doesn't match the specified record_type (e.g., IPv4 address with `record_type = "alias"`, IPv6 address with `record_type = "A"`)? The module should validate the combination and provide a clear error message indicating the mismatch.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Module MUST accept a required `domain_name` variable (e.g., `example.com`) that specifies the root domain for DNS record creation
- **FR-002**: Module MUST accept an optional `subdomain` variable (e.g., `mc`) that, when provided, creates a subdomain record (e.g., `mc.example.com`), and when omitted or empty, creates an apex domain record (e.g., `example.com`)
- **FR-003**: Module MUST look up an existing public Route 53 hosted zone for the provided domain name when `hosted_zone_id` is not provided, or accept an optional `hosted_zone_id` variable to explicitly specify the zone
- **FR-003a**: Module MUST error with a clear message requiring explicit `hosted_zone_id` when multiple public hosted zones exist for the same domain name (prevents ambiguous zone selection)
- **FR-004**: Module MUST create a Route 53 DNS record that resolves the resulting hostname (subdomain + domain or apex domain) to the Minecraft server's public endpoint
- **FR-005**: Module MUST accept a required `record_type` variable with values `"alias"`, `"A"`, or `"AAAA"` that explicitly specifies whether to create an alias record (for AWS resources like ALB, Global Accelerator, CloudFront), an A record (for IPv4 addresses), or an AAAA record (for IPv6 addresses)
- **FR-006**: Module MUST support alias records when `record_type = "alias"` by configuring the Route 53 alias block with the appropriate AWS resource endpoint (ALB DNS name, Global Accelerator DNS name, etc.)
- **FR-006a**: Module MUST auto-configure alias record attributes (evaluate_target_health, zone_id) based on the target_endpoint pattern (ALB: evaluate_target_health=true with ALB zone_id; Global Accelerator: evaluate_target_health=false with Global Accelerator zone_id)
- **FR-006b**: Module MUST accept optional override variables (`evaluate_target_health_override`, `zone_id_override`) to allow advanced customization when auto-configuration is insufficient
- **FR-007**: Module MUST support A records when `record_type = "A"` by configuring an A record with the provided IPv4 address and a configurable TTL value
- **FR-007a**: Module MUST support AAAA records when `record_type = "AAAA"` by configuring an AAAA record with the provided IPv6 address and a configurable TTL value
- **FR-007b**: Module MUST accept an optional `ttl` variable (default: 300 seconds) that specifies the TTL for A and AAAA records (alias records do not use TTL as they are always evaluated dynamically)
- **FR-008**: Module MUST accept a `target_endpoint` variable that specifies the Minecraft server endpoint (DNS name for alias records, IPv4 address for A records, or IPv6 address for AAAA records) to which the DNS record should point
- **FR-009**: Module MUST output the fully-qualified domain name (FQDN) of the created DNS record (e.g., `mc.example.com` or `example.com`) for use in user connections and other Terraform modules
- **FR-010**: Module MUST output the Route 53 record name (the actual DNS name created) for reference and integration with other systems
- **FR-011**: Module MUST validate domain name format (no trailing dots, valid DNS characters) and subdomain format (if provided) according to DNS naming standards
- **FR-012**: Module MUST validate that `record_type` is one of `"alias"`, `"A"`, or `"AAAA"` and that `target_endpoint` format matches the record type (DNS name for alias, IPv4 address for A, IPv6 address for AAAA)
- **FR-013**: Module MUST normalize domain names by removing trailing dots and ensuring consistent formatting before creating DNS records
- **FR-014**: Module MUST follow Terraform best practices including proper variable types, descriptions, validation rules, output descriptions, and resource tagging
- **FR-015**: Module MUST be reusable across different environments (dev, staging, production) through parameterized variables without hard-coding values
- **FR-016**: Module MUST support resource tagging through a `tags` variable to enable cost tracking and resource organization
- **FR-017**: Module MUST handle hosted zone lookup failures gracefully by providing clear error messages when the zone cannot be found or is ambiguous

### Key Entities *(include if feature involves data)*

- **DNS Record**: Represents a Route 53 DNS record that maps a hostname (subdomain + domain or apex domain) to a target endpoint (ALB DNS name, Global Accelerator DNS name, IPv4 address, or IPv6 address). Key attributes include record name, record type (A for IPv4, AAAA for IPv6, ALIAS for AWS resources), TTL (for A and AAAA records, configurable with default 300 seconds; alias records do not use TTL), and target endpoint.
- **Hosted Zone**: Represents an existing Route 53 hosted zone that contains DNS records for a domain. The module looks up or accepts this zone to create records within it. Key attributes include zone ID, zone name (domain), and zone type (public vs private).
- **Target Endpoint**: Represents the Minecraft server's public endpoint that players connect to. Can be an ALB DNS name (e.g., `minecraft-alb-123456789.us-east-1.elb.amazonaws.com`), Global Accelerator DNS name (e.g., `a1234567890-1234567890.awsglobalaccelerator.com`), an IPv4 address (e.g., `203.0.113.10`), or an IPv6 address (e.g., `2001:0db8:85a3:0000:0000:8a2e:0370:7334`). The caller must specify the correct `record_type` (`alias` for DNS names, `A` for IPv4 addresses, `AAAA` for IPv6 addresses) to match the endpoint format.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Administrators can create a DNS record for their Minecraft server in under 2 minutes by providing domain name, optional subdomain, record type, and target endpoint variables
- **SC-002**: The module successfully resolves DNS queries for the created hostname to the correct Minecraft server endpoint (ALB, Global Accelerator, IPv4, or IPv6) with 100% accuracy
- **SC-003**: The module validates that the provided `record_type` matches the `target_endpoint` format and creates the correct DNS record type (alias for AWS resources, A record for IPv4, AAAA record for IPv6) with 100% accuracy
- **SC-004**: The module outputs the correct FQDN that matches the created DNS record name, enabling seamless integration with other Terraform modules and user-facing documentation
- **SC-005**: The module can be reused across at least 3 different environments (dev, staging, production) with different domain names and subdomains without code modifications
- **SC-006**: DNS record creation completes successfully when a valid hosted zone exists, with zero manual hosted zone ID lookups required in 95% of use cases
- **SC-007**: The module provides clear, actionable error messages when hosted zone lookup fails or domain validation fails, enabling administrators to resolve issues without consulting Terraform documentation

## Assumptions

- Route 53 hosted zones are managed outside this module (created manually or via other Terraform configurations)
- The target endpoint (ALB DNS name, Global Accelerator DNS name, or IP) is provided by the calling module or administrator
- DNS propagation and resolution are handled by Route 53 and AWS DNS infrastructure (not within module scope)
- The module operates within a single AWS account and region (cross-account or cross-region hosted zones require explicit zone ID)
- Domain names follow standard DNS naming conventions (RFC 1123)
- Public hosted zones are preferred over private hosted zones when multiple zones exist for the same domain
- Minecraft server endpoints are either AWS resources (supporting alias records) or public IP addresses (requiring A records)

## Dependencies

- **AWS Provider**: Terraform AWS provider version >= 5.0 (for Route 53 resources)
- **Route 53 Hosted Zone**: An existing public Route 53 hosted zone for the target domain (or zone ID must be provided)
- **Target Endpoint**: The Minecraft server's public endpoint (ALB DNS name, Global Accelerator DNS name, or IP address) must be available and resolvable
- **IAM Permissions**: Terraform execution role/user must have `route53:GetHostedZone`, `route53:ListHostedZones`, `route53:ChangeResourceRecordSets`, and `route53:GetChange` permissions

## Non-Functional Requirements

- **Modularity**: Module must be self-contained and reusable without modifications to core Terraform configuration
- **Error Handling**: Module must provide descriptive error messages for common failure scenarios (missing hosted zone, invalid domain format, etc.)
- **Documentation**: Module must include comprehensive README with usage examples, variable descriptions, output descriptions, and integration examples
- **Code Quality**: Module must follow Terraform style guide, use consistent naming conventions, and include inline comments for complex logic
- **Validation**: Module must validate all input variables according to DNS and AWS Route 53 constraints before attempting resource creation

## Out of Scope

- Creating or managing Route 53 hosted zones (assumes existing zones)
- DNS propagation monitoring or health checks (handled by Route 53)
- SSL/TLS certificate management (separate concern, handled by ACM or other modules)
- Multiple record types beyond A, AAAA, and ALIAS (CNAME, MX, etc. not needed for Minecraft)
- DNS failover or health-check based routing (Route 53 health checks not in scope)
- Cross-account hosted zone access (requires explicit zone ID if cross-account)
- Private hosted zone support (focus on public zones for internet-facing Minecraft servers)
