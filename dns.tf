# Route53 zone for mountain-race.eravest.fr
# One-time OVH setup: add 4 NS records for mountain-race.eravest.fr pointing to route53_name_servers output
resource "aws_route53_zone" "mountain_race" {
  name = "mountain-race.eravest.fr"
  tags = { Name = "mountain-race" }
}

output "route53_name_servers" {
  description = "Add these as NS records for mountain-race.eravest.fr in OVH (one-time)"
  value       = aws_route53_zone.mountain_race.name_servers
}

# ACM certificate — must be in us-east-1 for CloudFront
resource "aws_acm_certificate" "mountain_race" {
  provider          = aws.us_east_1
  domain_name       = "mountain-race.eravest.fr"
  validation_method = "DNS"
  tags              = { Name = "mountain-race" }

  lifecycle { create_before_destroy = true }
}

# Validation CNAME record — created automatically in Route53
resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.mountain_race.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }
  zone_id = aws_route53_zone.mountain_race.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "mountain_race" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.mountain_race.arn
  validation_record_fqdns = [for r in aws_route53_record.acm_validation : r.fqdn]
}

# Origin hostname — stable DNS name for CloudFront to reach the Fargate task
# Lambda updates the A record on each task start
resource "aws_route53_record" "origin" {
  zone_id = aws_route53_zone.mountain_race.zone_id
  name    = "origin.mountain-race.eravest.fr"
  type    = "A"
  ttl     = 60
  records = ["127.0.0.1"] # placeholder; Lambda overwrites on first task start

  lifecycle { ignore_changes = [records] }
}

# Public CNAME: mountain-race.eravest.fr → CloudFront (Terraform managed, stable)
resource "aws_route53_record" "mountain_race" {
  zone_id = aws_route53_zone.mountain_race.zone_id
  name    = "mountain-race.eravest.fr"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.mountain_race.domain_name
    zone_id                = aws_cloudfront_distribution.mountain_race.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_cloudfront_distribution" "mountain_race" {
  enabled         = true
  aliases         = ["mountain-race.eravest.fr"]
  price_class     = "PriceClass_100"
  http_version    = "http2"
  is_ipv6_enabled = true

  origin {
    origin_id   = "fargate"
    domain_name = aws_route53_record.origin.fqdn

    custom_origin_config {
      http_port              = 8003
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "fargate"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = true
      headers      = ["*"]
      cookies { forward = "all" }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.mountain_race.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  tags = { Name = "mountain-race" }
}

module "dns_updater" {
  source = "git::https://github.com/yarichard/terraform-bootstrap.git//modules/fargate-dns-updater?ref=main"

  app_name         = "mountain-race"
  region           = var.region
  aws_account_id   = var.aws_account_id
  ecs_cluster_arn  = aws_ecs_cluster.mountain_race.arn
  ecs_cluster_name = aws_ecs_cluster.mountain_race.name
  hosted_zone_id   = aws_route53_zone.mountain_race.zone_id
  origin_hostname  = "origin.mountain-race.eravest.fr."
}
