locals {
  enable_dns = var.domain_name != ""

  common_tags = merge(var.tags, {
    Namespace = var.namespace
    ManagedBy = "terraform"
  })

  short_name = substr(var.namespace, 0, 20)

  # ---------------------------------------------------------------------------
  # Availability zones - 3 AZs for HA
  # ---------------------------------------------------------------------------

  az_count             = 3
  az_names             = slice(data.aws_availability_zones.available.names, 0, local.az_count)
  public_subnet_cidrs  = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 8, 100 + i)]
  private_subnet_cidrs = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]

  # ---------------------------------------------------------------------------
  # Instance grouping by role
  # ---------------------------------------------------------------------------

  bastion_instances    = { for k, v in var.instances : k => v if v.role == "bastion" }
  controller_instances = { for k, v in var.instances : k => v if v.role == "controller" }
  worker_instances     = { for k, v in var.instances : k => v if v.role == "worker" }
  db_instances         = { for k, v in var.instances : k => v if v.role == "db" }

  # ---------------------------------------------------------------------------
  # Round-robin subnet assignment across AZs
  # ---------------------------------------------------------------------------

  public_keys  = sort(keys({ for k, v in var.instances : k => v if v.subnet_type == "public" }))
  private_keys = sort(keys({ for k, v in var.instances : k => v if v.subnet_type == "private" }))

  subnet_map = merge(
    { for i, k in local.public_keys : k => module.vpc.public_subnets[i % length(module.vpc.public_subnets)] },
    { for i, k in local.private_keys : k => module.vpc.private_subnets[i % length(module.vpc.private_subnets)] },
  )

  # ---------------------------------------------------------------------------
  # Security group resolution by role
  # ---------------------------------------------------------------------------

  role_sg_map = {
    bastion    = module.sg_bastion.id
    controller = module.sg_k8s_nodes.id
    worker     = module.sg_k8s_nodes.id
    db         = module.sg_db.id
  }

  # ---------------------------------------------------------------------------
  # Security group rules (all ports are configurable via variables)
  # ---------------------------------------------------------------------------

  default_egress_rules = {
    all-outbound = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
      description = "All outbound"
    }
  }

  bastion_ingress_rules = {
    for i, cidr in var.allowed_ssh_cidrs : "ssh-${i}" => {
      from_port   = var.ssh_port
      to_port     = var.ssh_port
      ip_protocol = "tcp"
      cidr_ipv4   = cidr
      description = "SSH from ${cidr}"
    }
  }

  k8s_ingress_rules = {
    ssh-from-bastion = {
      from_port                    = var.ssh_port
      to_port                      = var.ssh_port
      ip_protocol                  = "tcp"
      referenced_security_group_id = module.sg_bastion.id
      description                  = "SSH from bastion"
    }
    k8s-api-from-bastion = {
      from_port                    = var.k8s_api_port
      to_port                      = var.k8s_api_port
      ip_protocol                  = "tcp"
      referenced_security_group_id = module.sg_bastion.id
      description                  = "Kubernetes API from bastion (kubectl)"
    }
    ingress-http = {
      from_port   = 30080
      to_port     = 30080
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Cilium ingress HTTP NodePort - NLB passthrough"
    }
    ingress-https = {
      from_port   = 30443
      to_port     = 30443
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Cilium ingress HTTPS NodePort - NLB passthrough"
    }
    k8s-api-from-nlb = {
      from_port   = var.k8s_api_port
      to_port     = var.k8s_api_port
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "K8s API - NLB TCP passthrough"
    }
  }

  k8s_self_rules = {
    all-intra-cluster = {
      ip_protocol = "-1"
      description = "All intra-cluster traffic (etcd, kubelet, CNI, CoreDNS)"
    }
  }

  db_ingress_rules = {
    ssh-from-bastion = {
      from_port                    = var.ssh_port
      to_port                      = var.ssh_port
      ip_protocol                  = "tcp"
      referenced_security_group_id = module.sg_bastion.id
      description                  = "SSH from bastion"
    }
    mysql-from-k8s = {
      from_port                    = var.mysql_port
      to_port                      = var.mysql_port
      ip_protocol                  = "tcp"
      referenced_security_group_id = module.sg_k8s_nodes.id
      description                  = "MySQL from K8s nodes"
    }
  }

  # ---------------------------------------------------------------------------
  # Build fully-resolved instance map for the compute module
  # ---------------------------------------------------------------------------

  compute_instances = {
    for name, inst in var.instances : name => {
      name                 = "${var.namespace}-${name}"
      ami_id               = data.aws_ami.ubuntu.id
      instance_type        = inst.instance_type
      key_name             = aws_key_pair.deployer.key_name
      subnet_id            = local.subnet_map[name]
      security_group_ids   = [local.role_sg_map[inst.role]]
      iam_instance_profile = contains(["controller", "worker"], inst.role) ? module.iam.instance_profile_name : null
      associate_public_ip  = inst.subnet_type == "public"
      eip                  = inst.role == "bastion"
      volume_size          = inst.volume_size
      volume_type          = "gp3"
      metadata_hop_limit   = contains(["controller", "worker"], inst.role) ? 3 : 1
      tags                 = { Role = inst.role }
    }
  }

  # ---------------------------------------------------------------------------
  # NLB targets - controller instance IDs
  # ---------------------------------------------------------------------------

  controller_ids = [for k in sort(keys(local.controller_instances)) : module.compute.instances[k].id]

  # ---------------------------------------------------------------------------
  # Bastion
  # ---------------------------------------------------------------------------

  primary_bastion_key = sort(keys(local.bastion_instances))[0]
  primary_bastion_ip  = module.compute.eip_public_ips[local.primary_bastion_key]

  # ---------------------------------------------------------------------------
  # IAM policies (composed from module outputs)
  # ---------------------------------------------------------------------------

  iam_policies = merge(
    {
      ebs-csi = {
        description = "EBS CSI driver - dynamic PV provisioning"
        json = jsonencode({
          Version = "2012-10-17"
          Statement = [{
            Effect = "Allow"
            Action = [
              "ec2:AttachVolume",
              "ec2:CreateSnapshot",
              "ec2:CreateTags",
              "ec2:CreateVolume",
              "ec2:DeleteSnapshot",
              "ec2:DeleteTags",
              "ec2:DeleteVolume",
              "ec2:DescribeAvailabilityZones",
              "ec2:DescribeInstances",
              "ec2:DescribeSnapshots",
              "ec2:DescribeTags",
              "ec2:DescribeVolumes",
              "ec2:DescribeVolumesModifications",
              "ec2:DetachVolume",
              "ec2:ModifyVolume",
              "ec2:DescribeInstanceAttribute",
              "ec2:DescribeInstanceTypes",
              "ec2:DescribeRegions",
            ]
            Resource = "*"
          }]
        })
      }
    },

    length(var.s3_buckets) > 0 ? {
      s3-access = {
        description = "Full S3 access scoped to cluster buckets"
        json = jsonencode({
          Version = "2012-10-17"
          Statement = [{
            Effect   = "Allow"
            Action   = ["s3:*"]
            Resource = flatten([for arn in values(module.s3.bucket_arns) : [arn, "${arn}/*"]])
          }]
        })
      }
    } : {},

    local.enable_dns ? {
      certmanager-dns01 = {
        description = "cert-manager DNS-01 ACME challenge via Route53"
        json = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect   = "Allow"
              Action   = "route53:GetChange"
              Resource = "arn:aws:route53:::change/*"
            },
            {
              Effect = "Allow"
              Action = [
                "route53:ChangeResourceRecordSets",
                "route53:ListResourceRecordSets",
              ]
              Resource = "arn:aws:route53:::hostedzone/*"
              Condition = {
                "ForAllValues:StringEquals" = {
                  "route53:ChangeResourceRecordSetsRecordTypes" = ["TXT"]
                }
              }
            },
            {
              Effect   = "Allow"
              Action   = "route53:ListHostedZonesByName"
              Resource = "*"
            },
          ]
        })
      }
    } : {},
  )

  # ---------------------------------------------------------------------------
  # DNS records (conditional)
  # ---------------------------------------------------------------------------

  dns_a_records = local.enable_dns ? merge(
    {
      for k, _ in local.bastion_instances : k => {
        name    = k
        records = [module.compute.eip_public_ips[k]]
      }
    },
    {
      for k, v in var.instances : k => {
        name    = k
        records = [module.compute.instances[k].private_ip]
      } if v.role != "bastion"
    },
  ) : {}

  dns_cname_records = local.enable_dns ? merge(
    {
      for sub in var.application_subdomains : sub => {
        name    = sub
        records = [module.nlb.dns_name]
      }
    },
    {
      (var.control_plane_subdomain) = {
        name    = var.control_plane_subdomain
        records = [module.nlb.dns_name]
      }
    },
  ) : {}

  dns_alias_records = local.enable_dns ? {
    apex = {
      name     = var.domain_name
      dns_name = module.nlb.dns_name
      zone_id  = module.nlb.zone_id
    }
  } : {}
}
