locals {
  project_id      = "<PROJECT_ID>"
  region          = "<REGION>"
  environment     = "dev"
  image           = "<IMAGE>"
  db_user         = "<DB_USER>"         # TODO(Use a Secret Manager for this!)
  db_password     = "<DB_PASSWORD>"     # TODO(Use a Secret Manager for this!)
  auth_secret_key = "<AUTH_SECRET_KEY>" # TODO(Use a Secret Manager for this!)
  auth_issuer     = "https://conduit/api"
}
