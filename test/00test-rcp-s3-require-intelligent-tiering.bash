#!/bin/bash

# Resource control policy requiring specific storage class in tagged S3 buckets
# github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering
# GPLv3, Copyright Paul Marcelin

# RCP TESTS
# github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering/blob/main/README.md#resource-control-policy-test



# Input: message ($1)
pause_with_message() {
  printf '\n'
  printf '\n'
  printf '\n'
  printf "%s...\n" "${1}"
  printf '\n'
  read -p 'Acknowledge... ' -e -r
  return
}

# shellcheck disable=SC2329  # Referenced in trap
general_error() {
  set +o xtrace
  set +o errexit  # Already in a final clean-up
  trap - INT EXIT
  printf '\n'
  printf '\n'
  printf 'CANNOT CONTINUE RCP TESTING. Check result of preceding operation.\n'
  printf 'If there is a permissions problem, check all applicable service and\n'
  printf 'resource policies, and all permissions of the role that is being used for\n'
  printf 'RCP testing (including any permissions boundary, session policy, etc.).\n'
  exit 1
}

# Input: s3_bucket_uri ($1)
delete_s3_bucket() {
  set -o xtrace
  aws s3 rb "${1}" --force
  set +o xtrace
  return
}

# shellcheck disable=SC2329
delete_scratch_s3_bucket_and_exit() {
  set +o xtrace
  set +o errexit
  trap - INT EXIT
  printf '\n'
  printf '\n'
  printf '==============================================================================\n'
  printf 'Delete the scratch S3 bucket...\n'
  printf '==============================================================================\n'
  printf '\n'
  delete_s3_bucket "s3://${s3_bucket_name_prefix}-scratch"
  exit 1
}

delete_test_s3_buckets_and_exit() {
  set +o xtrace
  set +o errexit  # Already in a final clean-up
  trap - INT EXIT
  printf '\n'
  printf '\n'
  printf '==============================================================================\n'
  printf 'Delete the 4 test buckets...\n'
  printf '==============================================================================\n'
  for s3_bucket_name_suffix in 'no-tags' 'tag' 'override-tag' 'both-tags'
  do
    printf '\n'
    delete_s3_bucket "s3://${s3_bucket_name_prefix}-${s3_bucket_name_suffix}"
  done
  exit 1
}



set +o xtrace   # Don't echo commands, at baseline
set -o errexit  # Stop in case of error, at baseline
set -o nounset  # Don't allow referencing a variable before setting it



printf '\n'
printf '==============================================================================\n'
printf 'Test aws-rcp-s3-require-intelligent-tiering resource control policy\n'
printf '\n'
printf 'IMPORTANT instructions:\n'
printf 'github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering/blob/main/README.md#testing\n'
printf '==============================================================================\n'
printf '\n'

trap general_error INT EXIT

timestamp=$( date --utc '+%s' )  # Seconds since start of 1970
aws_account_id=$( aws sts get-caller-identity --query 'Account' --output text )

read -p 'Unique S3 bucket name prefix   : ' \
  -e -i "deletable-acct-${aws_account_id}-ts-${timestamp}" \
  -r s3_bucket_name_prefix

read -p 'S3 storage class (not STANDARD): ' \
  -e -i 'INTELLIGENT_TIERING' \
  -r s3_storage_class

read -p 'Strict bucket tag key          : ' \
  -e -i 'cost-s3-require-storage-class-intelligent-tiering' \
  -r s3_bucket_tag_key_strict

read -p 'Permissive bucket tag key      : ' \
  -e -i 'cost-s3-require-storage-class-intelligent-tiering-override-with-object-tag' \
  -r s3_bucket_tag_key_permissive

read -p 'Object override tag key        : ' \
  -e -i 'cost-s3-override-storage-class-intelligent-tiering' \
  -r s3_object_tag_key_override_bucket_tag



pause_with_message "The setup steps should complete without errors unless noted"

printf '\n'
printf '\n'
printf '==============================================================================\n'
printf 'S1 Create an untagged scratch S3 bucket in region %s,\n' "${AWS_REGION}"
printf '   create a STANDARD-class object with a tag, delete the object,\n'
printf '   then delete the bucket\n'
printf '==============================================================================\n'
printf '\n'

