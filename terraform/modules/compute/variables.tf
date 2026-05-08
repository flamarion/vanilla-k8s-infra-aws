variable "instances" {
  description = "Map of instance key to fully-resolved configuration"
  type = map(object({
    name                 = string
    ami_id               = string
    instance_type        = string
    key_name             = string
    subnet_id            = string
    security_group_ids   = list(string)
    iam_instance_profile = optional(string)
    associate_public_ip  = optional(bool, false)
    eip                  = optional(bool, false)
    volume_size          = number
    volume_type          = optional(string, "gp3")
    metadata_hop_limit   = optional(number, 1)
    tags                 = optional(map(string), {})
  }))
}

variable "tags" {
  description = "Tags applied to every resource created by this module"
  type        = map(string)
  default     = {}
}
