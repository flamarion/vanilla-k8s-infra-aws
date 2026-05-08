terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1"
    }
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "this" {
  for_each = var.buckets

  bucket        = "${var.namespace}-${each.key}-${random_string.suffix.result}"
  force_destroy = each.value.force_destroy

  tags = merge(var.tags, {
    Name    = "${var.namespace}-${each.key}"
    Purpose = each.key
  })
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = { for k, v in var.buckets : k => v if v.manage_versioning }

  bucket = aws_s3_bucket.this[each.key].id
  versioning_configuration {
    status = each.value.versioning_status
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  for_each = { for k, v in var.buckets : k => v if v.lifecycle_enabled }

  bucket     = aws_s3_bucket.this[each.key].id
  depends_on = [aws_s3_bucket_versioning.this]

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      newer_noncurrent_versions = 1
      noncurrent_days           = 1
    }
    expiration {
      expired_object_delete_marker = true
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "this" {
  for_each = { for k, v in var.buckets : k => v if v.cors_enabled }

  bucket = aws_s3_bucket.this[each.key].id

  cors_rule {
    allowed_headers = var.cors_configuration.allowed_headers
    allowed_methods = var.cors_configuration.allowed_methods
    allowed_origins = var.cors_configuration.allowed_origins
    expose_headers  = var.cors_configuration.expose_headers
    max_age_seconds = var.cors_configuration.max_age_seconds
  }
}
