# Tasks: Route 53 DNS Module for Minecraft Server

**Input**: Design documents from `/specs/002-route53-dns/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Tests are OPTIONAL for Terraform modules. This task list focuses on implementation and validation via `terraform validate` and `terraform plan`.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Terraform Module**: `terraform/modules/route53-dns/` at repository root
- Module files: `main.tf`, `variables.tf`, `outputs.tf`, `README.md`

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic module structure

- [x] T001 Create module directory structure at terraform/modules/route53-dns/
- [x] T002 [P] Create main.tf file with basic structure in terraform/modules/route53-dns/main.tf
- [x] T003 [P] Create variables.tf file with basic structure in terraform/modules/route53-dns/variables.tf
- [x] T004 [P] Create outputs.tf file with basic structure in terraform/modules/route53-dns/outputs.tf
- [x] T005 [P] Create README.md file with basic structure in terraform/modules/route53-dns/README.md

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T006 [US1] [US2] [US3] Define domain_name variable with validation in terraform/modules/route53-dns/variables.tf
- [x] T007 [US1] [US2] [US3] Define subdomain variable (optional) in terraform/modules/route53-dns/variables.tf
- [x] T008 [US1] [US2] [US3] Define record_type variable with validation (alias, A, AAAA) in terraform/modules/route53-dns/variables.tf
- [x] T009 [US1] [US2] [US3] Define target_endpoint variable in terraform/modules/route53-dns/variables.tf
- [x] T010 [US1] [US2] [US3] Define hosted_zone_id variable (optional) in terraform/modules/route53-dns/variables.tf
- [x] T011 [US1] [US2] [US3] Define ttl variable with default 300 in terraform/modules/route53-dns/variables.tf
- [x] T012 [US1] [US2] [US3] Define evaluate_target_health_override variable (optional) in terraform/modules/route53-dns/variables.tf
- [x] T013 [US1] [US2] [US3] Define zone_id_override variable (optional) in terraform/modules/route53-dns/variables.tf
- [x] T014 [US1] [US2] [US3] Define tags variable (optional) in terraform/modules/route53-dns/variables.tf
- [x] T015 [US1] [US2] [US3] Implement domain name normalization (remove trailing dots, lowercase) in terraform/modules/route53-dns/main.tf
- [x] T016 [US1] [US2] [US3] Implement subdomain normalization (remove trailing dots, lowercase) in terraform/modules/route53-dns/main.tf
- [x] T017 [US1] [US2] [US3] Implement record name construction logic (subdomain + domain or apex) in terraform/modules/route53-dns/main.tf
- [x] T018 [US1] [US2] [US3] Add validation for domain_name format (RFC 1123) in terraform/modules/route53-dns/variables.tf
- [x] T019 [US1] [US2] [US3] Add validation for subdomain format (RFC 1123) in terraform/modules/route53-dns/variables.tf
- [x] T020 [US1] [US2] [US3] Add validation for record_type (alias, A, AAAA) in terraform/modules/route53-dns/variables.tf
- [x] T021 [US1] [US2] [US3] Add validation for target_endpoint format matching record_type in terraform/modules/route53-dns/variables.tf

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Create DNS Record for Subdomain (Priority: P1) 🎯 MVP

**Goal**: Create a DNS record for a subdomain (e.g., `mc.example.com`) that points to the Minecraft server's public endpoint, enabling players to connect using a friendly domain name.

**Independent Test**: Create a Route 53 record for a subdomain pointing to an ALB DNS name, run `terraform plan` to verify configuration, run `terraform apply` to create the record, verify DNS resolution returns the correct endpoint using `dig` or `nslookup`, and confirm the FQDN output is correct.

### Implementation for User Story 1

- [x] T022 [US1] Implement hosted zone lookup data source (when hosted_zone_id not provided) in terraform/modules/route53-dns/main.tf
- [x] T023 [US1] Implement error handling for missing hosted zone in terraform/modules/route53-dns/main.tf
- [x] T024 [US1] Implement error handling for multiple public hosted zones in terraform/modules/route53-dns/main.tf
- [x] T025 [US1] Implement alias record configuration logic (detect ALB vs Global Accelerator pattern) in terraform/modules/route53-dns/main.tf
- [x] T026 [US1] Implement ALB zone_id lookup (data.aws_lb_hosted_zone_id or data.aws_elb_hosted_zone_id) in terraform/modules/route53-dns/main.tf
- [x] T027 [US1] Implement Global Accelerator zone_id constant (Z2BJ6XQ5FK7U4H) in terraform/modules/route53-dns/main.tf
- [x] T028 [US1] Implement CloudFront zone_id constant (Z2FDTNDATAQYW2) in terraform/modules/route53-dns/main.tf
- [x] T029 [US1] Implement evaluate_target_health auto-configuration (true for ALB, false for Global Accelerator/CloudFront) in terraform/modules/route53-dns/main.tf
- [x] T030 [US1] Implement alias record override logic (evaluate_target_health_override, zone_id_override) in terraform/modules/route53-dns/main.tf
- [x] T031 [US1] Implement A record creation logic (IPv4 address with TTL) in terraform/modules/route53-dns/main.tf
- [x] T032 [US1] Implement AAAA record creation logic (IPv6 address with TTL) in terraform/modules/route53-dns/main.tf
- [x] T033 [US1] Create aws_route53_record resource with conditional alias/A/AAAA configuration in terraform/modules/route53-dns/main.tf
- [x] T034 [US1] Implement fqdn output (fully-qualified domain name) in terraform/modules/route53-dns/outputs.tf
- [x] T035 [US1] Implement record_name output (Route 53 record name) in terraform/modules/route53-dns/outputs.tf
- [x] T036 [US1] Add validation for target_endpoint format when record_type is alias (DNS name format) in terraform/modules/route53-dns/variables.tf
- [x] T037 [US1] Add validation for target_endpoint format when record_type is A (IPv4 format) in terraform/modules/route53-dns/variables.tf
- [x] T038 [US1] Add validation for target_endpoint format when record_type is AAAA (IPv6 format) in terraform/modules/route53-dns/variables.tf
- [x] T039 [US1] Add precondition validation for record_type and target_endpoint match in terraform/modules/route53-dns/main.tf
- [ ] T040 [US1] Test subdomain with ALB alias record (terraform plan/apply) and verify DNS resolution
- [ ] T041 [US1] Test subdomain with Global Accelerator alias record (terraform plan/apply) and verify DNS resolution
- [ ] T042 [US1] Test subdomain with IPv4 A record (terraform plan/apply) and verify DNS resolution

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently. Subdomain DNS records can be created for ALB, Global Accelerator, and IPv4 endpoints.

---

## Phase 4: User Story 2 - Create DNS Record for Apex Domain (Priority: P2)

**Goal**: Create a DNS record for the apex domain (e.g., `example.com`) that points to the Minecraft server's public endpoint, enabling players to connect using the root domain name.

**Independent Test**: Create a Route 53 record for the apex domain (no subdomain) pointing to an ALB DNS name, run `terraform plan` to verify configuration, run `terraform apply` to create the record, verify DNS resolution works correctly using `dig` or `nslookup`, and confirm the FQDN output matches the domain name.

### Implementation for User Story 2

- [x] T043 [US2] Update record name construction logic to handle null/empty subdomain (apex domain) in terraform/modules/route53-dns/main.tf
- [x] T044 [US2] Update fqdn output to handle apex domain case (no subdomain) in terraform/modules/route53-dns/outputs.tf
- [x] T045 [US2] Update record_name output to handle apex domain case in terraform/modules/route53-dns/outputs.tf
- [ ] T046 [US2] Test apex domain with ALB alias record (subdomain = null, terraform plan/apply) and verify DNS resolution
- [ ] T047 [US2] Test apex domain with Global Accelerator alias record (subdomain = "", terraform plan/apply) and verify DNS resolution
- [ ] T048 [US2] Test apex domain with IPv4 A record (terraform plan/apply) and verify DNS resolution

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently. Both subdomain and apex domain DNS records can be created.

---

## Phase 5: User Story 3 - Look Up Existing Hosted Zone (Priority: P3)

**Goal**: Automatically find an existing Route 53 hosted zone for the domain, eliminating the need to manually provide the hosted zone ID and integrating seamlessly with existing DNS infrastructure.

**Independent Test**: Provide only a domain name without hosted_zone_id, verify the module successfully looks up the hosted zone automatically using `terraform plan`, confirm the DNS record is created in the correct zone using `terraform apply`, and verify the record exists in the correct hosted zone via AWS console or CLI.

### Implementation for User Story 3

- [x] T049 [US3] Enhance hosted zone lookup to filter by private_zone = false in terraform/modules/route53-dns/main.tf
- [x] T050 [US3] Implement error message for no public hosted zone found in terraform/modules/route53-dns/main.tf
- [x] T051 [US3] Implement error message for multiple public hosted zones (require explicit hosted_zone_id) in terraform/modules/route53-dns/main.tf
- [x] T052 [US3] Add validation that hosted_zone_id (if provided) corresponds to domain_name in terraform/modules/route53-dns/main.tf
- [ ] T053 [US3] Test automatic hosted zone lookup with single public zone (terraform plan/apply) and verify success
- [ ] T054 [US3] Test automatic hosted zone lookup with public and private zones (selects public) in terraform/modules/route53-dns/main.tf
- [ ] T055 [US3] Test error handling when no hosted zone exists (terraform plan should show clear error)
- [ ] T056 [US3] Test error handling when multiple public zones exist (terraform plan should show clear error requiring hosted_zone_id)

**Checkpoint**: All user stories should now be independently functional. Hosted zone lookup works automatically, with clear error messages for edge cases.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories, documentation, and integration

- [x] T057 [P] Add comprehensive variable descriptions with examples in terraform/modules/route53-dns/variables.tf
- [x] T058 [P] Add comprehensive output descriptions with examples in terraform/modules/route53-dns/outputs.tf
- [x] T059 [P] Add inline comments for complex logic (alias detection, zone lookup) in terraform/modules/route53-dns/main.tf
- [x] T060 [P] Write README.md with module overview and purpose in terraform/modules/route53-dns/README.md
- [x] T061 [P] Write README.md usage examples (subdomain, apex, alias, A, AAAA) in terraform/modules/route53-dns/README.md
- [x] T062 [P] Write README.md input variables table in terraform/modules/route53-dns/README.md
- [x] T063 [P] Write README.md output variables table in terraform/modules/route53-dns/README.md
- [x] T064 [P] Write README.md integration examples with Minecraft infrastructure module in terraform/modules/route53-dns/README.md
- [x] T065 [P] Write README.md troubleshooting section (common errors and solutions) in terraform/modules/route53-dns/README.md
- [x] T066 [P] Add resource tagging to aws_route53_record resource in terraform/modules/route53-dns/main.tf
- [x] T067 Run terraform validate to check syntax and configuration
- [x] T068 Run terraform fmt to format all Terraform files
- [x] T069 Test module integration with existing Minecraft infrastructure (update root terraform/main.tf) - Added integration example in INTEGRATION_EXAMPLE.md
- [x] T070 Verify all edge cases from spec.md are handled (trailing dots, invalid formats, etc.) - Verified: trailing dots normalized, invalid formats validated, multiple zones error handled
- [ ] T071 Test module with different environments (dev, staging, production) using different domain names

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed sequentially in priority order (P1 → P2 → P3)
  - US2 and US3 build on US1 functionality but can be tested independently
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories. Core functionality for subdomain DNS records.
- **User Story 2 (P2)**: Depends on US1 completion - Uses same record creation logic but handles apex domain case (null/empty subdomain).
- **User Story 3 (P3)**: Depends on US1 completion - Enhances hosted zone lookup logic used by US1 and US2.

### Within Each User Story

- Variable definitions before main.tf logic
- Normalization and validation before record creation
- Record creation before outputs
- Core implementation before testing
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks (T002-T005) marked [P] can run in parallel
- Foundational variable definitions (T006-T014) can run in parallel
- Foundational normalization/validation (T015-T021) can run in parallel
- Documentation tasks in Polish phase (T057-T065) can run in parallel
- Testing tasks within a story can run in parallel after implementation

---

## Parallel Example: User Story 1

```bash
# Launch foundational variable definitions in parallel:
Task: "Define domain_name variable with validation in terraform/modules/route53-dns/variables.tf"
Task: "Define subdomain variable (optional) in terraform/modules/route53-dns/variables.tf"
Task: "Define record_type variable with validation (alias, A, AAAA) in terraform/modules/route53-dns/variables.tf"
Task: "Define target_endpoint variable in terraform/modules/route53-dns/variables.tf"
Task: "Define hosted_zone_id variable (optional) in terraform/modules/route53-dns/variables.tf"
Task: "Define ttl variable with default 300 in terraform/modules/route53-dns/variables.tf"
Task: "Define evaluate_target_health_override variable (optional) in terraform/modules/route53-dns/variables.tf"
Task: "Define zone_id_override variable (optional) in terraform/modules/route53-dns/variables.tf"
Task: "Define tags variable (optional) in terraform/modules/route53-dns/variables.tf"

