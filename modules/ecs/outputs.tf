output "ecs_cluster_id" {
  description = "ECS cluster ID/ARN"
  value       = aws_ecs_cluster.main.id
}

output "ecs_service_id" {
  description = "ECS service ID"
  value       = aws_ecs_service.main.id
}

output "ecs_task_security_group_id" {
  description = "ECS task security group ID"
  value       = aws_security_group.ecs_task.id
}

output "ecs_task_definition_arn" {
  description = "ECS task definition ARN"
  value       = aws_ecs_task_definition.main.arn
}


