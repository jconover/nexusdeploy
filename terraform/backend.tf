# GCS backend for remote state management.
# Initialize per environment:
#
#   terraform init \
#     -backend-config="bucket=nexusdeploy-tfstate-dev" \
#     -backend-config="prefix=terraform/state/dev"
#
#   terraform init \
#     -backend-config="bucket=nexusdeploy-tfstate-staging" \
#     -backend-config="prefix=terraform/state/staging"
#
#   terraform init \
#     -backend-config="bucket=nexusdeploy-tfstate-prod" \
#     -backend-config="prefix=terraform/state/prod"
#
# Or use the Makefile:  make init ENV=dev

terraform {
  backend "gcs" {
    # bucket and prefix are supplied at init time via -backend-config flags
    # or environment-specific backend config files (see environments/*/backend.hcl)
  }
}
