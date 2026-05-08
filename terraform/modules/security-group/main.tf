resource "aws_security_group" "this" {
  name_prefix = "${var.name}-"
  description = var.description
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = var.name })

  lifecycle { create_before_destroy = true }
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = var.ingress_rules

  security_group_id            = aws_security_group.this.id
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  ip_protocol                  = each.value.ip_protocol
  cidr_ipv4                    = each.value.cidr_ipv4
  referenced_security_group_id = each.value.referenced_security_group_id
  description                  = each.value.description

  tags = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "self" {
  for_each = var.ingress_self_rules

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = aws_security_group.this.id
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  ip_protocol                  = each.value.ip_protocol
  description                  = each.value.description

  tags = var.tags
}

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = var.egress_rules

  security_group_id            = aws_security_group.this.id
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  ip_protocol                  = each.value.ip_protocol
  cidr_ipv4                    = each.value.cidr_ipv4
  referenced_security_group_id = each.value.referenced_security_group_id
  description                  = each.value.description

  tags = var.tags
}