s3_bucket_name="${s3_bucket_name_prefix}-scratch"
s3_bucket_uri="s3://${s3_bucket_name}"
s3_object_key='standard.txt'
s3_object_uri="${s3_bucket_uri}/${s3_object_key}"

trap delete_scratch_s3_bucket_and_exit INT EXIT
set -o xtrace
aws s3api create-bucket --bucket "${s3_bucket_name}" \
  --create-bucket-configuration "LocationConstraint=${AWS_REGION}" \
  --query 'BucketArn' --output text
aws s3api put-object \
  --body input.txt --bucket "${s3_bucket_name}" --key "${s3_object_key}" \
  --storage-class 'STANDARD' --tagging "${s3_object_tag_key_override_bucket_tag}=" \
  --query 'ETag' --output text
aws s3 rm "${s3_object_uri}"
set +o xtrace
trap general_error INT EXIT
delete_s3_bucket "${s3_bucket_uri}"

printf '\n'
printf '\n'
printf '==============================================================================\n'
printf 'S2 Create a scratch S3 bucket, tagged with the strict tag, then enable ABAC,\n'
printf '   try to create a STANDARD-class object (error expected, non-fatal),\n'
printf '   then delete the bucket\n'
printf '==============================================================================\n'
printf '\n'

trap delete_scratch_s3_bucket_and_exit INT EXIT
set +o errexit
set -o xtrace
if ! aws s3api create-bucket --bucket "${s3_bucket_name}" \
  --create-bucket-configuration \
  "LocationConstraint=${AWS_REGION},Tags=[{Key=${s3_bucket_tag_key_strict},Value=,}]" \
  --query 'BucketArn' --output text; then
    set +o xtrace
    printf '\n'
    printf 'CANNOT CONTINUE RCP TESTING. Make sure that the\n'
    printf 'S3BucketRestrictTagAndAbacChanges service control policy does not apply\n'
    printf 'to AWS account %s , or that ScpPrincipalArnNotLike matches\n' "${aws_account_id}"
    printf 'the ARN of the role that is being used for RCP testing.\n'
    exit 1
fi
set -o errexit
aws s3api put-bucket-abac --bucket "${s3_bucket_name}" --abac-status 'Status=Enabled'
if aws s3 cp input.txt "${s3_object_uri}" --storage-class 'STANDARD'; then
  set +o xtrace
  printf '\n'
  printf 'CANNOT CONTINUE RCP TESTING. Make sure that the\n'
  printf 'S3BucketRequireStorageClass resource control policy applies\n'
  printf 'to AWS account %s .\n' "${aws_account_id}"
  exit 1
fi
set +o xtrace
trap general_error INT EXIT
delete_s3_bucket "${s3_bucket_uri}"

printf '\n'
printf '\n'
printf '==============================================================================\n'
printf 'S3 Create the no-tags S3 bucket\n'
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
printf 'S4 Create the 3 tagged S3 buckets\n'
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

printf '\n'
printf '\n'
printf '==============================================================================\n'
printf 'S5 Enable attribute-based access control for the 4 buckets\n'
printf '==============================================================================\n'
for s3_bucket_name_suffix in 'no-tags' 'tag' 'override-tag' 'both-tags'
do
  s3_bucket_name="${s3_bucket_name_prefix}-${s3_bucket_name_suffix}"
  printf '\n'
  set -o xtrace
  aws s3api put-bucket-abac --bucket "${s3_bucket_name}" --abac-status 'Status=Enabled'
  set +o xtrace
done



pause_with_message "The following tests should complete without errors"

trap delete_test_s3_buckets_and_exit INT EXIT
set +o errexit  # Having checked the basics, continue in spite of errors

printf '\n'
printf '\n'
printf '==============================================================================\n'
printf 'T01 Create and delete a default-class object in the no-tags bucket\n'
printf '==============================================================================\n'
printf '\n'
s3_object_uri="s3://${s3_bucket_name_prefix}-no-tags/standard.txt"
set -o xtrace
aws s3 cp input.txt "${s3_object_uri}"
aws s3 rm "${s3_object_uri}"
set +o xtrace

