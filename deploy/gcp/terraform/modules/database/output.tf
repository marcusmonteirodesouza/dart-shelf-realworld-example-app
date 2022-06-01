output "db_host" {
  value = "/cloudsql/${google_sql_database_instance.master.connection_name}"
}

output "db_port" {
  value = 5432
}

output "db_name" {
  value = google_sql_database.conduit_db.name
}

output "connection_name" {
  value = google_sql_database_instance.master.connection_name
}
