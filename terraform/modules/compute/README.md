# Compute Module

Generic EC2 instance provisioning from a map of fully-resolved configurations.

Handles instance creation, encrypted gp3 volumes, IMDSv2 enforcement, Elastic
IP allocation for flagged instances, and tag propagation to volumes.

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_eip.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_eip_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip_association) | resource |
| [aws_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_instances"></a> [instances](#input\_instances) | Map of instance key to fully-resolved configuration | <pre>map(object({<br/>    name                 = string<br/>    ami_id               = string<br/>    instance_type        = string<br/>    key_name             = string<br/>    subnet_id            = string<br/>    security_group_ids   = list(string)<br/>    iam_instance_profile = optional(string)<br/>    associate_public_ip  = optional(bool, false)<br/>    eip                  = optional(bool, false)<br/>    volume_size          = number<br/>    volume_type          = optional(string, "gp3")<br/>    metadata_hop_limit   = optional(number, 1)<br/>    tags                 = optional(map(string), {})<br/>  }))</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource created by this module | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_eip_public_ips"></a> [eip\_public\_ips](#output\_eip\_public\_ips) | Map of instance key to its Elastic IP (only instances with eip=true) |
| <a name="output_instances"></a> [instances](#output\_instances) | Map of instance key to core attributes |
<!-- END_TF_DOCS -->
