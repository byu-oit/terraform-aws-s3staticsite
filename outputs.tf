output "site_bucket" {
  value = aws_s3_bucket.website
}

output "cf_distribution" {
  value = aws_cloudfront_distribution.cdn
}

output "dns_record" {
  value = aws_route53_record.custom_url_a
}
