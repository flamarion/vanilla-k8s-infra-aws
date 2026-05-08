# =============================================================================
# Required — no defaults, caller must provide
# =============================================================================

variable "namespace" {
  description = "Namespace prefix applied to every resource name"
  type        = string
}

variable "instances" {
  description = "Map of instance name to {role, instance_type, volume_size, subnet_type}"
  type = map(object({
    role          = string # controller | worker | db | bastion
    instance_type = string
    volume_size   = number
    subnet_type   = string # public | private
  }))
}

variable "ssh_public_key" {
  description = "SSH public key material for the EC2 key pair"
  type        = string
}

# =============================================================================
# Optional — sensible defaults for quick adoption
# =============================================================================

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH into the bastion"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "ssh_port" {
  description = "SSH port for bastion and instance access"
  type        = number
  default     = 22
}

variable "mysql_port" {
  description = "MySQL port on the database instance"
  type        = number
  default     = 3306
}

variable "k8s_api_port" {
  description = "Kubernetes API server port"
  type        = number
  default     = 6443
}

variable "control_plane_subdomain" {
  description = "DNS subdomain for the K8s API control plane endpoint (CNAME to NLB)"
  type        = string
  default     = "k8scontroller"
}

variable "domain_name" {
  description = "Route53 hosted zone domain (empty = skip DNS and cert-manager policy)"
  type        = string
  default     = ""
}

variable "application_subdomains" {
  description = "Subdomains to create CNAME records pointing to the NLB"
  type        = list(string)
  default     = []
}

variable "s3_buckets" {
  description = "Map of S3 bucket short names to per-bucket configuration"
  type = map(object({
    versioning_status = optional(string, "Suspended")
    manage_versioning = optional(bool, false)
    lifecycle_enabled = optional(bool, false)
    cors_enabled      = optional(bool, false)
  }))
  default = {}
}

variable "s3_cors_configuration" {
  description = "Default CORS rules applied to buckets with cors_enabled=true"
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
  description = "Additional tags merged into every resource"
  type        = map(string)
  default     = {}
}
