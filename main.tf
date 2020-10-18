terraform {
  required_version = ">= 0.12.16"
  required_providers {
    aws = ">= 3.0"
  }
}

provider "aws" {
  alias  = "aws_n_va"
  region = "us-east-1"
}

resource "aws_acm_certificate" "cert" {
  provider          = aws.aws_n_va
  domain_name       = var.site_url
  validation_method = "DNS"
  tags              = var.tags
}

resource "aws_acm_certificate_validation" "cert" {
  provider                = aws.aws_n_va
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  provider = aws.aws_n_va
  name     = each.value.name
  type     = each.value.type
  zone_id  = var.hosted_zone_id
  records  = [each.value.record]
  ttl      = 60
}

resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = var.origin_path
}

resource "aws_cloudfront_distribution" "cdn" {
  price_class = var.cloudfront_price_class
  origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.website.bucket

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  comment             = "CDN for ${var.site_url}"
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = var.index_doc
  aliases             = [var.site_url]

  default_cache_behavior {
    target_origin_id = aws_s3_bucket.website.bucket
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2019"
  }

  wait_for_deployment = var.wait_for_deployment
  tags                = var.tags
}

resource "aws_route53_record" "custom-url-a" {
  name    = var.site_url
  type    = "A"
  zone_id = var.hosted_zone_id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
  }
}

resource "aws_route53_record" "custom-url-4a" {
  name    = var.site_url
  type    = "AAAA"
  zone_id = var.hosted_zone_id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
  }
}

resource "aws_s3_bucket" "website" {
  bucket = var.s3_bucket_name
  tags   = var.tags

  website {
    index_document = var.index_doc
    error_document = var.error_doc
  }

  lifecycle_rule {
    enabled                                = true
    abort_incomplete_multipart_upload_days = 10
    id                                     = "AutoAbortFailedMultipartUpload"

    expiration {
      days                         = 0
      expired_object_delete_marker = false
    }
  }

  dynamic "cors_rule" {
    for_each = var.cors_rules
    content {
      allowed_headers = cors_rule.value["allowed_headers"]
      allowed_methods = cors_rule.value["allowed_methods"]
      allowed_origins = cors_rule.value["allowed_origins"]
      expose_headers  = cors_rule.value["expose_headers"]
      max_age_seconds = cors_rule.value["max_age_seconds"]
    }
  }
}

data "aws_iam_policy_document" "static_website" {
  statement {
    sid       = "1"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website.arn}/*"]

    principals {
      identifiers = [aws_cloudfront_origin_access_identity.oai.iam_arn]
      type        = "AWS"
    }
  }
}

resource "aws_s3_bucket_policy" "static_website_read" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.static_website.json
}
