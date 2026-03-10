# Require S3 Intelligent Tiering!

_Enforce use of Intelligent Tiering by tagging S3 buckets_

Still relying on a lifecycle policy to transition S3 objects to
[Intelligent Tiering](https://aws.amazon.com/s3/storage-classes/intelligent-tiering)
after the fact? You're losing money! Set `--storage-class` in your scripts or
`StorageClass` in your code to avoid the transition charge and start the
discount countdown the moment you create each object.

But how do you make sure _everyone else_ is using Intelligent Tiering?

AWS&nbsp;Config, CloudFormation Hooks, and third-party Terraform tooling with
Open Policy Agent all let you require lifecycle policies on S3 buckets, but the
best practice of creating objects directly in `INTELLIGENT_TIERING` makes
lifecycle transition rules unnecessary. Checking hundreds or thousands of
S3 buckets every 24 hours with AWS Config isn't cheap, anyway. Neither is
licensing and configuring third-party software.

By putting three new AWS features and one old one together, I've found a
practical way to enforce the initial storage class. Every time an object is
created. By any user. In one S3 bucket or thousands. For free!

## How to Use It

A single CloudFormation stack (Terraform is coming), deployed in your
management account, creates a resource control policy. It's safe to apply the
RCP throughout your organization, because it doesn't affect existing buckets.

### Strict Bucket Tag

To require Intelligent Tiering for all new objects, tag an S3 bucket with
`cost-s3-require-storage-class-intelligent-tiering` (you can customize
the tag) and enable
[attribute-based access control](https://aws.amazon.com/blogs/aws/introducing-attribute-based-access-control-for-amazon-s3-general-purpose-buckets)
for the bucket.

Users who forget to...

- add `--storage-class INTELLIGENT_TIERING` when running `aws s3 cp` or
  `aws s3api put-object`
- set `StorageClass` when calling `client("s3").put_object()` in boto3, or the
  equivalent in a different AWS SDK
- set the `x-amz-storage-class` header when calling `PubObject` in the HTTPS
  API

...will receive an `AccessDenied` error with the message "explicit deny in a
resource control policy". Users can't see RCPs, but they can see
"require-storage-class-intelligent-tiering" in the bucket tag. If they miss
that, the RCP hint in the error message tells an administrator exactly where to
look.

Pretty soon, setting the storage class will be second-nature.

### Permissive Bucket Tag with Object Tag Override

To require Intelligent Tiering but let users override the requirement, tag an
S3 bucket with
`cost-s3-require-storage-class-intelligent-tiering-override-with-object-tag`
(again you can customize this) and enable ABAC for the bucket.

A user can choose any storage class (or leave it to get `STANDARD`) by:

- adding `--tagging 'cost-s3-override-storage-class-intelligent-tiering='` when
  running `aws s3api put-object`
- setting `Tagging=cost-s3-override-storage-class-intelligent-tiering=` when
  calling  `client("s3").put_object()` in boto3, or the equivalent in a
  different AWS SDK
- setting the `x-amz-tagging` header to
  `cost-s3-override-storage-class-intelligent-tiering=` when calling
  `PubObject` in the HTTPS API. Encode `=` as `%3D` if
  other software doesn't do it for you. Separate additional _tag_=_value_ pairs
  with `&`&nbsp;, encoded as `%26`&nbsp;.

## How It Works

Background coming soon

## Installation

### CloudFormation Installation

Instructions coming soon

### Terraform Installation

Coming soon!

## Test

### Resource Control Policy Test

Test the RCP by running
[test/0test-rcp-s3-require-intelligent-tiering.bash](/test/0test-rcp-s3-require-intelligent-tiering.bash?raw=true)&nbsp;.
The script assumes that you have already run:

- [`aws configure`](https://docs.aws.amazon.com/cli/latest/reference/configure)
  or
  [`aws configure sso`](https://docs.aws.amazon.com/cli/latest/reference/configure/sso.html)
- [`aws login`](https://docs.aws.amazon.com/signin/latest/userguide/command-line-sign-in.html#command-line-sign-in-local-development)
  or
  [`aws sso login`](https://docs.aws.amazon.com/signin/latest/userguide/command-line-sign-in.html#command-line-sign-in-sso)

[CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/welcome.html)
is an extremely convenient alternative, if you use the AWS Console.

The IAM role you use for RCP testing must:

- be in an AWS account subject to the resource control policy
- not be in an AWS account subject to the optional service control policy (If
  the SCP applies, then you must use a role allowed by the
  `ScpPrincipalCondition` CloudFormation parameter.)
- have permission to:
  - create, tag, and delete S3 buckets
  - create, tag, and delete S3 objects
  - enable attribute-based access control for S3 buckets (`s3:PutBucketAbac`)

### Service Control Policy Test

Coming soon!

### Report Bugs

Please
[report bugs](/../../issues). Thank you!

## Licenses

|Scope|Link|Included Copy|
|:---|:---|:---|
|Source code, and source code in documentation|[GNU General Public License (GPL) 3.0](http://www.gnu.org/licenses/gpl-3.0.html)|[LICENSE-CODE.md](/LICENSE-CODE.md)|
|Documentation, including this ReadMe file|[GNU Free Documentation License (FDL) 1.3](http://www.gnu.org/licenses/fdl-1.3.html)|[LICENSE-DOC.md](/LICENSE-DOC.md)|

Copyright Paul Marcelin

Contact: `marcelin` at `cmu.edu` (replace "at" with `@`)
