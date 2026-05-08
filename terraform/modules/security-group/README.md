# Security Group Module

Generic AWS security group with configurable ingress and egress rules.

Supports CIDR-based rules, security-group-referenced rules, and
self-referencing rules (for intra-group traffic). All rule maps use `for_each`
for clean plan diffs.

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
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.self](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_description"></a> [description](#input\_description) | Security group description (ASCII only: a-zA-Z0-9. \_-:/()#,@[]+=&;{}!$*) | `string` | `"Managed by Terraform"` | no |
| <a name="input_egress_rules"></a> [egress\_rules](#input\_egress\_rules) | Map of egress rules (set cidr\_ipv4 OR referenced\_security\_group\_id per rule) | <pre>map(object({<br/>    from_port                    = optional(number)<br/>    to_port                      = optional(number)<br/>    ip_protocol                  = string<br/>    cidr_ipv4                    = optional(string)<br/>    referenced_security_group_id = optional(string)<br/>    description                  = optional(string, "")<br/>  }))</pre> | `{}` | no |
| <a name="input_ingress_rules"></a> [ingress\_rules](#input\_ingress\_rules) | Map of ingress rules (set cidr\_ipv4 OR referenced\_security\_group\_id per rule) | <pre>map(object({<br/>    from_port                    = optional(number)<br/>    to_port                      = optional(number)<br/>    ip_protocol                  = string<br/>    cidr_ipv4                    = optional(string)<br/>    referenced_security_group_id = optional(string)<br/>    description                  = optional(string, "")<br/>  }))</pre> | `{}` | no |
| <a name="input_ingress_self_rules"></a> [ingress\_self\_rules](#input\_ingress\_self\_rules) | Map of ingress rules that reference this security group itself | <pre>map(object({<br/>    from_port   = optional(number)<br/>    to_port     = optional(number)<br/>    ip_protocol = string<br/>    description = optional(string, "")<br/>  }))</pre> | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Security group name (used in Name tag and as name\_prefix) | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | n/a | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | Security group ARN |
| <a name="output_id"></a> [id](#output\_id) | Security group ID |
| <a name="output_name"></a> [name](#output\_name) | Security group name (AWS-generated from name\_prefix) |
<!-- END_TF_DOCS -->
