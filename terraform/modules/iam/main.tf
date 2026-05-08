resource "aws_iam_role" "this" {
  name = "${var.namespace}-${var.role_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = var.trusted_services }
    }]
  })

  tags = var.tags
}

resource "aws_iam_policy" "this" {
  for_each = var.policies

  name        = "${var.namespace}-${each.key}"
  description = each.value.description
  policy      = each.value.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each   = var.policies
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this[each.key].arn
}

resource "aws_iam_instance_profile" "this" {
  count = var.create_instance_profile ? 1 : 0
  name  = "${var.namespace}-${var.role_name}"
  role  = aws_iam_role.this.name
  tags  = var.tags
}
