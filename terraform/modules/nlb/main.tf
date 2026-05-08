resource "aws_lb" "this" {
  name               = var.name
  internal           = var.internal
  load_balancer_type = "network"
  subnets            = var.subnet_ids

  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing
  enable_deletion_protection       = var.enable_deletion_protection

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_lb_target_group" "this" {
  for_each = var.listeners

  name     = "${substr(var.name, 0, 26)}-${each.key}"
  port     = each.value.target_port
  protocol = each.value.protocol
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
    port                = coalesce(each.value.health_check_port, each.value.target_port)
    protocol            = each.value.protocol
  }

  tags = merge(var.tags, { Name = "${var.name}-${each.key}-tg" })
}

locals {
  # Cartesian product: one attachment per (listener × target)
  attachments = merge([
    for lk, lv in var.listeners : {
      for idx, tid in var.target_ids : "${lk}-${idx}" => {
        target_group_arn = aws_lb_target_group.this[lk].arn
        target_id        = tid
        port             = lv.target_port
      }
    }
  ]...)
}

resource "aws_lb_target_group_attachment" "this" {
  for_each         = local.attachments
  target_group_arn = each.value.target_group_arn
  target_id        = each.value.target_id
  port             = each.value.port
}

resource "aws_lb_listener" "this" {
  for_each = var.listeners

  load_balancer_arn = aws_lb.this.arn
  port              = each.value.listen_port
  protocol          = each.value.protocol

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.key].arn
  }

  tags = var.tags
}
