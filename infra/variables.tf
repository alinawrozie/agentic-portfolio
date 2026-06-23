variable "aws_region" {
  description = "Primary AWS region for S3, Lambda, API Gateway, etc."
  type        = string
  default     = "eu-west-2"
}

variable "domain_name" {
  description = "Your apex domain, e.g. yourname.com"
  type        = string
}

variable "create_route53_zone" {
  description = "Set true if Route 53 should create the hosted zone (first-time setup). Set false if you already have a zone and are importing it instead."
  type        = bool
  default     = true
}

variable "contact_form_recipient_email" {
  description = "The email address that receives contact form submissions. Must be SES-verified while SES is in sandbox mode."
  type        = string
}

variable "ses_sender_email" {
  description = "The 'from' address SES sends with. Must be SES-verified while SES is in sandbox mode. Can be the same as contact_form_recipient_email."
  type        = string
}

variable "alarm_notification_email" {
  description = "Email address to receive CloudWatch alarm notifications (Lambda errors)"
  type        = string
}

variable "project_name" {
  description = "Short name used as a prefix for resource naming"
  type        = string
  default     = "portfolio"
}
