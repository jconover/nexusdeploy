output "connection_name" {
  description = "The connection name of the Cloud SQL instance"
  value       = google_sql_database_instance.main.connection_name
}

output "private_ip" {
  description = "The private IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.main.private_ip_address
}

output "database_name" {
  description = "The name of the database"
  value       = google_sql_database.main.name
}

output "instance_name" {
  description = "The name of the Cloud SQL instance"
  value       = google_sql_database_instance.main.name
}

output "database_user" {
  description = "The database user name"
  value       = google_sql_user.main.name
}

output "password_secret_id" {
  description = "The Secret Manager secret ID containing the database password"
  value       = google_secret_manager_secret.db_password.secret_id
}
