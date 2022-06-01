resource "google_project" "conduit" {
  name                = var.project_id
  project_id          = var.project_id
  org_id              = var.org_id
  billing_account     = var.billing_account
  auto_create_network = false
}

# Artifact Registry
resource "google_project_service" "artifactregistry_api" {
  project            = google_project.conduit.project_id
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "conduit" {
  provider      = google-beta
  project       = google_project.conduit.project_id
  location      = var.region
  repository_id = "conduit-server"
  description   = "Conduit Server App"
  format        = "DOCKER"

  depends_on = [
    google_project_service.artifactregistry_api,
  ]
}

# Terraform State Bucket
resource "google_storage_bucket" "terraform_state" {
  project  = google_project.conduit.project_id
  name     = "terraform-state-${google_project.conduit.project_id}"
  location = var.region

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

# Write Environment terraform backend file
resource "null_resource" "write_environment_backend_file" {
  provisioner "local-exec" {
    command     = "./write-environment-backend.sh ${var.environment}"
    working_dir = "${path.module}/scripts"
  }

  triggers = {
    always_run = "${timestamp()}"
  }

  depends_on = [
    google_storage_bucket.terraform_state
  ]
}
