resource "aws_route53_record" "alias" {
  for_each = var.alias_records

  zone_id = var.zone_id
  name    = each.value.name
  type    = "A"

  alias {
    name                   = each.value.dns_name
    zone_id                = each.value.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "a" {
  for_each = var.a_records

  zone_id = var.zone_id
  name    = each.value.name
  type    = "A"
  ttl     = each.value.ttl
  records = each.value.records
}

resource "aws_route53_record" "cname" {
  for_each = var.cname_records

  zone_id = var.zone_id
  name    = each.value.name
  type    = "CNAME"
  ttl     = each.value.ttl
  records = each.value.records

  lifecycle { create_before_destroy = true }
}
