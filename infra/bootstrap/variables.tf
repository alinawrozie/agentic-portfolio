variable "aws_region" {
  description = "AWS region for the Terraform state backend resources"
  type        = string
  default     = "eu-west-2"
}

variable "state_bucket_name" {
  description = "Globally-unique S3 bucket name to hold Terraform remote state for the main infra/ config"
  type        = string
}

variable "github_org" {
  description = "Your GitHub username or organisation"
  type        = string
}

variable "github_repo" {
  description = "The GitHub repository name (without org prefix) that is allowed to assume the deploy role"
  type        = string
}

variable "github_branch" {
  description = "Branch allowed to deploy via OIDC (use '*' to allow any branch, not recommended)"
  type        = string
  default     = "main"
}

variable "domain_name" {
  description = "The domain name used for the S3 site bucket (e.g. nawrozie.com). Used to scope S3 object-level IAM permissions."
  type        = string
}

variable "project_name" {
  description = "Short name used as a prefix for resource naming in the main config"
  type        = string
  default     = "portfolio"
}

