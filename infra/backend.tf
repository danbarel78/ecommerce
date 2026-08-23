# Remote state backend (partial configuration).
#
# The bucket / dynamodb_table / region below are intentionally left unset so this
# repo carries no account-specific values. Supply them at init time, e.g.:
#
#   terraform init \
#     -backend-config="bucket=REQUIRES_REAL_VALUE-tfstate-bucket" \
#     -backend-config="dynamodb_table=REQUIRES_REAL_VALUE-tf-lock" \
#     -backend-config="region=us-east-1" \
#     -backend-config="key=ecommerce/dev/terraform.tfstate"
#
# For local validation without a backend, run: terraform init -backend=false
terraform {
  backend "s3" {
    encrypt = true
    # bucket         = REQUIRES REAL VALUE (via -backend-config)
    # dynamodb_table = REQUIRES REAL VALUE (via -backend-config)
    # region         = REQUIRES REAL VALUE (via -backend-config)
    # key            = REQUIRES REAL VALUE (via -backend-config)
  }
}
