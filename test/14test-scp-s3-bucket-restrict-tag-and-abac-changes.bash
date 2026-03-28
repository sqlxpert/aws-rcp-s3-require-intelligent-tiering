#!/bin/bash

# Resource control policy requiring specific storage class in tagged S3 buckets
# github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering
# GPLv3, Copyright Paul Marcelin

# SCP TEST: DISABLE ABAC
# github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering/blob/main/README.md#service-control-policy-test



set +o xtrace   # Don't echo commands, at baseline
set -o errexit  # Stop in case of error
set -o nounset  # Don't allow referencing a variable before setting it



printf '\n'
printf '==============================================================================\n'
printf 'Test scp-s3-bucket-restrict-tag-and-abac-change service control policy\n'
printf '\n'
printf 'IMPORTANT instructions:\n'
printf 'github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering/blob/main/README.md#testing\n'
printf '==============================================================================\n'
printf '\n'

date=$( date --utc --iso-8601 )
aws_account_id=$( aws sts get-caller-identity --query 'Account' --output text )

printf  'Caller ARN                     : %s\n' \
  "$( aws sts get-caller-identity --query 'Arn' --output text )"

read -p 'Unique S3 bucket name prefix   : ' \
  -e -i "deletable-acct-${aws_account_id}-dt-${date}" \
  -r s3_bucket_name_prefix



printf '\n'
printf '\n'
printf '==============================================================================\n'
printf 'C2 Disable attribute-based access control for all 4 buckets\n'
printf '==============================================================================\n'
for s3_bucket_name_suffix in 'no-tags' 'tag' 'override-tag' 'both-tags'
do
  s3_bucket_name="${s3_bucket_name_prefix}-${s3_bucket_name_suffix}"
  printf '\n'
  set -o xtrace
  aws s3api put-bucket-abac --bucket "${s3_bucket_name}" --abac-status 'Status=Disabled'
  set +o xtrace
done
