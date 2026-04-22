# Resource control policy requiring specific storage class in tagged S3 buckets
# github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering
# GPLv3, Copyright Paul Marcelin

plugin "aws" {
  enabled = true
  version = "0.47.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
