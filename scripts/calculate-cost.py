#!/usr/bin/env python3
"""
Standalone cost calculation script for Minecraft server infrastructure.
Calculates monthly AWS costs based on player capacity without running Terraform plan.

Usage:
    python3 scripts/calculate-cost.py <player_capacity> [--json]

Example:
    python3 scripts/calculate-cost.py 500
    python3 scripts/calculate-cost.py 1000 --json
"""

import sys
import json
import math

# AWS Pricing (approximate, region-specific)
ECS_CPU_PRICE_PER_VCPU_HOUR = 0.04048
ECS_MEMORY_PRICE_PER_GB_HOUR = 0.004445
HOURS_PER_MONTH = 730

REDIS_HOURLY_PRICING = {
    "cache.t3.micro": 0.017,
    "cache.t3.small": 0.034,
    "cache.t3.medium": 0.068,
    "cache.t3.large": 0.136,
    "cache.r6g.large": 0.126,
    "cache.r6g.xlarge": 0.252,
}

EFS_STORAGE_PRICE_PER_GB_MONTH = 0.30
EFS_BASELINE_STORAGE_GB = 100

NAT_GATEWAY_PRICE_PER_MONTH = 32.40
ALB_BASE_PRICE_PER_MONTH = 16.20
GLOBAL_ACCELERATOR_PRICE_PER_MONTH = 7.20

# ECS CPU discrete options
CPU_OPTIONS = [256, 512, 1024, 2048, 4096, 8192, 16384]

# CPU memory constraints
CPU_MEMORY_MIN = {
    256: 512,
    512: 1024,
    1024: 2048,
    2048: 4096,
    4096: 8192,
    8192: 16384,
    16384: 32768,
}

CPU_MEMORY_MAX = {
    256: 2048,
    512: 4096,
    1024: 8192,
    2048: 16384,
    4096: 30720,
    8192: 30720,
    16384: 61440,
}


def calculate_resources(player_capacity):
    """Calculate resource sizing based on player capacity."""
    # CPU calculation
    cpu_vcpu = max(1, math.ceil(player_capacity / 100))
    cpu_units = cpu_vcpu * 1024
    
    # Round up to nearest CPU option
    rounded_cpu = min([cpu for cpu in CPU_OPTIONS if cpu >= cpu_units])
    
    # Memory calculation
    memory_gb = max(2, math.ceil(player_capacity / 50))
    memory_mb = memory_gb * 1024
    
    # Validate memory against CPU constraints
    valid_memory_min = CPU_MEMORY_MIN[rounded_cpu]
    valid_memory_max = CPU_MEMORY_MAX[rounded_cpu]
    memory_mb = max(valid_memory_min, min(memory_mb, valid_memory_max))
    memory_gb = memory_mb / 1024
    
    # Redis instance type
    if player_capacity <= 500:
        redis_node_type = "cache.t3.micro"
    elif player_capacity <= 2000:
        redis_node_type = "cache.t3.small"
    elif player_capacity <= 5000:
        redis_node_type = "cache.t3.medium"
    elif player_capacity <= 10000:
        redis_node_type = "cache.t3.large"
    elif player_capacity <= 20000:
        redis_node_type = "cache.r6g.large"
    else:
        redis_node_type = "cache.r6g.xlarge"
    
    # Redis replica count
    redis_replica_count = max(0, math.ceil(player_capacity / 5000) - 1)
    
    # EFS performance mode
    efs_performance_mode = "maxIO" if player_capacity >= 5000 else "generalPurpose"
    
    # NAT Gateway count
    nat_gateway_count = 2 if player_capacity >= 10000 else 1
    
    # Global Accelerator
    enable_global_accelerator = player_capacity >= 1000
    
    # ECS desired count
    if player_capacity < 5000:
        desired_count = 1
    else:
        desired_count = max(2, math.ceil(player_capacity / 5000))
    
    return {
        "cpu_vcpu": cpu_vcpu,
        "cpu_units": rounded_cpu,
        "memory_gb": memory_gb,
        "memory_mb": memory_mb,
        "desired_count": desired_count,
        "redis_node_type": redis_node_type,
        "redis_replica_count": redis_replica_count,
        "efs_performance_mode": efs_performance_mode,
        "nat_gateway_count": nat_gateway_count,
        "enable_global_accelerator": enable_global_accelerator,
    }


