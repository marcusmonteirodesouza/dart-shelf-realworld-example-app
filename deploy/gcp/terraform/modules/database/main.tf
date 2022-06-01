provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_project_service" "sqladmin_service" {
  service = "sqladmin.googleapis.com"
}

resource "random_id" "db_name_suffix" {
  byte_length = 4
}

resource "google_sql_database_instance" "master" {
  name             = "master-instance-${random_id.db_name_suffix.hex}"
  database_version = "POSTGRES_13"

  settings {
    tier = "db-f1-micro"
  }

  depends_on = [
    google_project_service.sqladmin_service
  ]
}

resource "google_sql_user" "master_user" {
  name     = var.db_user
  password = var.db_password
  instance = google_sql_database_instance.master.name
}

resource "google_sql_database" "conduit_db" {
  name     = "conduit"
  instance = google_sql_database_instance.master.name
}

resource "google_storage_bucket" "conduit_db_init_sql" {
  name          = "conduit-db-init-sql-${random_id.db_name_suffix.hex}"
  location      = var.region
  force_destroy = true
}

resource "google_storage_bucket_object" "conduit_db_init_sql" {
  name   = "20220215161400_initial_create.sql"
  source = "../../../../../initdb/20220215161400_initial_create.sql"
  bucket = google_storage_bucket.conduit_db_init_sql.name
}

resource "google_storage_bucket_iam_member" "db_instance_master_sa_init_sql_bucket" {
  bucket = google_storage_bucket.conduit_db_init_sql.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_sql_database_instance.master.service_account_email_address}"
}

resource "null_resource" "conduit_db_import_init_sql" {
  provisioner "local-exec" {
    command = "gcloud sql import sql ${google_sql_database_instance.master.name} gs://${google_storage_bucket.conduit_db_init_sql.name}/${google_storage_bucket_object.conduit_db_init_sql.name} --project=${var.project_id} --database=${google_sql_database.conduit_db.name} --quiet"
  }
  depends_on = [
    google_storage_bucket_iam_member.db_instance_master_sa_init_sql_bucket
  ]
}
