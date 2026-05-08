variable "name" {
  description = "Name of the NLB (also used as prefix for target groups)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for target groups"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs where the NLB is placed"
  type        = list(string)
}

variable "internal" {
  description = "Whether the NLB is internal"
  type        = bool
  default     = false
}

variable "listeners" {
  description = "Map of listener key to its configuration"
  type = map(object({
    listen_port       = number
    target_port       = number
    protocol          = optional(string, "TCP")
    health_check_port = optional(number)
  }))
}

variable "target_ids" {
  description = "Instance IDs registered in every target group"
  type        = list(string)
}

variable "enable_cross_zone_load_balancing" {
  type    = bool
  default = true
}

variable "enable_deletion_protection" {
  type    = bool
  default = false
}

variable "tags" {
  description = "Tags applied to every resource"
  type        = map(string)
  default     = {}
}
