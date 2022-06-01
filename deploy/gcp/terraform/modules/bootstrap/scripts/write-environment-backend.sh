#!/bin/bash

ENVIRONMENT=$1
ENVIRONMENT_DIR="../../../environments/$ENVIRONMENT"

# Push bootstrap terraform state to Google Storage bucket
TERRAFORM_STATE_FILE="$ENVIRONMENT_DIR/bootstrap/terraform.tfstate"
TERRAFORM_STATE_BUCKET_URL=$(terraform output -raw -state="$TERRAFORM_STATE_FILE" terraform_state_bucket_url || exit 1)
gsutil cp "$TERRAFORM_STATE_FILE" "$TERRAFORM_STATE_BUCKET_URL/bootstrap" || exit 1

# Write the backend file
TERRAFORM_STATE_BUCKET=$(terraform output -raw -state="$TERRAFORM_STATE_FILE" terraform_state_bucket || exit 1)

cat << EOF > "$ENVIRONMENT_DIR"/backend.tf
terraform {
  backend "gcs" {
    bucket = "$TERRAFORM_STATE_BUCKET"
    prefix = "$ENVIRONMENT"
  }
}
EOF
