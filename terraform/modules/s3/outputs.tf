output "buckets" {
  description = "Map of logical name to actual bucket name"
  value       = { for k, v in aws_s3_bucket.this : k => v.bucket }
}

output "bucket_arns" {
  description = "Map of logical name to bucket ARN"
  value       = { for k, v in aws_s3_bucket.this : k => v.arn }
}

output "bucket_regions" {
  description = "Map of logical name to bucket region"
  value       = { for k, v in aws_s3_bucket.this : k => v.region }
}
