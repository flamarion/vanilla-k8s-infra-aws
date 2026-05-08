# DNS Module

Generic Route53 record management supporting A records, CNAME records, and
alias records (for load balancers and CloudFront distributions).

All record types accept maps, making it easy to manage multiple records from a
single module call.

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
| [aws_route53_record.a](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.cname](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_a_records"></a> [a\_records](#input\_a\_records) | Map of A-records | <pre>map(object({<br/>    name    = string<br/>    records = list(string)<br/>    ttl     = optional(number, 60)<br/>  }))</pre> | `{}` | no |
| <a name="input_alias_records"></a> [alias\_records](#input\_alias\_records) | Map of alias A-records (typically for load balancers) | <pre>map(object({<br/>    name     = string<br/>    dns_name = string<br/>    zone_id  = string<br/>  }))</pre> | `{}` | no |
| <a name="input_cname_records"></a> [cname\_records](#input\_cname\_records) | Map of CNAME records | <pre>map(object({<br/>    name    = string<br/>    records = list(string)<br/>    ttl     = optional(number, 300)<br/>  }))</pre> | `{}` | no |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Route53 hosted zone ID | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_a_fqdns"></a> [a\_fqdns](#output\_a\_fqdns) | Map of A record key to its FQDN |
| <a name="output_alias_fqdns"></a> [alias\_fqdns](#output\_alias\_fqdns) | Map of alias record key to its FQDN |
| <a name="output_cname_fqdns"></a> [cname\_fqdns](#output\_cname\_fqdns) | Map of CNAME record key to its FQDN |
<!-- END_TF_DOCS -->
