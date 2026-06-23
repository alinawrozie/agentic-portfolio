# If this is the first time deploying, Route 53 creates the hosted zone for
# you - after the first apply, go update your domain registrar's (or AWS
# Route 53 domain registration's) nameservers to the ones in the
# `route53_nameservers` output, then wait for propagation before relying on
# the domain. If you already had a zone and registered nameservers
# elsewhere, set create_route53_zone = false and the data source below will
# look it up instead.

resource "aws_route53_zone" "primary" {
  count = var.create_route53_zone ? 1 : 0
  name  = var.domain_name
}

data "aws_route53_zone" "primary" {
  count = var.create_route53_zone ? 0 : 1
  name  = var.domain_name
}

locals {
  zone_id = var.create_route53_zone ? aws_route53_zone.primary[0].zone_id : data.aws_route53_zone.primary[0].zone_id
}
