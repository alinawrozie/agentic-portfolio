output "site_url" {
  description = "Your live portfolio URL"
  value       = "https://${var.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "Needed by the CI/CD workflow to invalidate the cache after deploying new frontend files"
  value       = aws_cloudfront_distribution.site.id
}

output "s3_bucket_name" {
  description = "Needed by the CI/CD workflow to sync the frontend/ files"
  value       = aws_s3_bucket.site.id
}

output "route53_nameservers" {
  description = "If create_route53_zone = true, point your domain registrar at these nameservers"
  value       = var.create_route53_zone ? aws_route53_zone.primary[0].name_servers : []
}

output "contact_api_endpoint" {
  description = "The contact form POST endpoint - this is what frontend/script.js should fetch() to"
  value       = "${aws_apigatewayv2_api.contact_form.api_endpoint}/contact"
}

output "ses_sender_verification_note" {
  description = "Reminder"
  value       = "Check ${var.ses_sender_email} (and recipient, if different) inbox for an AWS SES verification email and click the link before testing the contact form."
}
