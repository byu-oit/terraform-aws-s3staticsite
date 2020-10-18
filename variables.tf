variable "index_doc" {
  type        = string
  default     = "index.html"
  description = "The index document of the site."
}

variable "encryption_key_id" {
  type        = string
  default     = ""
  description = "The AWS KMS master key ID used for the SSE-KMS encryption."
}

variable "site_url" {
  type        = string
  description = "The URL for the site."
}

variable "wait_for_deployment" {
  type        = string
  description = "Define if Terraform should wait for the distribution to deploy before completing."
  default     = true
}

variable "s3_bucket_name" {
  type        = string
  description = "Name of S3 bucket for website"
}

variable "tags" {
  type        = map(string)
  description = "A map of AWS Tags to attach to each resource created"
  default     = {}
}

variable "cloudfront_price_class" {
  type        = string
  description = "The price class for the cloudfront distribution"
  default     = "PriceClass_100"
}

variable "hosted_zone_id" {
  type        = string
  description = "hosted zone id"
}

variable "cors_rules" {
  type        = list(object({ allowed_headers = list(string), allowed_methods = list(string), allowed_origins = list(string), expose_headers = list(string), max_age_seconds = number }))
  default     = []
  description = "cors policy rules"
}

variable "log_cookies" {
  type        = bool
  default     = false
  description = "Include cookies in the CloudFront access logs."
}
