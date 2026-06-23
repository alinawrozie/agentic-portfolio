terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # This bootstrap module is applied manually, once, by you, using your own
  # AWS credentials (e.g. `aws configure`). It has no remote backend on
  # purpose — it CREATES the remote backend that the main `infra/` config
  # uses. Its local terraform.tfstate file should stay out of git
  # (see .gitignore) but you should keep a personal backup of it, since it's
  # the only record of these resources unless you import them again.
}

provider "aws" {
  region = var.aws_region
}
