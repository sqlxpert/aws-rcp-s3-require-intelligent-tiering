#!/bin/bash

# Resource control policy requiring specific storage class in tagged S3 buckets
# github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering
# GPLv3, Copyright Paul Marcelin

# SCP TEST: CORE TEST, WITH ABAC DISABLED
# github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering/blob/main/README.md#service-control-policy-test



set +o xtrace   # Don't echo commands, at baseline
set +o errexit  # Don't stop in case of error
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
printf 'If your role is not subject to the SCP, tests should succeed without errors.\n'
printf 'If your role is     subject to the SCP, tests should produce         errors\n'
printf 'except where noted.\n'
printf '\n'
read -p 'Acknowledge... ' -e -r



printf '\n'
printf '\n'
printf '==============================================================================\n'
printf 'T1 Set non-controlled tag, for all 4 buckets\n'
printf '   (errors expected except for -no-tag bucket, 1st of 4)\n'
printf '==============================================================================\n'
for s3_bucket_name_suffix in 'no-tags' 'tag' 'override-tag' 'both-tags'
do
  s3_bucket_name="${s3_bucket_name_prefix}-${s3_bucket_name_suffix}"
  printf '\n'
  set -o xtrace
  aws s3api put-bucket-tagging --bucket "${s3_bucket_name}" \
    --tagging "TagSet=[{Key=ArbitraryTag,Value=,}]"
  set +o xtrace
done

printf '\n'
printf '\n'
printf '==============================================================================\n'
printf 'T2 Remove all tags, from all 4 buckets\n'
printf '   (errors expected except for -no-tag bucket, 1st of 4)\n'
printf '==============================================================================\n'
for s3_bucket_name_suffix in 'no-tags' 'tag' 'override-tag' 'both-tags'
do
  s3_bucket_name="${s3_bucket_name_prefix}-${s3_bucket_name_suffix}"
  printf '\n'
  set -o xtrace
  aws s3api put-bucket-tagging --bucket "${s3_bucket_name}" \
    --tagging "TagSet=[]"
  set +o xtrace
done

printf '\n'
printf '\n'
printf '==============================================================================\n'
printf 'T3 Add non-controlled tag, to bucket with strict tag\n'
printf '   (no error expected)\n'
printf '==============================================================================\n'
s3_bucket_name="${s3_bucket_name_prefix}-tag"
set -o xtrace
aws s3api put-bucket-tagging --bucket "${s3_bucket_name}" \
  --tagging "TagSet=[{Key=${s3_bucket_tag_key_strict},Value=,},{Key=ArbitraryTag,Value=,}]"
set +o xtrace

printf '\n'
printf '\n'
printf '==============================================================================\n'
printf 'T4 Remove non-controlled tag, from bucket with strict tag\n'
printf '   (no error expected)\n'
printf '==============================================================================\n'
set -o xtrace
aws s3api put-bucket-tagging --bucket "${s3_bucket_name}" \
  --tagging "TagSet=[{Key=${s3_bucket_tag_key_strict},Value=,}]"
set +o xtrace

printf '\n'
printf '\n'
printf '==============================================================================\n'
printf 'T5 Set strict tag only, on all 4 buckets\n'
printf '   (errors expected except for -tag bucket, 2nd of 4)\n'
printf '==============================================================================\n'
for s3_bucket_name_suffix in 'no-tags' 'tag' 'override-tag' 'both-tags'
do
  s3_bucket_name="${s3_bucket_name_prefix}-${s3_bucket_name_suffix}"
  printf '\n'
  set -o xtrace
  aws s3api put-bucket-tagging --bucket "${s3_bucket_name}" \
    --tagging "TagSet=[{Key=${s3_bucket_tag_key_strict},Value=,}]"
  set +o xtrace
done

printf '\n'
printf '\n'
printf '==============================================================================\n'
printf 'T6 Set permissive tag only, on all 4 buckets\n'
printf '   (errors expected except for -override-tag bucket, 3rd of 4)\n'
printf '==============================================================================\n'
for s3_bucket_name_suffix in 'no-tags' 'tag' 'override-tag' 'both-tags'
do
  s3_bucket_name="${s3_bucket_name_prefix}-${s3_bucket_name_suffix}"
  printf '\n'
  set -o xtrace
  aws s3api put-bucket-tagging --bucket "${s3_bucket_name}" \
    --tagging "TagSet=[{Key=${s3_bucket_tag_key_permissive},Value=,}]"
  set +o xtrace
done

printf '\n'
printf '\n'
printf '==============================================================================\n'
printf 'T7 Set both strict and permissive tags, on all 4 buckets\n'
printf '   (errors expected on all 4 buckets)\n'
printf '==============================================================================\n'
for s3_bucket_name_suffix in 'no-tags' 'tag' 'override-tag' 'both-tags'
do
  s3_bucket_name="${s3_bucket_name_prefix}-${s3_bucket_name_suffix}"
  printf '\n'
  set -o xtrace
  aws s3api put-bucket-tagging --bucket "${s3_bucket_name}" \
    --tagging "TagSet=[{Key=${s3_bucket_tag_key_strict},Value=,},{Key=${s3_bucket_tag_key_permissive},Value=,}]"
  set +o xtrace
done