def calculate_costs(resources):
    """Calculate monthly costs based on resources."""
    # ECS cost
    ecs_cost = (resources["cpu_vcpu"] * ECS_CPU_PRICE_PER_VCPU_HOUR +
                resources["memory_gb"] * ECS_MEMORY_PRICE_PER_GB_HOUR) * \
               HOURS_PER_MONTH * resources["desired_count"]
    
    # Redis cost
    redis_hourly = REDIS_HOURLY_PRICING.get(resources["redis_node_type"], 0.017)
    redis_cost = redis_hourly * HOURS_PER_MONTH * (resources["redis_replica_count"] + 1)
    
    # EFS cost
    efs_cost = EFS_BASELINE_STORAGE_GB * EFS_STORAGE_PRICE_PER_GB_MONTH
    
    # NAT Gateway cost
    nat_cost = resources["nat_gateway_count"] * NAT_GATEWAY_PRICE_PER_MONTH
    
    # ALB cost
    alb_cost = ALB_BASE_PRICE_PER_MONTH
    
    # Global Accelerator cost
    accelerator_cost = GLOBAL_ACCELERATOR_PRICE_PER_MONTH if resources["enable_global_accelerator"] else 0
    
    # Total cost
    total_cost = ecs_cost + redis_cost + efs_cost + nat_cost + alb_cost + accelerator_cost
    
    return {
        "ecs": round(ecs_cost, 2),
        "redis": round(redis_cost, 2),
        "efs": round(efs_cost, 2),
        "nat": round(nat_cost, 2),
        "alb": round(alb_cost, 2),
        "accelerator": round(accelerator_cost, 2),
        "total": round(total_cost, 2),
    }


def main():
    """Main function."""
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/calculate-cost.py <player_capacity> [--json]")
        sys.exit(1)
    
    try:
        player_capacity = int(sys.argv[1])
    except ValueError:
        print(f"Error: Invalid player capacity '{sys.argv[1]}'. Must be an integer.")
        sys.exit(1)
    
    if player_capacity < 100 or player_capacity > 50000:
        print(f"Error: Player capacity must be between 100 and 50,000.")
        sys.exit(1)
    
    json_output = "--json" in sys.argv
    
    # Calculate resources and costs
    resources = calculate_resources(player_capacity)
    costs = calculate_costs(resources)
    
    if json_output:
        output = {
            "player_capacity": player_capacity,
            "resources": {
                "ecs_cpu": resources["cpu_units"],
                "ecs_memory": int(resources["memory_mb"]),
                "ecs_desired_count": resources["desired_count"],
                "redis_node_type": resources["redis_node_type"],
                "redis_replica_count": resources["redis_replica_count"],
                "efs_performance_mode": resources["efs_performance_mode"],
                "nat_gateway_count": resources["nat_gateway_count"],
                "enable_global_accelerator": resources["enable_global_accelerator"],
            },
            "costs": costs,
        }
        print(json.dumps(output, indent=2))
    else:
        print(f"Cost Estimate for {player_capacity} Players")
        print("=" * 50)
        print(f"\nResource Configuration:")
        print(f"  ECS CPU: {resources['cpu_units']} units ({resources['cpu_vcpu']} vCPU)")
        print(f"  ECS Memory: {int(resources['memory_mb'])} MB ({resources['memory_gb']:.1f} GB)")
        print(f"  ECS Tasks: {resources['desired_count']}")
        print(f"  Redis: {resources['redis_node_type']} ({resources['redis_replica_count'] + 1} nodes)")
        print(f"  EFS: {resources['efs_performance_mode']}")
        print(f"  NAT Gateways: {resources['nat_gateway_count']}")
        print(f"  Global Accelerator: {'Enabled' if resources['enable_global_accelerator'] else 'Disabled'}")
        print(f"\nMonthly Cost Breakdown:")
        print(f"  ECS Fargate:     ${costs['ecs']:.2f}/month")
        print(f"  ElastiCache:     ${costs['redis']:.2f}/month")
        print(f"  EFS Storage:     ${costs['efs']:.2f}/month")
        print(f"  NAT Gateways:    ${costs['nat']:.2f}/month")
        print(f"  Load Balancer:   ${costs['alb']:.2f}/month")
        print(f"  Global Accel:    ${costs['accelerator']:.2f}/month")
        print(f"  {'-' * 50}")
        print(f"  Total:           ${costs['total']:.2f}/month")


if __name__ == "__main__":
    main()

