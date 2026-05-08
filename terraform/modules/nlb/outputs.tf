output "arn" {
  description = "NLB ARN"
  value       = aws_lb.this.arn
}

output "dns_name" {
  description = "NLB DNS name"
  value       = aws_lb.this.dns_name
}

output "zone_id" {
  description = "NLB Route53 zone ID (for alias records)"
  value       = aws_lb.this.zone_id
}

output "target_group_arns" {
  description = "Map of listener key to its target group ARN"
  value       = { for k, v in aws_lb_target_group.this : k => v.arn }
}