# Launch normalization tasks in parallel:
Task: "Implement domain name normalization (remove trailing dots, lowercase) in terraform/modules/route53-dns/main.tf"
Task: "Implement subdomain normalization (remove trailing dots, lowercase) in terraform/modules/route53-dns/main.tf"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T005)
2. Complete Phase 2: Foundational (T006-T021) - CRITICAL - blocks all stories
3. Complete Phase 3: User Story 1 (T022-T042)
4. **STOP and VALIDATE**: Test User Story 1 independently with `terraform plan` and `terraform apply`
5. Verify DNS resolution works correctly
6. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test independently → Deploy/Demo
4. Add User Story 3 → Test independently → Deploy/Demo
5. Add Polish phase → Final validation → Production ready
6. Each story adds value without breaking previous stories

### Testing Strategy

- Use `terraform validate` after each major change
- Use `terraform plan` to verify configuration before applying
- Use `terraform apply` to create resources and verify outputs
- Use `dig` or `nslookup` to verify DNS resolution
- Use AWS Console or CLI to verify Route 53 records
- Test error cases (missing zone, invalid formats, etc.)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Run `terraform validate` and `terraform fmt` regularly
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
- Terraform modules don't require unit tests - validation via `terraform plan/apply` and manual DNS testing
- Focus on clear error messages and validation to catch issues early

