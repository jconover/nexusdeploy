output "endpoint" {
  description = "Full connection endpoint (host:port)"
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "Hostname of the RDS instance"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Port the RDS instance is listening on"
  value       = aws_db_instance.this.port
}

output "database_name" {
  description = "Name of the database"
  value       = aws_db_instance.this.db_name
}

output "instance_identifier" {
  description = "Identifier of the RDS instance"
  value       = aws_db_instance.this.identifier
}

output "database_user" {
  description = "Master username for the database"
  value       = aws_db_instance.this.username
}

output "master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the master user password"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
  sensitive   = true
}

output "security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.this.id
}
