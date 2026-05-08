resource "aws_instance" "this" {
  for_each = var.instances

  ami                         = each.value.ami_id
  instance_type               = each.value.instance_type
  key_name                    = each.value.key_name
  vpc_security_group_ids      = each.value.security_group_ids
  subnet_id                   = each.value.subnet_id
  iam_instance_profile        = each.value.iam_instance_profile
  associate_public_ip_address = each.value.associate_public_ip

  root_block_device {
    volume_size = each.value.volume_size
    volume_type = each.value.volume_type
    encrypted   = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = each.value.metadata_hop_limit
    http_tokens                 = "required"
  }

  tags = merge(var.tags, each.value.tags, {
    Name = each.value.name
  })

  volume_tags = merge(var.tags, {
    Name = "${each.value.name}-root"
  })
}

resource "aws_eip" "this" {
  for_each = { for k, v in var.instances : k => v if v.eip }
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "${each.value.name}-eip"
  })
}

resource "aws_eip_association" "this" {
  for_each      = { for k, v in var.instances : k => v if v.eip }
  instance_id   = aws_instance.this[each.key].id
  allocation_id = aws_eip.this[each.key].id
}
