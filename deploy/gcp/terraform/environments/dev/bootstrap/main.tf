module "bootstrap" {
  source = "../../../modules/bootstrap"

  org_id          = local.org_id
  billing_account = local.billing_account
  project_id      = local.project_id
  region          = local.region
  environment     = local.environment
}
