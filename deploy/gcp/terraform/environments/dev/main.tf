module "database" {
  source = "../../modules/database"

  project_id  = local.project_id
  region      = local.region
  db_user     = local.db_user
  db_password = local.db_password
}

module "cloud_run" {
  source = "../../modules/cloud_run"

  project_id         = local.project_id
  region             = local.region
  image              = local.image
  environment        = local.environment
  auth_secret_key    = local.auth_secret_key
  auth_issuer        = local.auth_issuer
  db_host            = module.database.db_host
  db_port            = module.database.db_port
  db_name            = module.database.db_name
  db_user            = local.db_user
  db_password        = local.db_password
  db_connection_name = module.database.connection_name
}
