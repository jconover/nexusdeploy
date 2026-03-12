output "role_arns" {
  description = "Map of role key to IAM role ARN"
  value       = { for k, v in aws_iam_role.roles : k => v.arn }
}

output "role_names" {
  description = "Map of role key to IAM role name"
  value       = { for k, v in aws_iam_role.roles : k => v.name }
}

output "instance_profile_arns" {
  description = "Map of role key to instance profile ARN (only for roles with create_instance_profile=true)"
  value       = { for k, v in aws_iam_instance_profile.profiles : k => v.arn }
}

output "custom_policy_arns" {
  description = "Map of policy key to custom IAM policy ARN"
  value       = { for k, v in aws_iam_policy.custom : k => v.arn }
}
