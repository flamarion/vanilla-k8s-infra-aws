# Vanilla Kubernetes on AWS — Terraform Module

Composable Terraform module that provisions infrastructure for self-managed
Kubernetes clusters on AWS EC2.

## Architecture

```
                  ┌─────────────────────────────────────────────────┐
                  │                       VPC                       │
                  │                                                 │
  ┌──────────┐    │  ┌─ Public subnets ──────────────────────────┐  │
  │ Internet │────┼─▶│  ┌─────┐                    ┌─────────┐   │  │
  └──────────┘    │  │  │ NLB │ TCP 80/443/6443    │ Bastion │   │  │
                  │  │  └──┬──┘                    └────┬────┘   │  │
                  │  └─────┼────────────────────────────┼────────┘  │
                  │        │                            │ SSH       │
                  │        ▼                            ▼           │
                  │  ┌─ Private subnets ─────────────────────────┐  │
                  │  │                                           │  │
                  │  │  ┌────────┐   ┌────────┐   ┌────────┐     │  │
                  │  │  │ ctrl-1 │   │ ctrl-2 │   │ ctrl-3 │     │  │
                  │  │  │  AZ-a  │   │  AZ-b  │   │  AZ-c  │     │  │
                  │  │  └───┬────┘   └───┬────┘   └───┬────┘     │  │
                  │  │      └─────┬──────┴──────┬─────┘          │  │
                  │  │            ▼             ▼                │  │
                  │  │  ┌──────────┐ ┌──────────┐ ┌──────────┐   │  │
                  │  │  │ worker-1 │ │ worker-2 │ │ worker-3 │   │  │
                  │  │  │   AZ-a   │ │   AZ-b   │ │   AZ-c   │   │  │
                  │  │  └────┬─────┘ └────┬─────┘ └────┬─────┘   │  │
                  │  │       └──────┬─────┴──────┬─────┘         │  │
                  │  │              ▼            ▼               │  │
                  │  │       ┌──────────┐  ┌───────────┐         │  │
                  │  │       │    DB    │  │ S3 Bucket │         │  │
                  │  │       │ (MySQL)  │  │  (data)   │         │  │
                  │  │       └──────────┘  └───────────┘         │  │
                  │  │                                           │  │
                  │  └───────────────────────────────────────────┘  │
                  └─────────────────────────────────────────────────┘
```

## Directory structure

```
terraform/
├── versions.tf            Required providers (no provider block)
├── variables.tf           Module interface — 3 required, rest have defaults
├── outputs.tf             Ansible inventory + infrastructure metadata
├── data.tf                AMI lookup, AZs, Route53 zone
├── locals.tf              Composition logic — wires modules together
├── main.tf                Module calls (VPC, SGs, IAM, compute, NLB, S3, DNS)
│
├── modules/               Generic, project-agnostic building blocks
│   ├── compute/           EC2 instances from a map, EIPs, encrypted volumes
│   ├── nlb/               NLB with configurable listeners + targets
│   ├── s3/                S3 buckets with versioning, lifecycle, CORS
│   ├── iam/               IAM role + pluggable policies + instance profile
│   ├── dns/               Route53 A, CNAME, and alias records
│   └── security-group/    Security group + configurable ingress/egress rules
│
└── environments/          Deployment workspaces that call this module
    ├── README.md          How to create a new environment
    └── lab/               Lab environment (eu-central-1)
```

## Usage

This directory is a **Terraform module**. You don't run `terraform apply` here.
Instead, create an environment under `environments/` that calls this module.

### Quick start

```bash
cd environments/lab
terraform init
terraform plan
terraform apply
```

### Calling the module from a new environment

```hcl
# environments/staging/main.tf
module "infra" {
  source = "../../"

  namespace      = "k8s-staging"
  ssh_public_key = file("~/.ssh/id_ed25519.pub")

  instances = {
    bastion      = { role = "bastion",    instance_type = "t3.micro",  volume_size = 20,  subnet_type = "public"  }
    controller-1 = { role = "controller", instance_type = "m5.large",  volume_size = 100, subnet_type = "private" }
    controller-2 = { role = "controller", instance_type = "m5.large",  volume_size = 100, subnet_type = "private" }
    controller-3 = { role = "controller", instance_type = "m5.large",  volume_size = 100, subnet_type = "private" }
    worker-1     = { role = "worker",     instance_type = "m5.xlarge", volume_size = 100, subnet_type = "private" }
    worker-2     = { role = "worker",     instance_type = "m5.xlarge", volume_size = 100, subnet_type = "private" }
    db           = { role = "db",         instance_type = "m5.large",  volume_size = 100, subnet_type = "private" }
  }

  domain_name            = "staging.example.com"
  application_subdomains = ["app", "grafana"]
}
```

See `environments/README.md` for the full guide.

## NLB listeners

The NLB is configured with three TCP passthrough listeners:

| Port | Target Port | Purpose |
|------|-------------|---------|
| 80   | 30080 | HTTP ingress -- Cilium Envoy NodePort (redirects to HTTPS) |
| 443  | 30443 | HTTPS ingress -- Cilium Envoy terminates SSL |
| 6443 | 6443 | Kubernetes API -- round-robin across controllers |

The `control_plane_subdomain` variable (default: `k8scontroller`) creates a
dedicated CNAME pointing to the NLB, used as the kubeadm HA control plane
endpoint. This is separate from `application_subdomains` to avoid confusion
with application DNS records.

## Provider versions

The module's `versions.tf` owns all provider version constraints (AWS >= 6.0).
Environments configure provider settings (region, profile, default tags) but
**do not** set `required_providers` -- this prevents version conflicts.

## Instance roles

