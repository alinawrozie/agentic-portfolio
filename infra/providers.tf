terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

# Primary provider — used for S3, Lambda, API Gateway, SES, CloudWatch.
# Pick whichever region you want these resources to live in.
provider "aws" {
  region = var.aws_region
}

# CloudFront only accepts ACM certificates issued in us-east-1,
# regardless of which region everything else runs in.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
