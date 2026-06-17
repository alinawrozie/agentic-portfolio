variable "domain_name" {
  description = "Root domain for the portfolio, e.g. yourname.com. Must already be a registered domain."
  type        = string
}

variable "aws_region" {
  description = "Region for S3, Lambda, API Gateway, SES and CloudWatch."
  type        = string
  default     = "eu-west-2"
}

variable "create_hosted_zone" {
  description = "true if Route 53 should create a new hosted zone for domain_name. false if you already have one (e.g. because you registered the domain through Route 53, which creates a zone automatically)."
  type        = bool
  default     = false
}

variable "sender_email" {
  description = "Email address the contact form sends FROM. Must be verified in SES (SES sandbox mode requires this regardless of recipient)."
  type        = string
}

variable "recipient_email" {
  description = "Your email address — where contact form submissions and CloudWatch alarms are delivered. Must also be verified in SES while your account is in sandbox mode."
  type        = string
}

variable "lambda_runtime" {
  description = "Lambda Python runtime."
  type        = string
  default     = "python3.12"
}

variable "cloudfront_price_class" {
  description = "PriceClass_100 (NA/EU only, cheapest), PriceClass_200, or PriceClass_All."
  type        = string
  default     = "PriceClass_100"
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default = {
    Project = "personal-portfolio"
  }
}
