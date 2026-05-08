output "instances" {
  description = "Map of instance key to core attributes"
  value = {
    for k, v in aws_instance.this : k => {
      id                = v.id
      private_ip        = v.private_ip
      public_ip         = v.public_ip
      availability_zone = v.availability_zone
      subnet_id         = v.subnet_id
    }
  }
}

output "eip_public_ips" {
  description = "Map of instance key to its Elastic IP (only instances with eip=true)"
  value       = { for k, v in aws_eip.this : k => v.public_ip }
}
