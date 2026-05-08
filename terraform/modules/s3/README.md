# S3 Module

Generic S3 bucket provisioning with optional versioning, lifecycle policies,
and CORS configuration.

Bucket names are globally unique via a random 8-character suffix:
`{namespace}-{key}-{suffix}`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_cors_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_cors_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_buckets"></a> [buckets](#input\_buckets) | Map of bucket short name to configuration | <pre>map(object({<br/>    versioning_status = optional(string, "Suspended")<br/>    manage_versioning = optional(bool, false)<br/>    lifecycle_enabled = optional(bool, false)<br/>    cors_enabled      = optional(bool, false)<br/>    force_destroy     = optional(bool, true)<br/>  }))</pre> | `{}` | no |
| <a name="input_cors_configuration"></a> [cors\_configuration](#input\_cors\_configuration) | CORS rules applied to buckets with cors\_enabled=true | <pre>object({<br/>    allowed_headers = list(string)<br/>    allowed_methods = list(string)<br/>    allowed_origins = list(string)<br/>    expose_headers  = list(string)<br/>    max_age_seconds = number<br/>  })</pre> | <pre>{<br/>  "allowed_headers": [<br/>    "*"<br/>  ],<br/>  "allowed_methods": [<br/>    "GET",<br/>    "PUT",<br/>    "POST",<br/>    "DELETE",<br/>    "HEAD"<br/>  ],<br/>  "allowed_origins": [<br/>    "*"<br/>  ],<br/>  "expose_headers": [<br/>    "ETag"<br/>  ],<br/>  "max_age_seconds": 3600<br/>}</pre> | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Prefix for bucket names | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | n/a | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_arns"></a> [bucket\_arns](#output\_bucket\_arns) | Map of logical name to bucket ARN |
| <a name="output_bucket_regions"></a> [bucket\_regions](#output\_bucket\_regions) | Map of logical name to bucket region |
| <a name="output_buckets"></a> [buckets](#output\_buckets) | Map of logical name to actual bucket name |
<!-- END_TF_DOCS -->