printf '\n'
printf '\n'
printf '==============================================================================\n'
printf 'T02 Create and delete a STANDARD-class object in the no-tags bucket\n'
printf '==============================================================================\n'
printf '\n'
set -o xtrace
aws s3 cp input.txt "${s3_object_uri}" --storage-class 'STANDARD'
aws s3 rm "${s3_object_uri}"
set +o xtrace

printf '\n'
printf '\n'
printf '==============================================================================\n'
printf 'T03 Create and delete a(n) %s-class object in each of the 4 buckets\n' \
  "${s3_storage_class}"
printf '==============================================================================\n'
for s3_bucket_name_suffix in 'no-tags' 'tag' 'override-tag' 'both-tags'
do
  s3_object_uri="s3://${s3_bucket_name_prefix}-${s3_bucket_name_suffix}/other.txt"
  printf '\n'
  set -o xtrace
  aws s3 cp input.txt "${s3_object_uri}" --storage-class "${s3_storage_class}"
  aws s3 rm "${s3_object_uri}"
  set +o xtrace
done


printf '\n'
printf '\n'
printf '==============================================================================\n'
printf 'T04 Create, overwrite and delete a STANDARD-class object with the override tag\n'
printf '    in the bucket tagged with the permissive tag\n'
printf '    and the bucket tagged with both the strict and permissive tags\n'
printf '==============================================================================\n'
for s3_bucket_name_suffix in 'override-tag' 'both-tags'
do
  s3_bucket_name="${s3_bucket_name_prefix}-${s3_bucket_name_suffix}"
  s3_object_key='standard.txt'
  s3_object_uri="s3://${s3_bucket_name}/${s3_object_key}"
  printf '\n'
  set -o xtrace
  # shellcheck disable=SC2034
  for put_count in {1..2}
  do
    aws s3api put-object \
      --body input.txt --bucket "${s3_bucket_name}" --key "${s3_object_key}" \
      --storage-class 'STANDARD' --tagging "${s3_object_tag_key_override_bucket_tag}=" \
      --query 'ETag' --output text
  done
  aws s3 rm "${s3_object_uri}"
  set +o xtrace
done



pause_with_message "The following tests should produce errors unless noted"

printf '\n'
printf '\n'
printf '==============================================================================\n'
printf 'T05 Create and delete a STANDARD-class object in each of the 3 tagged buckets\n'
printf '==============================================================================\n'
for s3_bucket_name_suffix in 'tag' 'override-tag' 'both-tags'
do
  s3_object_uri="s3://${s3_bucket_name_prefix}-${s3_bucket_name_suffix}/standard.txt"
  printf '\n'
  set -o xtrace
  aws s3 cp input.txt "${s3_object_uri}" --storage-class 'STANDARD'
  aws s3 rm "${s3_object_uri}"
  set +o xtrace
done

printf '\n'
printf '\n'
printf '==============================================================================\n'
printf 'T06 Create and delete a STANDARD-class object with the override tag in the\n'
printf '    bucket tagged with the strict tag\n'
printf '==============================================================================\n'
printf '\n'
s3_bucket_name="${s3_bucket_name_prefix}-tag"
s3_object_key='standard.txt'
s3_object_uri="s3://${s3_bucket_name}/${s3_object_key}"
set -o xtrace
aws s3api put-object \
  --body input.txt --bucket "${s3_bucket_name}" --key "${s3_object_key}" \
  --storage-class 'STANDARD' --tagging "${s3_object_tag_key_override_bucket_tag}=" \
  --query 'ETag' --output text
aws s3 rm "${s3_object_uri}"
set +o xtrace

printf '\n'
printf '\n'
printf '==============================================================================\n'
printf 'T07 Overwrite a(n) %s-class object in the bucket\n' \
  "${s3_storage_class}"
printf '    tagged with the permissive tag\n'
printf '    with a STANDARD-class object\n'
printf '==============================================================================\n'
printf '\n'
s3_bucket_name="${s3_bucket_name_prefix}-override-tag"
s3_object_key='other.txt'
s3_object_uri="s3://${s3_bucket_name}/${s3_object_key}"
set -o xtrace
aws s3 cp input.txt "${s3_object_uri}" --storage-class 'STANDARD'
set +o xtrace



pause_with_message "The tear-down steps should complete without errors"

delete_test_s3_buckets_and_exit
