terraform {
  required_version = ">= 1.6.0"

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

# Primary region for most resources.
provider "aws" {
  region = var.aws_region
}

# CloudFront only accepts ACM certificates issued in us-east-1, no matter
# which region the distribution's other resources live in. This alias lets
# the acm.tf resources target us-east-1 specifically while everything else
# uses var.aws_region.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
