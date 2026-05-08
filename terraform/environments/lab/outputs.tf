# =============================================================================
# Ansible
# =============================================================================

output "ansible_inventory" {
  description = "Ansible dynamic inventory JSON"
  value       = module.infra.ansible_inventory
}

output "infrastructure" {
  description = "Infrastructure metadata for Ansible group_vars"
  value       = module.infra.infrastructure
}

# =============================================================================
# Quick access
# =============================================================================

output "bastion_ip" {
  description = "Bastion Elastic IP — SSH entry point"
  value       = module.infra.bastion_ip
}

output "nlb_dns_name" {
  description = "NLB DNS name — point your domain here"
  value       = module.infra.nlb_dns_name
}

output "s3_buckets" {
  description = "Map of logical name → S3 bucket name"
  value       = module.infra.s3_buckets
}