| Role         | SG           | IAM Profile | NLB Target | Subnet  |
| ------------ | ------------ | ----------- | ---------- | ------- |
| `bastion`    | bastion-sg   | none        | no         | public  |
| `controller` | k8s-nodes-sg | k8s-node    | yes        | private |
| `worker`     | k8s-nodes-sg | k8s-node    | no         | private |
| `db`         | db-sg        | none        | no         | private |

## Reusing individual modules

Every module under `modules/` is generic and works independently:

```hcl
# Stand-alone NLB for any TCP service
module "api_lb" {
  source     = "path/to/modules/nlb"
  name       = "my-api-nlb"
  vpc_id     = "vpc-123"
  subnet_ids = ["subnet-a", "subnet-b"]
  target_ids = ["i-111", "i-222"]
  listeners  = {
    grpc = { listen_port = 443, target_port = 8443 }
  }
}
```

## Module reference

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_compute"></a> [compute](#module\_compute) | ./modules/compute | n/a |
| <a name="module_dns"></a> [dns](#module\_dns) | ./modules/dns | n/a |
| <a name="module_iam"></a> [iam](#module\_iam) | ./modules/iam | n/a |
| <a name="module_nlb"></a> [nlb](#module\_nlb) | ./modules/nlb | n/a |
| <a name="module_s3"></a> [s3](#module\_s3) | ./modules/s3 | n/a |
| <a name="module_sg_bastion"></a> [sg\_bastion](#module\_sg\_bastion) | ./modules/security-group | n/a |
| <a name="module_sg_db"></a> [sg\_db](#module\_sg\_db) | ./modules/security-group | n/a |
| <a name="module_sg_k8s_nodes"></a> [sg\_k8s\_nodes](#module\_sg\_k8s\_nodes) | ./modules/security-group | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | ~> 6.0 |

## Resources

| Name | Type |
|------|------|
| [aws_key_pair.deployer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair) | resource |
| [aws_ami.ubuntu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_route53_zone.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_ssh_cidrs"></a> [allowed\_ssh\_cidrs](#input\_allowed\_ssh\_cidrs) | CIDR blocks allowed to SSH into the bastion | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_application_subdomains"></a> [application\_subdomains](#input\_application\_subdomains) | Subdomains to create CNAME records pointing to the NLB | `list(string)` | `[]` | no |
| <a name="input_control_plane_subdomain"></a> [control\_plane\_subdomain](#input\_control\_plane\_subdomain) | DNS subdomain for the K8s API control plane endpoint (CNAME to NLB) | `string` | `"k8scontroller"` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Route53 hosted zone domain (empty = skip DNS and cert-manager policy) | `string` | `""` | no |
| <a name="input_instances"></a> [instances](#input\_instances) | Map of instance name to {role, instance\_type, volume\_size, subnet\_type} | <pre>map(object({<br/>    role          = string # controller | worker | db | bastion<br/>    instance_type = string<br/>    volume_size   = number<br/>    subnet_type   = string # public | private<br/>  }))</pre> | n/a | yes |
| <a name="input_k8s_api_port"></a> [k8s\_api\_port](#input\_k8s\_api\_port) | Kubernetes API server port | `number` | `6443` | no |
| <a name="input_mysql_port"></a> [mysql\_port](#input\_mysql\_port) | MySQL port on the database instance | `number` | `3306` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace prefix applied to every resource name | `string` | n/a | yes |
| <a name="input_s3_buckets"></a> [s3\_buckets](#input\_s3\_buckets) | Map of S3 bucket short names to per-bucket configuration | <pre>map(object({<br/>    versioning_status = optional(string, "Suspended")<br/>    manage_versioning = optional(bool, false)<br/>    lifecycle_enabled = optional(bool, false)<br/>    cors_enabled      = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| <a name="input_s3_cors_configuration"></a> [s3\_cors\_configuration](#input\_s3\_cors\_configuration) | Default CORS rules applied to buckets with cors\_enabled=true | <pre>object({<br/>    allowed_headers = list(string)<br/>    allowed_methods = list(string)<br/>    allowed_origins = list(string)<br/>    expose_headers  = list(string)<br/>    max_age_seconds = number<br/>  })</pre> | <pre>{<br/>  "allowed_headers": [<br/>    "*"<br/>  ],<br/>  "allowed_methods": [<br/>    "GET",<br/>    "PUT",<br/>    "POST",<br/>    "DELETE",<br/>    "HEAD"<br/>  ],<br/>  "allowed_origins": [<br/>    "*"<br/>  ],<br/>  "expose_headers": [<br/>    "ETag"<br/>  ],<br/>  "max_age_seconds": 3600<br/>}</pre> | no |
| <a name="input_ssh_port"></a> [ssh\_port](#input\_ssh\_port) | SSH port for bastion and instance access | `number` | `22` | no |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | SSH public key material for the EC2 key pair | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags merged into every resource | `map(string)` | `{}` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for the VPC | `string` | `"10.0.0.0/16"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ansible_inventory"></a> [ansible\_inventory](#output\_ansible\_inventory) | Ansible dynamic inventory JSON (groups, hostvars, ProxyJump through bastion) |
| <a name="output_bastion_ip"></a> [bastion\_ip](#output\_bastion\_ip) | Bastion Elastic IP |
| <a name="output_infrastructure"></a> [infrastructure](#output\_infrastructure) | Infrastructure details for Ansible playbooks and downstream tooling |
| <a name="output_nlb_dns_name"></a> [nlb\_dns\_name](#output\_nlb\_dns\_name) | NLB DNS name — point your domain here |
| <a name="output_s3_buckets"></a> [s3\_buckets](#output\_s3\_buckets) | Map of logical name → S3 bucket name |
<!-- END_TF_DOCS -->
