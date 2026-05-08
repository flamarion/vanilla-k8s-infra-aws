variable "namespace" {
  description = "Prefix for IAM resource names"
  type        = string
}

variable "role_name" {
  description = "Suffix appended to namespace for the role name"
  type        = string
}

variable "trusted_services" {
  description = "AWS service principals allowed to assume this role"
  type        = list(string)
  default     = ["ec2.amazonaws.com"]
}

variable "policies" {
  description = "Map of policy short name to its definition"
  type = map(object({
    description = optional(string, "")
    json        = string
  }))
  default = {}
}

variable "create_instance_profile" {
  description = "Whether to create an EC2 instance profile for this role"
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
