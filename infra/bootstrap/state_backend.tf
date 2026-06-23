# -----------------------------------------------------------------------------
# Remote state backend for the main infra/ Terraform configuration.
#
# Why this exists as a separate, manually-applied module: Terraform can't
# create the S3 bucket it then immediately uses as its own backend in the
# same config (chicken-and-egg). So this small bootstrap module is applied
# once by hand, and everything else (including CI/CD) builds on top of it.
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Locking prevents two concurrent `terraform apply` runs (e.g. you running
# one locally while a GitHub Actions run is mid-flight) from corrupting state.
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.state_bucket_name}-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
