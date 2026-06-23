output "state_bucket_name" {
  description = "Use this as the 'bucket' value in infra/backend.tf"
  value       = aws_s3_bucket.terraform_state.id
}

output "lock_table_name" {
  description = "Use this as the 'dynamodb_table' value in infra/backend.tf"
  value       = aws_dynamodb_table.terraform_locks.id
}

output "github_deploy_role_arn" {
  description = "Add this as the AWS_DEPLOY_ROLE_ARN GitHub Actions secret/variable"
  value       = aws_iam_role.github_deploy.arn
}
