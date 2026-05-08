variable "zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

variable "alias_records" {
  description = "Map of alias A-records (typically for load balancers)"
  type = map(object({
    name     = string
    dns_name = string
    zone_id  = string
  }))
  default = {}
}

variable "a_records" {
  description = "Map of A-records"
  type = map(object({
    name    = string
    records = list(string)
    ttl     = optional(number, 60)
  }))
  default = {}
}

variable "cname_records" {
  description = "Map of CNAME records"
  type = map(object({
    name    = string
    records = list(string)
    ttl     = optional(number, 300)
  }))
  default = {}
}
