# =============================================================================
# Ansible dynamic inventory
#   terraform output -json ansible_inventory > inventory.json
#   ansible-playbook -i inventory.json site.yml
# =============================================================================

output "ansible_inventory" {
  description = "Ansible dynamic inventory JSON (groups, hostvars, ProxyJump through bastion)"
  value = {
    bastion = {
      hosts = keys(local.bastion_instances)
      vars  = { ansible_ssh_common_args = "" }
    }
    controllers = {
      hosts = keys(local.controller_instances)
    }
    workers = {
      hosts = keys(local.worker_instances)
    }
    databases = {
      hosts = keys(local.db_instances)
    }
    k8s = {
      children = ["controllers", "workers"]
    }
    all = {
      vars = {
        ansible_user            = "ubuntu"
        bastion_host            = local.primary_bastion_ip
        ansible_ssh_common_args = "-o StrictHostKeyChecking=no"
      }
    }
    _meta = {
      hostvars = {
        for name, inst in var.instances : name => merge(
          {
            ansible_host      = inst.role == "bastion" ? module.compute.eip_public_ips[name] : module.compute.instances[name].private_ip
            private_ip        = module.compute.instances[name].private_ip
            role              = inst.role
            instance_id       = module.compute.instances[name].id
            availability_zone = module.compute.instances[name].availability_zone
          },
          inst.role == "bastion" ? { ansible_ssh_common_args = "" } : {}
        )
      }
    }
  }
}

# =============================================================================
# Infrastructure metadata — feed into Ansible group_vars
#   terraform output -json infrastructure > group_vars/all.json
# =============================================================================

output "infrastructure" {
  description = "Infrastructure details for Ansible playbooks and downstream tooling"
  value = {
    namespace       = var.namespace
    vpc_id          = module.vpc.vpc_id
    public_subnets  = module.vpc.public_subnets
    private_subnets = module.vpc.private_subnets
    nat_gateway_ips = module.vpc.nat_public_ips

    nlb = {
      dns_name = module.nlb.dns_name
      zone_id  = module.nlb.zone_id
      arn      = module.nlb.arn
    }

    domain_name = var.domain_name

    s3_buckets = {
      for k, name in module.s3.buckets : k => {
        name   = name
        arn    = module.s3.bucket_arns[k]
        region = module.s3.bucket_regions[k]
      }
    }

    iam = {
      role_arn              = module.iam.role_arn
      instance_profile_name = module.iam.instance_profile_name
    }

    security_groups = {
      bastion   = module.sg_bastion.id
      k8s_nodes = module.sg_k8s_nodes.id
      db        = module.sg_db.id
    }

    key_pair_name = aws_key_pair.deployer.key_name
    ami_id        = data.aws_ami.ubuntu.id
    bastion_ip    = local.primary_bastion_ip
  }
}

# =============================================================================
# Quick-access outputs
# =============================================================================

output "bastion_ip" {
  description = "Bastion Elastic IP"
  value       = local.primary_bastion_ip
}

output "nlb_dns_name" {
  description = "NLB DNS name — point your domain here"
  value       = module.nlb.dns_name
}

output "s3_buckets" {
  description = "Map of logical name → S3 bucket name"
  value       = module.s3.buckets
}
