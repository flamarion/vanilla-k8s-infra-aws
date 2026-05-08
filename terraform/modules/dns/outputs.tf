output "alias_fqdns" {
  description = "Map of alias record key to its FQDN"
  value       = { for k, v in aws_route53_record.alias : k => v.fqdn }
}

output "a_fqdns" {
  description = "Map of A record key to its FQDN"
  value       = { for k, v in aws_route53_record.a : k => v.fqdn }
}

output "cname_fqdns" {
  description = "Map of CNAME record key to its FQDN"
  value       = { for k, v in aws_route53_record.cname : k => v.fqdn }
}
