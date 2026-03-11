# Resource control policy requiring specific storage class in tagged S3 buckets
# github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering
# GPLv3, Copyright Paul Marcelin

locals {
  module_directory = basename(path.module)
  rcp_scp_tags = merge(
    {
      terraform = "1"
      source    = "https://github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering/blob/main/${local.module_directory}"
      rights    = "GPLv3. Copyright Paul Marcelin."
    },
    var.rcp_scp_tags,
  )

  generate_scp = (length(var.scp_principal_condition) > 0)

  apply_rcp = var.enable_rcp && (length(var.rcp_target_ids) > 0)
  apply_scp = (
    local.generate_scp && var.enable_scp && (length(var.scp_target_ids) > 0)
  )

  apply_rcp_target_ids_set = toset(local.apply_rcp ? var.rcp_target_ids : [])
  apply_scp_target_ids_set = toset(local.apply_scp ? var.scp_target_ids : [])
}
