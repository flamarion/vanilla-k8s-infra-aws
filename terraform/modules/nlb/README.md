# NLB Module

Generic Network Load Balancer with configurable TCP/UDP listeners and shared
target group attachments.

Each listener key creates its own target group. All `target_ids` are registered
in every target group. Supports cross-zone load balancing and custom health
check ports.

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
| [aws_lb.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_enable_cross_zone_load_balancing"></a> [enable\_cross\_zone\_load\_balancing](#input\_enable\_cross\_zone\_load\_balancing) | n/a | `bool` | `true` | no |
| <a name="input_enable_deletion_protection"></a> [enable\_deletion\_protection](#input\_enable\_deletion\_protection) | n/a | `bool` | `false` | no |
| <a name="input_internal"></a> [internal](#input\_internal) | Whether the NLB is internal | `bool` | `false` | no |
| <a name="input_listeners"></a> [listeners](#input\_listeners) | Map of listener key to its configuration | <pre>map(object({<br/>    listen_port       = number<br/>    target_port       = number<br/>    protocol          = optional(string, "TCP")<br/>    health_check_port = optional(number)<br/>  }))</pre> | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the NLB (also used as prefix for target groups) | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnet IDs where the NLB is placed | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource | `map(string)` | `{}` | no |
| <a name="input_target_ids"></a> [target\_ids](#input\_target\_ids) | Instance IDs registered in every target group | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID for target groups | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | NLB ARN |
| <a name="output_dns_name"></a> [dns\_name](#output\_dns\_name) | NLB DNS name |
| <a name="output_target_group_arns"></a> [target\_group\_arns](#output\_target\_group\_arns) | Map of listener key to its target group ARN |
| <a name="output_zone_id"></a> [zone\_id](#output\_zone\_id) | NLB Route53 zone ID (for alias records) |
<!-- END_TF_DOCS -->
