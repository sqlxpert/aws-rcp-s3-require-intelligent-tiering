# Resource control policy requiring specific storage class in tagged S3 buckets
# github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering
# GPLv3, Copyright Paul Marcelin

variable "rcp_scp_name_suffix" {
  type        = string
  description = "Resource and service control policy name suffix, for blue/green deployments or other scenarios in which you install multiple instances of this module. This suffix should reflect require_s3_storage_class . If you have also installed the CloudFormation template equivalent to this Terraform module, this suffix must differ from the stack name(s)."

  default = "S3RequireIntelligentTiering"
}

variable "enable_rcp" {
  type        = bool
  description = "Whether to apply the resource control policy to its designated targets. Change this to false to detach the RCP but preserve the list of its targets."

  default = true
}

variable "rcp_target_ids" {
  type        = list(string)
  description = "Up to 100 r- root ID strings, ou- organizational unit ID strings, and/or AWS account ID numbers to which the RCP will apply. To view the RCP before applying it leave this empty, or start with enable_rcp set to false . Exercise caution when applying any RCP, but note that this RCP generally does not affect pre-existing S3 buckets; it only affects S3 buckets with designated tags."

  default = []
}

variable "require_s3_storage_class" {
  type        = string
  description = "Storage class in which objects in tagged S3 buckets must be created. Recommended: INTELLIGENT_TIERING (the default in this template). Not recommended: STANDARD_IA , ONEZONE_IA or GLACIER_IR ; use INTELLIGENT_TIERING . Not recommended: GLACIER ; use GLACIER_IR . Requires asynchronous retrieval: GLACIER or DEEP_ARCHIVE . Suitable if you use this template for permissions rather than cost management: STANDARD (the default in S3, except for replication). Effectively deprecated: REDUCED_REDUNDANCY . See https://docs.aws.amazon.com/AmazonS3/latest/API/API_PutObject.html#AmazonS3-PutObject-request-header-StorageClass"

  default = "INTELLIGENT_TIERING"

  validation {
    error_message = "Must be one of the values listed in the description."

    condition = contains(
      [
        "INTELLIGENT_TIERING",
        "STANDARD_IA",
        "GLACIER_IR",
        "GLACIER",
        "DEEP_ARCHIVE",
        "STANDARD",
        "ONEZONE_IA",
        "REDUCED_REDUNDANCY",
      ],
      var.require_s3_storage_class
    )
  }
}

variable "s3_bucket_tag_key_strict" {
  type        = string
  description = "S3 bucket tag key to require that all objects be created in the designated storage class. This should reflect require_s3_storage_class . To activate, make sure that the AWS account is subject to the RCP, then enable attribute-based access control for the bucket and apply this tag to the bucket. (The tag value is ignored.) Do not apply this tag to a bucket that is the destination of replication rule, unless the rule also specifies the correct storage class. For bucket tag rules, see https://docs.aws.amazon.com/AmazonS3/latest/userguide/tagging.html#tag-key . For ABAC, see  https://docs.aws.amazon.com/AmazonS3/latest/userguide/buckets-tagging-enable-abac.html . For replication storage class, see https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication-add-config.html#storage-class-configuration"

  default = "cost-s3-require-storage-class-intelligent-tiering"
}

variable "s3_bucket_tag_key_permissive" {
  type        = string
  description = "S3 bucket tag key to require that objects without the overriding S3 object tag be created in the designated storage class. This should reflect require_s3_storage_class . To activate, make sure that the AWS account is subject to the RCP, then enable ABAC for the bucket and apply this tag to the bucket. (The tag value is ignored.) Do not apply this tag to a bucket that is the destination of a replication rule, unless the rule also specifies the correct storage class. This permissive bucket tag key must be different from its non-overridable counterpart. Recommended: Copy s3_bucket_tag_key_strict and append a suffix."

  default = "cost-s3-require-storage-class-intelligent-tiering-override-with-object-tag"

  validation {
    error_message = "Must be different from s3_bucket_tag_key_strict ."

    condition = (
      var.s3_bucket_tag_key_permissive != var.s3_bucket_tag_key_strict
    )
  }
}

variable "s3_object_tag_key_override_bucket_tag" {
  type        = string
  description = "S3 object tag key to override the required storage class in a bucket tagged with the permissive bucket key, s3_bucket_tag_key_permissive . This should reflect require_s3_storage_class . To create an object in a different storage class, set this object tag in the request to create the object, and in every request to overwrite the object or create a new version. This object tag key must be different from both bucket tag keys. For object tag rules, see https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-tagging.html"

  default = "cost-s3-override-storage-class-intelligent-tiering"

  validation {
    error_message = "Must be different from s3_bucket_tag_key_strict and s3_bucket_tag_key_permissive ."

    condition = !contains(
      [
        var.s3_bucket_tag_key_strict,
        var.s3_bucket_tag_key_permissive,
      ],
      var.s3_object_tag_key_override_bucket_tag
    )
  }
}

variable "enable_scp" {
  type        = bool
  description = "Whether to apply the service control policy (if generated) to its designated targets. Change this to false to detach the SCP but preserve the list of its targets."

  default = true
}

variable "scp_target_ids" {
  type        = list(string)
  description = "Up to 100 r- root ID strings, ou- organizational unit ID strings, and/or AWS account ID numbers to which the SCP (if generated) will apply. You may wish to apply the SCP, which restricts S3 bucket tag and ABAC changes, to a target before applying the RCP, which actually enforces the required storage class in tagged buckets. In some organizational units, you might want the benefit of the RCP but give all users control over S3 bucket tags and ABAC by not applying the SCP. To view the SCP before applying it, leave this empty, or start with enable_scp set to false . Exercise caution when applying this SCP, because it generally does reduce existing permissions."

  default = []
}

variable "scp_principal_condition" {
  type        = string
  description = "One or more condition expressions determining which roles (or other IAM principals) are not allowed to set/change/remove the designated S3 bucket tags or enable/disable ABAC, for buckets in AWS accounts subject to the SCP. Separate multiple expressions with commas. Follow Terraform string escape rules for double quotation marks (prefix with a backslash) and any IAM policy variables (double the dollar sign). The default means that a request to change ABAC or the designated tags will be denied if it is not made by the manage-s3 role. (Separately, you would have to create the manage-s3 role and attach an IAM policy allowing the role to read and change S3 bucket tags and ABAC.) To avoid generating the SCP, leave this blank. \"ForAnyValue:StringEquals\" is forbidden; to use this condition operator, write a custom policy. For condition operators, see https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_condition_operators.html . For condition keys, see https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_condition-keys.html#condition-keys-principal-properties"

  default = "\"ArnNotLike\": { \"aws:PrincipalArn\": \"arn:aws:iam::*:role/manage-s3\" }"

  validation {
    error_message = "\"ForAnyValue:StringEquals\" is forbidden. To use this condition operator, write a custom policy."

    condition = length(regexall(
      "\"ForAnyValue:StringEquals\"",
      var.scp_principal_condition
    )) == 0
  }
}

variable "rcp_scp_tags" {
  type        = map(string)
  description = "Tag map for the RCP and SCP. Keys, all optional, are tag keys. Values are tag values. This takes precedence over the Terraform AWS provider's default_tags and over tags attributes defined by the module. To remove tags defined by the module, set the terraform , name_suffix , source and rights tags to null ."

  default = {}
}
