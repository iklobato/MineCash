# Implementation Plan: Route 53 DNS Module for Minecraft Server

**Branch**: `002-route53-dns` | **Date**: 2024-12-19 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-route53-dns/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Create a reusable Terraform module that manages Route 53 DNS records for Minecraft server endpoints. The module accepts domain name and optional subdomain, looks up existing Route 53 hosted zones, and creates DNS records (alias for AWS resources, A/AAAA for IP addresses) pointing to the Minecraft server's public endpoint. The module outputs the fully-qualified domain name (FQDN) for player connections and integrates seamlessly with the existing AWS Minecraft infrastructure.

**Research Complete**: All technical decisions documented in [research.md](./research.md). Key decisions: Explicit record_type variable (no auto-detection), configurable TTL with 300s default, auto-configure alias attributes with optional overrides, error on multiple hosted zones requiring explicit zone_id, support for IPv4 (A) and IPv6 (AAAA) records.

## Technical Context

**Language/Version**: Terraform >= 1.0, HCL2  
**Primary Dependencies**: AWS Provider >= 5.0, Terraform data sources for Route 53 hosted zone lookup  
**Storage**: N/A (DNS records stored in Route 53)  
**Testing**: terraform validate, terraform plan (dry-run), manual DNS resolution testing, integration with existing infrastructure  
**Target Platform**: AWS Route 53 (any AWS region)  
**Project Type**: Infrastructure-as-Code (Terraform module)  
**Performance Goals**: DNS record creation completes in <30 seconds, DNS propagation handled by Route 53 (<60 seconds typical)  
**Constraints**: No hard-coded secrets, explicit record_type required (no auto-detection), must handle hosted zone lookup failures gracefully, validate endpoint format matches record_type  
**Scale/Scope**: Single reusable Terraform module, supports multiple environments (dev/staging/prod), integrates with existing Minecraft infrastructure module

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Note**: Constitution file appears to be a template. No specific constitution gates identified. Proceeding with standard Terraform best practices:
- Modular code organization (standalone module)
- No hard-coded secrets or values
- Comprehensive documentation (README with examples)
- Proper error handling and validation
- Clean resource lifecycle (terraform destroy removes records)
- Reusable across environments via parameterized variables

## Project Structure

### Documentation (this feature)

```text
specs/002-route53-dns/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md         # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
terraform/
├── modules/
│   └── route53-dns/          # Route 53 DNS module
│       ├── main.tf            # Route 53 record resource, hosted zone lookup
│       ├── variables.tf       # Input variables (domain_name, subdomain, record_type, target_endpoint, etc.)
│       ├── outputs.tf         # Output values (fqdn, record_name)
│       └── README.md          # Module documentation with usage examples
│
└── [existing modules: vpc, ecs, storage, cache, networking]
```

**Structure Decision**: Standalone Terraform module following the same pattern as existing modules (vpc, ecs, storage, cache, networking). The module is self-contained, reusable, and can be integrated into the root Terraform configuration or used independently. Module structure includes main.tf (resources), variables.tf (inputs), outputs.tf (outputs), and README.md (documentation).

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | N/A | No violations - module follows standard Terraform patterns |

## Phase 0: Research & Technical Decisions

**Status**: Complete (see [research.md](./research.md))

### Research Areas Covered

1. **Route 53 Hosted Zone Lookup**: Using `data.aws_route53_zone` with name filter, handling multiple zones, prioritizing public zones
2. **Alias Record Configuration**: Auto-detecting ALB vs Global Accelerator patterns, configuring evaluate_target_health and zone_id appropriately
3. **DNS Record Types**: Supporting alias (for AWS resources), A (IPv4), and AAAA (IPv6) records
4. **TTL Configuration**: Best practices for DNS TTL values, default 300 seconds for A/AAAA records
5. **Domain Name Normalization**: Handling trailing dots, RFC 1123 validation
6. **Error Handling**: Clear error messages for missing zones, ambiguous zones, format mismatches

### Key Technical Decisions

- **Record Type Detection**: Explicit `record_type` variable required (no auto-detection) - simplifies implementation and reduces errors
- **TTL**: Configurable with 300-second default - balances DNS caching with update responsiveness
- **Alias Configuration**: Auto-configure based on endpoint pattern with optional overrides - balances automation with flexibility
- **Multiple Hosted Zones**: Error requiring explicit `hosted_zone_id` when ambiguous - prevents incorrect record placement
- **IPv6 Support**: Support AAAA records with explicit `record_type = "AAAA"` - enables IPv6 support without complexity

## Phase 1: Design & Contracts

**Status**: In Progress

### Data Model

See [data-model.md](./data-model.md) for detailed entity definitions:

- **DNS Record**: Route 53 record mapping hostname to endpoint
- **Hosted Zone**: Route 53 hosted zone containing DNS records
- **Target Endpoint**: Minecraft server endpoint (ALB DNS, Global Accelerator DNS, IPv4, or IPv6)

### Module Interface (Contracts)

See [contracts/variables-schema.md](./contracts/variables-schema.md) for detailed variable definitions:

**Input Variables**:
- `domain_name` (required, string): Root domain name (e.g., "example.com")
- `subdomain` (optional, string): Subdomain prefix (e.g., "mc" for "mc.example.com")
- `record_type` (required, string): "alias", "A", or "AAAA"
- `target_endpoint` (required, string): Endpoint to point to (DNS name or IP)
- `hosted_zone_id` (optional, string): Explicit hosted zone ID (if not provided, looked up)
- `ttl` (optional, number): TTL for A/AAAA records (default: 300)
- `evaluate_target_health_override` (optional, bool): Override for alias evaluate_target_health
- `zone_id_override` (optional, string): Override for alias zone_id
- `tags` (optional, map(string)): Resource tags

**Output Variables**:
- `fqdn` (string): Fully-qualified domain name (e.g., "mc.example.com")
- `record_name` (string): Route 53 record name

### Integration Points

- **Input from Minecraft Infrastructure**: `target_endpoint` can be `module.networking.alb_dns_name` or `module.networking.global_accelerator_dns_name` or `aws_globalaccelerator_accelerator.main[0].ip_sets[0].ip_addresses[0]`
- **Output to Users**: `fqdn` output provides the connection hostname for players

## Phase 2: Implementation Tasks

**Status**: Pending (will be created by `/speckit.tasks` command)

Tasks will be generated based on:
- Module file creation (main.tf, variables.tf, outputs.tf, README.md)
- Hosted zone lookup logic
- DNS record resource creation
- Validation logic
- Error handling
- Documentation
- Integration with existing infrastructure

## Next Steps

1. Complete Phase 1 design artifacts (data-model.md, contracts/, quickstart.md)
2. Run `/speckit.tasks` to generate implementation tasks
3. Implement module following generated tasks
4. Test module integration with existing Minecraft infrastructure
5. Update root Terraform configuration to use the new module
