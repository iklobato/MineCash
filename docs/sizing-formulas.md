# Resource Sizing Formulas

This document describes all formulas and assumptions used for calculating resource sizing based on `player_capacity`.

## Overview

When `player_capacity` is specified, the system automatically calculates resource sizing for all components using mathematical formulas. Individual resource variables can override calculated values if needed.

## ECS CPU and Memory

### CPU Calculation
- **Formula**: `cpu_vcpu = max(1, ceil(player_capacity / 100))`
- **Minimum**: 1 vCPU
- **Ratio**: 1 vCPU per 100 players
- **Discrete Options**: 256, 512, 1024, 2048, 4096, 8192, 16384 CPU units (rounded up to nearest)

### Memory Calculation
- **Formula**: `memory_gb = max(2, ceil(player_capacity / 50))`
- **Minimum**: 2GB
- **Ratio**: 1GB per 50 players
- **Constraints**: Memory must be within valid range for selected CPU:
  - 256 CPU: 512-2048 MB
  - 512 CPU: 1024-4096 MB
  - 1024 CPU: 2048-8192 MB
  - 2048 CPU: 4096-16384 MB
  - 4096 CPU: 8192-30720 MB
  - 8192 CPU: 16384-30720 MB
  - 16384 CPU: 32768-61440 MB

### ECS Task Count
- **Formula**: 
  - If `player_capacity < 5000`: `desired_count = 1`
  - If `player_capacity >= 5000`: `desired_count = max(2, ceil(player_capacity / 5000))`
- **Rationale**: Single task for moderate loads, multiple tasks for high availability and load distribution

## Redis Configuration

### Instance Type Selection
Based on player capacity thresholds:
- **100-500 players**: `cache.t3.micro` (0.5 vCPU, 0.575 GB RAM)
- **500-2,000 players**: `cache.t3.small` (0.5 vCPU, 1.37 GB RAM)
- **2,000-5,000 players**: `cache.t3.medium` (2 vCPU, 3.09 GB RAM)
- **5,000-10,000 players**: `cache.t3.large` (2 vCPU, 6.18 GB RAM)
- **10,000-20,000 players**: `cache.r6g.large` (2 vCPU, 13.07 GB RAM)
- **20,000-50,000 players**: `cache.r6g.xlarge` (4 vCPU, 26.32 GB RAM)

### Replica Count
- **Formula**: `replica_count = max(0, ceil(player_capacity / 5000) - 1)`
- **Rationale**: +1 replica per 5,000 players for redundancy and high availability

## EFS Performance Mode

- **Formula**: `performance_mode = player_capacity >= 5000 ? "maxIO" : "generalPurpose"`
- **Rationale**: 
  - `generalPurpose`: Lower latency, suitable for moderate I/O (< 5,000 players)
  - `maxIO`: Higher throughput, suitable for high I/O workloads (>= 5,000 players)

## NAT Gateway Count

- **Formula**: `nat_gateway_count = player_capacity >= 10000 ? 2 : 1`
- **Rationale**: 
  - Single NAT Gateway: Sufficient for moderate traffic (< 10,000 players)
  - Multiple NAT Gateways: High availability and load distribution (>= 10,000 players)
- **Note**: VPC module creates NAT Gateways per availability zone. The calculation determines effective usage.

## Global Accelerator

- **Formula**: `enable_global_accelerator = player_capacity >= 1000`
- **Rationale**: 
  - Disabled for small servers (< 1,000 players): Cost may not be justified
  - Enabled for larger servers (>= 1,000 players): Latency improvement and availability benefits outweigh cost

## Cost Calculation Formulas

### ECS Fargate (Monthly)
- **Formula**: `(cpu_vcpu * 0.04048 + memory_gb * 0.004445) * 730 * desired_count`
- **Pricing**: $0.04048 per vCPU-hour, $0.004445 per GB-hour
- **Assumption**: 730 hours/month

### ElastiCache Redis (Monthly)
- **Formula**: `redis_hourly_cost * 730 * (replica_count + 1)`
- **Hourly Pricing**:
  - cache.t3.micro: $0.017/hour
  - cache.t3.small: $0.034/hour
  - cache.t3.medium: $0.068/hour
  - cache.t3.large: $0.136/hour
  - cache.r6g.large: $0.126/hour
  - cache.r6g.xlarge: $0.252/hour

### EFS Storage (Monthly)
- **Formula**: `100 GB * $0.30/GB-month = $30/month`
- **Assumption**: Baseline 100GB storage estimate
- **Note**: Actual costs vary by usage

### NAT Gateway (Monthly)
- **Formula**: `nat_gateway_count * $32.40/month`
- **Pricing**: $0.045/hour = ~$32.40/month per gateway

### Application Load Balancer (Monthly)
- **Base Cost**: $16.20/month
- **Note**: LCU charges apply and vary by usage

### Global Accelerator (Monthly)
- **Base Cost**: $7.20/month (if enabled)
- **Note**: Data transfer charges apply and vary by region

### Total Monthly Cost
- **Formula**: Sum of all component costs
- **Note**: Costs are estimates and may vary by region, usage patterns, and AWS pricing changes

## Examples

### 100 Players
- CPU: 1 vCPU (1024 units)
- Memory: 2GB (2048 MB)
- Tasks: 1
- Redis: cache.t3.micro, 0 replicas
- EFS: generalPurpose
- NAT Gateways: 1
- Global Accelerator: Disabled
- **Estimated Cost**: ~$120/month

### 1,000 Players
- CPU: 10 vCPU (rounded to 4096 units = 4 vCPU)
- Memory: 20GB (rounded to 16384 MB = 16GB)
- Tasks: 1
- Redis: cache.t3.small, 0 replicas
- EFS: generalPurpose
- NAT Gateways: 1
- Global Accelerator: Enabled
- **Estimated Cost**: ~$230/month

### 10,000 Players
- CPU: 100 vCPU (rounded to 16384 units = 16 vCPU per task)
- Memory: 200GB (rounded to 32768 MB = 32GB per task)
- Tasks: 2 (ceil(10000/5000) = 2)
- Redis: cache.r6g.large, 1 replica
- EFS: maxIO
- NAT Gateways: 2
- Global Accelerator: Enabled
- **Estimated Cost**: ~$1,200/month

## Assumptions and Limitations

1. **Resource Ratios**: Based on industry-standard Minecraft server benchmarks and AWS case studies
2. **Cost Estimates**: Approximate pricing as of December 2024, may vary by region
3. **Storage**: EFS cost assumes baseline 100GB; actual costs vary by usage
4. **Data Transfer**: Not included in cost estimates (varies significantly by usage)
5. **LCU Charges**: ALB LCU charges not included (varies by traffic patterns)
6. **Scaling**: Formulas are conservative to ensure adequate capacity during peak loads

## Validation

All calculated values are validated for:
- ECS CPU/memory compatibility
- Redis instance type validity
- Resource limits (AWS service quotas)
- Player capacity range (100-50,000)

