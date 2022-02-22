provider "google" {
  project = var.project
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
  location      = var.location
  force_destroy = true
}

resource "google_storage_bucket_object" "conduit_db_init_sql" {
  name   = "20220215161400_initial_create.sql"
  source = "../../../initdb/20220215161400_initial_create.sql"
  bucket = google_storage_bucket.conduit_db_init_sql.name
}

resource "google_storage_bucket_iam_member" "db_instance_master_sa_init_sql_bucket" {
  bucket = google_storage_bucket.conduit_db_init_sql.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_sql_database_instance.master.service_account_email_address}"
}

resource "null_resource" "conduit_db_import_init_sql" {
  provisioner "local-exec" {
    command = "gcloud sql import sql ${google_sql_database_instance.master.name} gs://${google_storage_bucket.conduit_db_init_sql.name}/${google_storage_bucket_object.conduit_db_init_sql.name} --database=${google_sql_database.conduit_db.name} --quiet"
  }
  depends_on = [
    google_storage_bucket_iam_member.db_instance_master_sa_init_sql_bucket
  ]
}

resource "google_project_service" "cloud_run_service" {
  service = "run.googleapis.com"
}

resource "google_project_iam_member" "cloud_run_sa_sql_client_role" {
  project = var.project
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${var.project_number}-compute@developer.gserviceaccount.com"
}

resource "google_cloud_run_service" "conduit_server" {
  name     = "conduit-server"
  location = var.location

  template {
    spec {
      containers {
        image = var.image
        env {
          name  = "ENVIRONMENT"
          value = var.environment
        }
        env {
          name  = "AUTH_SECRET_KEY"
          value = var.auth_secret_key
        }
        env {
          name  = "AUTH_ISSUER"
          value = var.auth_issuer
        }
        env {
          name  = "DB_HOST"
          value = "/cloudsql/${google_sql_database_instance.master.connection_name}"
        }
        env {
          name  = "DB_PORT"
          value = 5432
        }
        env {
          name  = "DB_NAME"
          value = google_sql_database.conduit_db.name
        }
        env {
          name  = "DB_USER"
          value = google_sql_user.master_user.name
        }
        env {
          name  = "DB_PASSWORD"
          value = google_sql_user.master_user.password
        }
        env {
          name  = "USE_UNIX_SOCKET"
          value = "true"
        }
      }
    }

    metadata {
      annotations = {
        "run.googleapis.com/cloudsql-instances" = google_sql_database_instance.master.connection_name
      }
    }
  }

  depends_on = [
    google_project_service.cloud_run_service,
    google_project_iam_member.cloud_run_sa_sql_client_role,
    null_resource.conduit_db_import_init_sql
  ]
}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "conduit_server_noauth" {
  location = google_cloud_run_service.conduit_server.location
  project  = google_cloud_run_service.conduit_server.project
  service  = google_cloud_run_service.conduit_server.name

  policy_data = data.google_iam_policy.noauth.policy_data
}
