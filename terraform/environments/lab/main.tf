module "infra" {
  source = "../../"

  namespace              = var.namespace
  instances              = var.instances
  ssh_public_key         = var.ssh_public_key
  allowed_ssh_cidrs      = var.allowed_ssh_cidrs
  vpc_cidr               = var.vpc_cidr
  domain_name            = var.domain_name
  application_subdomains  = var.application_subdomains
  control_plane_subdomain = var.control_plane_subdomain
  s3_buckets             = var.s3_buckets
  s3_cors_configuration  = var.s3_cors_configuration
  tags                   = var.tags
}
