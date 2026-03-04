# Outputs for Monitoring EC2 Module

output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.monitoring.id
}

output "instance_public_ip" {
  description = "EC2 Instance Public IP (if available)"
  value       = aws_instance.monitoring.public_ip
}

output "instance_private_ip" {
  description = "EC2 Instance Private IP"
  value       = aws_instance.monitoring.private_ip
}

output "security_group_id" {
  description = "Security Group ID"
  value       = aws_security_group.monitoring.id
}

output "s3_telemetry_bucket" {
  description = "S3 bucket for telemetry storage"
  value       = aws_s3_bucket.telemetry.bucket
}

output "iam_instance_profile" {
  description = "IAM Instance Profile name"
  value       = aws_iam_instance_profile.monitoring.name
}

output "iam_readonly_role_arn" {
  description = "IAM Role ARN for cross-account access"
  value       = aws_iam_role.monitoring_readonly.arn
}
