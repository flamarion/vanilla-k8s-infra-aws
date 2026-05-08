variable "namespace" {
  description = "Prefix for bucket names"
  type        = string
}

variable "buckets" {
  description = "Map of bucket short name to configuration"
  type = map(object({
    versioning_status = optional(string, "Suspended")
    manage_versioning = optional(bool, false)
    lifecycle_enabled = optional(bool, false)
    cors_enabled      = optional(bool, false)
    force_destroy     = optional(bool, true)
  }))
  default = {}
}

variable "cors_configuration" {
  description = "CORS rules applied to buckets with cors_enabled=true"
  type = object({
    allowed_headers = list(string)
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = list(string)
    max_age_seconds = number
  })
  default = {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3600
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
