# Resource control policy requiring specific storage class in tagged S3 buckets
# github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering
# GPLv3, Copyright Paul Marcelin



resource "aws_organizations_policy" "rcp_s3_bucket_require_storage_class" {
  type        = "RESOURCE_CONTROL_POLICY"
  name        = "S3BucketRequireStorageClass-${var.rcp_scp_name_suffix}"
  description = "S3 bucket tagged '${var.s3_bucket_tag_key_strict}': Require that all objects be created in ${var.require_s3_storage_class} storage class. ABAC must be enabled for the bucket. Bucket tagged '${var.s3_bucket_tag_key_permissive}': Override by tagging an object '${var.s3_object_tag_key_override_bucket_tag}' on creation. GPLv3, Copyright Paul Marcelin. github.com/sqlxpert"

  # I prefer data.aws_iam_policy_document , but a HEREDOC allows source parity
  # with CloudFormation (except for variables):
  content = <<-END_POLICY
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Sid": "S3BucketRequireStorageClass",
          "Effect": "Deny",
          "Principal": "*",
          "Action": "s3:PutObject",
          "Resource": "*",
          "Condition": {
            "Null": {
              "s3:BucketTag/${var.s3_bucket_tag_key_strict}": false,
              "s3:BucketTag/${var.s3_bucket_tag_key_permissive}": true
            },
            "StringNotEquals": {
              "s3:x-amz-storage-class": "${var.require_s3_storage_class}"
            }
          }
        },
        {
          "Sid": "S3BucketRequireStorageClassButPermitObjectOverride",
          "Effect": "Deny",
          "Principal": "*",
          "Action": "s3:PutObject",
          "Resource": "*",
          "Condition": {
            "Null": {
              "s3:BucketTag/${var.s3_bucket_tag_key_permissive}": false
            },
            "StringNotEquals": {
              "s3:x-amz-storage-class": "${var.require_s3_storage_class}"
            },
            "ForAllValues:StringNotEquals": {
              "s3:RequestObjectTagKeys": "${var.s3_object_tag_key_override_bucket_tag}"
            }
          }
        }
      ]
    }
  END_POLICY
}

resource "aws_organizations_policy_attachment" "rcp_s3_bucket_require_storage_class" {
  for_each = local.apply_rcp_target_ids_set

  policy_id = aws_organizations_policy.rcp_s3_bucket_require_storage_class.id
  target_id = each.key
}



locals {
  comma_after_scp_principal_condition = (
    length(var.scp_principal_condition) > 0 ? "," : ""
  )
}

resource "aws_organizations_policy" "scp_s3_bucket_restrict_tag_and_abac_changes" {
  count = local.generate_scp ? 1 : 0

  type        = "SERVICE_CONTROL_POLICY"
  name        = "S3BucketRestrictTagAndAbacChanges-${var.rcp_scp_name_suffix}"
  description = "S3 bucket: Matching IAM principals cannot set/change/remove '${var.s3_bucket_tag_key_strict}' or '${var.s3_bucket_tag_key_permissive}' bucket tags, or enable/disable ABAC. Applicable tag permissions vary based on ABAC status; see statement IDs. GPLv3, Copyright Paul Marcelin. github.com/sqlxpert"

  # See "Semantics" comment in
  # ../cloudformation/aws-rcp-s3-require-intelligent-tiering.yaml

  # I prefer data.aws_iam_policy_document , but a HEREDOC allows source parity
  # with CloudFormation (except for variables) and permits insertion of values
  # that the user specifies in JSON (native for the IAM policy language):
  content = <<-END_POLICY
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Deny",
          "Action": "s3:PutBucketAbac",
          "Resource": "*",
          "Condition": {
            ${var.scp_principal_condition}
          }
        },
        {
          "Sid": "BucketAbacEnabled",
          "Effect": "Deny",
          "Action": [
            "s3:TagResource",
            "s3:UntagResource"
          ],
          "Resource": "*",
          "Condition": {
            ${var.scp_principal_condition}${local.comma_after_scp_principal_condition}
            "ForAnyValue:StringEquals": {
              "aws:TagKeys": [
                "${var.s3_bucket_tag_key_strict}",
                "${var.s3_bucket_tag_key_permissive}"
              ]
            }
          }
        },
        {
          "Sid": "CannotAddTag1BucketAbacDisabled",
          "Effect": "Deny",
          "Action": "s3:PutBucketTagging",
          "Resource": "*",
          "Condition": {
            ${var.scp_principal_condition}${local.comma_after_scp_principal_condition}
            "Null": {
              "s3:BucketTag/${var.s3_bucket_tag_key_strict}": true
            },
            "ForAnyValue:StringEquals": {
              "aws:TagKeys": "${var.s3_bucket_tag_key_strict}"
            }
          }
        },
        {
          "Sid": "CannotAddTag2BucketAbacDisabled",
          "Effect": "Deny",
          "Action": "s3:PutBucketTagging",
          "Resource": "*",
          "Condition": {
            ${var.scp_principal_condition}${local.comma_after_scp_principal_condition}
            "Null": {
              "s3:BucketTag/${var.s3_bucket_tag_key_permissive}": true
            },
            "ForAnyValue:StringEquals": {
              "aws:TagKeys": "${var.s3_bucket_tag_key_permissive}"
            }
          }
        },
        {
          "Sid": "CannotRemoveTag1BucketAbacDisabled",
          "Effect": "Deny",
          "Action": "s3:PutBucketTagging",
          "Resource": "*",
          "Condition": {
            ${var.scp_principal_condition}${local.comma_after_scp_principal_condition}
            "Null": {
              "s3:BucketTag/${var.s3_bucket_tag_key_strict}": false
            },
            "ForAllValues:StringNotEquals": {
              "aws:TagKeys": "${var.s3_bucket_tag_key_strict}"
            }
          }
        },
        {
          "Sid": "CannotRemoveTag2BucketAbacDisabled",
          "Effect": "Deny",
          "Action": "s3:PutBucketTagging",
          "Resource": "*",
          "Condition": {
            ${var.scp_principal_condition}${local.comma_after_scp_principal_condition}
            "Null": {
              "s3:BucketTag/${var.s3_bucket_tag_key_permissive}": false
            },
            "ForAllValues:StringNotEquals": {
              "aws:TagKeys": "${var.s3_bucket_tag_key_permissive}"
            }
          }
        }
      ]
    }
  END_POLICY
}

resource "aws_organizations_policy_attachment" "scp_s3_bucket_restrict_tag_and_abac_changes" {
  for_each = local.apply_scp_target_ids_set

  policy_id = aws_organizations_policy.scp_s3_bucket_restrict_tag_and_abac_changes[0].id
  target_id = each.key
}
