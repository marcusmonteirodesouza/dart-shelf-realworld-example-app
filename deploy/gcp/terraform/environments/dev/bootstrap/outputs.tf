output "terraform_state_bucket" {
  value = module.bootstrap.terraform_state_bucket.name
}

output "terraform_state_bucket_url" {
  value = module.bootstrap.terraform_state_bucket.url
}
