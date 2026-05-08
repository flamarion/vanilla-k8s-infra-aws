output "role_arn" {
  description = "IAM role ARN"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "IAM role name"
  value       = aws_iam_role.this.name
}

output "instance_profile_name" {
  description = "Instance profile name (empty string if not created)"
  value       = var.create_instance_profile ? aws_iam_instance_profile.this[0].name : ""
}

output "instance_profile_arn" {
  description = "Instance profile ARN (empty string if not created)"
  value       = var.create_instance_profile ? aws_iam_instance_profile.this[0].arn : ""
}

output "policy_arns" {
  description = "Map of policy short name to its ARN"
  value       = { for k, v in aws_iam_policy.this : k => v.arn }
}
