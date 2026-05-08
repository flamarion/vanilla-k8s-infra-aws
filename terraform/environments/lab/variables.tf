# Provider variables (not passed to the module)
variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI named profile"
  type        = string
  default     = null
}

# Module variables (passed through to the root module)
variable "namespace" {
  type = string
}

variable "instances" {
  type = map(object({
    role          = string
    instance_type = string
    volume_size   = number
    subnet_type   = string
  }))
}

variable "ssh_public_key" {
  type = string
}

variable "allowed_ssh_cidrs" {
  type = list(string)
}

variable "vpc_cidr" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "application_subdomains" {
  type = list(string)
}

variable "control_plane_subdomain" {
  type = string
}

variable "s3_buckets" {
  type = map(object({
    versioning_status = optional(string, "Suspended")
    manage_versioning = optional(bool, false)
    lifecycle_enabled = optional(bool, false)
    cors_enabled      = optional(bool, false)
  }))
}

variable "s3_cors_configuration" {
  type = object({
    allowed_headers = list(string)
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = list(string)
    max_age_seconds = number
  })
}

variable "tags" {
  type = map(string)
}
