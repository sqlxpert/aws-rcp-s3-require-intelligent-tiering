# Resource control policy requiring specific storage class in tagged S3 buckets
# github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering
# GPLv3, Copyright Paul Marcelin

output "rcp_s3_bucket_require_storage_class_arn" {
  value       = aws_organizations_policy.rcp_s3_bucket_require_storage_class.arn
  description = "ARN of resource control policy to require specific S3 storage class"
}
output "rcp_s3_bucket_require_storage_class_id" {
  value       = aws_organizations_policy.rcp_s3_bucket_require_storage_class.id
  description = "Physical identifier of resource control policy"
}

output "scp_s3_bucket_restrict_tag_and_abac_changes_arn" {
  value = (
    local.generate_scp
    ? aws_organizations_policy.scp_s3_bucket_restrict_tag_and_abac_changes[0].arn
    : ""
  )
  description = "ARN of system control policy to restrict S3 bucket tag and ABAC changes"
}
output "scp_s3_bucket_restrict_tag_and_abac_changes_id" {
  value = (
    local.generate_scp
    ? aws_organizations_policy.scp_s3_bucket_restrict_tag_and_abac_changes[0].id
    : ""
  )
  description = "Physical identifier of system control policy"
}
