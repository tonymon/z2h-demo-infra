output "state_bucket" {
  value = aws_s3_bucket.state.id
}

output "plan_role_arn" {
  description = "Set as GitHub secret AWS_ROLE_PLAN_ARN"
  value       = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  description = "Set as GitHub secret AWS_ROLE_APPLY_ARN"
  value       = aws_iam_role.apply.arn
}
