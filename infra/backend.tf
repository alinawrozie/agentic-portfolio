# This points at the S3 bucket + DynamoDB table created by infra/bootstrap.
# Fill in the bucket/dynamodb_table values with the outputs from
# `terraform apply` in infra/bootstrap, then run `terraform init` here.
#
# Terraform does not allow variables inside a backend block, so these
# values must be hardcoded (or passed via `-backend-config=` flags in CI).

terraform {
  backend "s3" {
    bucket         = "nawrozie-portfolio-tfstate" # <- replace with infra/bootstrap output: state_bucket_name
    key            = "portfolio/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "nawrozie-portfolio-tfstate-locks" # <- replace with infra/bootstrap output: lock_table_name
    encrypt        = true
  }
}
