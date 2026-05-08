variable "name" {
  description = "Security group name (used in Name tag and as name_prefix)"
  type        = string
}

variable "description" {
  description = "Security group description (ASCII only: a-zA-Z0-9. _-:/()#,@[]+=&;{}!$*)"
  type        = string
  default     = "Managed by Terraform"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "ingress_rules" {
  description = "Map of ingress rules (set cidr_ipv4 OR referenced_security_group_id per rule)"
  type = map(object({
    from_port                    = optional(number)
    to_port                      = optional(number)
    ip_protocol                  = string
    cidr_ipv4                    = optional(string)
    referenced_security_group_id = optional(string)
    description                  = optional(string, "")
  }))
  default = {}
}

variable "ingress_self_rules" {
  description = "Map of ingress rules that reference this security group itself"
  type = map(object({
    from_port   = optional(number)
    to_port     = optional(number)
    ip_protocol = string
    description = optional(string, "")
  }))
  default = {}
}

variable "egress_rules" {
  description = "Map of egress rules (set cidr_ipv4 OR referenced_security_group_id per rule)"
  type = map(object({
    from_port                    = optional(number)
    to_port                      = optional(number)
    ip_protocol                  = string
    cidr_ipv4                    = optional(string)
    referenced_security_group_id = optional(string)
    description                  = optional(string, "")
  }))
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
