# =============================================================================
# VPC — community module, 3 AZs, 1 NAT per AZ
# =============================================================================

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${var.namespace}-vpc"
  cidr = var.vpc_cidr

  azs             = local.az_names
  public_subnets  = local.public_subnet_cidrs
  private_subnets = local.private_subnet_cidrs

  enable_dns_hostnames    = true
  enable_dns_support      = true
  map_public_ip_on_launch = true

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  enable_vpn_gateway = false

  public_subnet_tags  = { Tier = "public" }
  private_subnet_tags = { Tier = "private" }

  tags = local.common_tags
}

# =============================================================================
# Security Groups - one per role, rules built from port variables in locals.tf
# =============================================================================

module "sg_bastion" {
  source = "./modules/security-group"

  name        = "${var.namespace}-bastion-sg"
  description = "Bastion host - SSH jump box"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = local.bastion_ingress_rules
  egress_rules  = local.default_egress_rules
  tags          = local.common_tags
}

module "sg_k8s_nodes" {
  source = "./modules/security-group"

  name        = "${var.namespace}-k8s-nodes-sg"
  description = "Kubernetes controller and worker nodes"
  vpc_id      = module.vpc.vpc_id

  ingress_rules      = local.k8s_ingress_rules
  ingress_self_rules = local.k8s_self_rules
  egress_rules       = local.default_egress_rules
  tags               = local.common_tags
}

module "sg_db" {
  source = "./modules/security-group"

  name        = "${var.namespace}-db-sg"
  description = "Database instance - access from K8s nodes"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = local.db_ingress_rules
  egress_rules  = local.default_egress_rules
  tags          = local.common_tags
}

# =============================================================================
# Key Pair
# =============================================================================

resource "aws_key_pair" "deployer" {
  key_name   = "${var.namespace}-deployer"
  public_key = var.ssh_public_key
  tags       = local.common_tags
}

# =============================================================================
# IAM — role + instance profile with pluggable policies
# =============================================================================

module "iam" {
  source = "./modules/iam"

  namespace = var.namespace
  role_name = "k8s-node"
  policies  = local.iam_policies
  tags      = local.common_tags
}

# =============================================================================
# S3 — buckets with optional versioning, lifecycle, CORS
# =============================================================================

module "s3" {
  source = "./modules/s3"

  namespace          = var.namespace
  buckets            = var.s3_buckets
  cors_configuration = var.s3_cors_configuration
  tags               = local.common_tags
}

# =============================================================================
# Compute — all EC2 instances from a single map
# =============================================================================

module "compute" {
  source = "./modules/compute"

  instances = local.compute_instances
  tags      = local.common_tags
}

# =============================================================================
# NLB — TCP passthrough, SSL terminates at ingress controller
# =============================================================================

module "nlb" {
  source = "./modules/nlb"

  name       = "${local.short_name}-nlb"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets
  target_ids = local.controller_ids

  listeners = {
    http = {
      listen_port = 80
      target_port = 30080
    }
    https = {
      listen_port = 443
      target_port = 30443
    }
    k8s-api = {
      listen_port = var.k8s_api_port
      target_port = var.k8s_api_port
    }
  }

  tags = local.common_tags
}

# =============================================================================
# DNS — conditional on domain_name being set
# =============================================================================

module "dns" {
  count  = local.enable_dns ? 1 : 0
  source = "./modules/dns"

  zone_id       = data.aws_route53_zone.this[0].zone_id
  alias_records = local.dns_alias_records
  a_records     = local.dns_a_records
  cname_records = local.dns_cname_records
}
