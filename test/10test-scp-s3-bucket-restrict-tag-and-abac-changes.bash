#!/bin/bash

# Resource control policy requiring specific storage class in tagged S3 buckets
# github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering
# GPLv3, Copyright Paul Marcelin

# SCP TEST: SETUP
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

read -p 'Strict bucket tag key          : ' \
  -e -i 'cost-s3-require-storage-class-intelligent-tiering' \
  -r s3_bucket_tag_key_strict

read -p 'Permissive bucket tag key      : ' \
  -e -i 'cost-s3-require-storage-class-intelligent-tiering-override-with-object-tag' \
  -r s3_bucket_tag_key_permissive



printf '\n'
printf '\n'
printf '==============================================================================\n'
printf 'S1 Create the no-tags S3 bucket\n'
printf '==============================================================================\n'
printf '\n'
set -o xtrace
aws s3api create-bucket --bucket "${s3_bucket_name_prefix}-no-tags" \
  --create-bucket-configuration \
  "LocationConstraint=${AWS_REGION}" \
  --query 'BucketArn' --output text
set +o xtrace

printf '\n'
printf '\n'
printf '==============================================================================\n'
printf 'S1 Create the 3 tagged S3 buckets\n'
printf '==============================================================================\n'
printf '\n'
set -o xtrace

aws s3api create-bucket --bucket "${s3_bucket_name_prefix}-tag" \
  --create-bucket-configuration \
  "LocationConstraint=${AWS_REGION},Tags=[{Key=${s3_bucket_tag_key_strict},Value=,}]" \
  --query 'BucketArn' --output text

aws s3api create-bucket --bucket "${s3_bucket_name_prefix}-override-tag" \
  --create-bucket-configuration \
  "LocationConstraint=${AWS_REGION},Tags=[{Key=${s3_bucket_tag_key_permissive},Value=,}]" \
  --query 'BucketArn' --output text

aws s3api create-bucket --bucket "${s3_bucket_name_prefix}-both-tags" \
  --create-bucket-configuration \
  "LocationConstraint=${AWS_REGION},Tags=[{Key=${s3_bucket_tag_key_strict},Value=,},{Key=${s3_bucket_tag_key_permissive},Value=,}]" \
  --query 'BucketArn' --output text

set +o xtrace
