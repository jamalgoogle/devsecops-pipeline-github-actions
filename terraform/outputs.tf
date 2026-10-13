output "reports_bucket" {
  description = "Bucket that stores the security scan reports"
  value       = aws_s3_bucket.reports.id
}

output "ecr_repository_url" {
  description = "URL of the container registry"
  value       = aws_ecr_repository.app.repository_url
}

output "app_security_group_id" {
  description = "Security group attached to the application"
  value       = aws_security_group.app.id
}
