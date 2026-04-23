output "bucket_name" {
  value       = aws_s3_bucket.pds.id
  description = "Name of the provisioned bucket. Set this in capture.s3.bucket."
}

output "bucket_arn" {
  value = aws_s3_bucket.pds.arn
}

output "archiver_access_key_id" {
  value       = aws_iam_access_key.archiver.id
  description = "Write-only IAM user access key. Place in ${XDG_CONFIG_HOME}/pds/aws-credentials."
  sensitive   = true
}

output "archiver_secret_access_key" {
  value     = aws_iam_access_key.archiver.secret
  sensitive = true
}
