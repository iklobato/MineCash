# Route 53 DNS Module Outputs

output "fqdn" {
  description = "Fully-qualified domain name (FQDN) of the created DNS record. This is the hostname that players use to connect to the Minecraft server."
  value       = aws_route53_record.main.fqdn
}

output "record_name" {
  description = "Route 53 record name (may include trailing dot, as Route 53 stores it). Useful for reference in other Route 53 operations or debugging."
  value       = aws_route53_record.main.name
}
