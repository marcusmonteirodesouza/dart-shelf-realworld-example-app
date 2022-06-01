data "google_project" "conduit" {
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_project_service" "cloud_run_service" {
  service = "run.googleapis.com"
}

resource "google_project_iam_member" "cloud_run_sa_sql_client_role" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${data.google_project.conduit.number}-compute@developer.gserviceaccount.com"
}

resource "google_cloud_run_service" "conduit_server" {
  name     = "conduit-server"
  location = var.region

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
          value = var.db_host
        }
        env {
          name  = "DB_PORT"
          value = var.db_port
        }
        env {
          name  = "DB_NAME"
          value = var.db_name
        }
        env {
          name  = "DB_USER"
          value = var.db_user
        }
        env {
          name  = "DB_PASSWORD"
          value = var.db_password
        }
        env {
          name  = "USE_UNIX_SOCKET"
          value = "true"
        }
      }
    }

    metadata {
      annotations = {
        "run.googleapis.com/cloudsql-instances"    = var.db_connection_name
        "run.googleapis.com/execution-environment" = "gen2"
      }
    }
  }

  metadata {
    annotations = {
      "run.googleapis.com/launch-stage" = "BETA"
    }
  }

  depends_on = [
    google_project_service.cloud_run_service,
    google_project_iam_member.cloud_run_sa_sql_client_role,
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
