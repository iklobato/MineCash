output "efs_id" {
  description = "EFS file system ID"
  value       = aws_efs_file_system.main.id
}

output "efs_dns_name" {
  description = "EFS DNS name for mounting"
  value       = aws_efs_file_system.main.dns_name
}

output "efs_security_group_id" {
  description = "EFS security group ID"
  value       = aws_security_group.efs.id
}

output "efs_arn" {
  description = "EFS file system ARN"
  value       = aws_efs_file_system.main.arn
}


