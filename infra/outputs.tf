output "site_url" {
  description = "Your live site."
  value       = "https://${var.domain_name}"
}

output "s3_bucket_name" {
  description = "Paste into scripts/deploy.sh / GitHub Actions secret S3_BUCKET."
  value       = aws_s3_bucket.site.bucket
}

output "cloudfront_distribution_id" {
  description = "Paste into scripts/deploy.sh / GitHub Actions secret CLOUDFRONT_DISTRIBUTION_ID — needed to invalidate the cache on each deploy."
  value       = aws_cloudfront_distribution.site.id
}

output "api_endpoint" {
  description = "Paste into site/script.js as API_ENDPOINT."
  value       = "${aws_apigatewayv2_api.contact.api_endpoint}/contact"
}

output "name_servers" {
  description = "If create_hosted_zone = true, point your domain registrar at these."
  value       = var.create_hosted_zone ? aws_route53_zone.this[0].name_servers : []
}
