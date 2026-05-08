# IAM Module

Generic IAM role with pluggable policy documents and optional EC2 instance
profile.

Accepts a map of policy definitions (name + JSON), creates managed policies,
and attaches them to the role. Supports configurable trusted service principals.

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
| [aws_iam_instance_profile.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_instance_profile"></a> [create\_instance\_profile](#input\_create\_instance\_profile) | Whether to create an EC2 instance profile for this role | `bool` | `true` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Prefix for IAM resource names | `string` | n/a | yes |
| <a name="input_policies"></a> [policies](#input\_policies) | Map of policy short name to its definition | <pre>map(object({<br/>    description = optional(string, "")<br/>    json        = string<br/>  }))</pre> | `{}` | no |
| <a name="input_role_name"></a> [role\_name](#input\_role\_name) | Suffix appended to namespace for the role name | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | n/a | `map(string)` | `{}` | no |
| <a name="input_trusted_services"></a> [trusted\_services](#input\_trusted\_services) | AWS service principals allowed to assume this role | `list(string)` | <pre>[<br/>  "ec2.amazonaws.com"<br/>]</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_instance_profile_arn"></a> [instance\_profile\_arn](#output\_instance\_profile\_arn) | Instance profile ARN (empty string if not created) |
| <a name="output_instance_profile_name"></a> [instance\_profile\_name](#output\_instance\_profile\_name) | Instance profile name (empty string if not created) |
| <a name="output_policy_arns"></a> [policy\_arns](#output\_policy\_arns) | Map of policy short name to its ARN |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | IAM role ARN |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | IAM role name |
<!-- END_TF_DOCS -->
