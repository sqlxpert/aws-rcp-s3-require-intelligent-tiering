# Require S3 Intelligent Tiering!

Still relying on lifecycle policies to transition S3 objects to
[Intelligent Tiering](https://aws.amazon.com/s3/storage-classes/intelligent-tiering)
after the fact? You're wasting money! Set `--storage-class` in scripts and
`StorageClass` in code to avoid the transition charge and start the discount
countdown the moment you create each object.

But how do you make sure _everyone else_ is using Intelligent Tiering?

AWS&nbsp;Config, CloudFormation Hooks, and third-party Terraform tooling with
Open Policy Agent all let you require lifecycle policies on S3 buckets, but
creating objects directly in `INTELLIGENT_TIERING` makes lifecycle transition
rules unnecessary.

I've discovered **a practical way to enforce the initial storage class**. Every
time an object is created. By any user. In one S3 bucket or thousands. With
configuration, not executable code.

## How to Use It

### Strict Bucket Tag

To require Intelligent Tiering for all new objects, tag an S3 bucket with
`cost-s3-require-storage-class-intelligent-tiering` (you can customize this tag
key; the tag value is ignored) and enable
[attribute-based access control](https://aws.amazon.com/blogs/aws/introducing-attribute-based-access-control-for-amazon-s3-general-purpose-buckets)
for the bucket.

Users who forget to...

- add `--storage-class INTELLIGENT_TIERING` when running `aws s3 cp`<br/>or
  `aws s3api put-object`
- set `StorageClass` when calling `client("s3").put_object()` in boto3<br/>(or
  the equivalent in a different AWS SDK)
- set the `x-amz-storage-class` header for the `PubObject` HTTP API operation

...will receive an "AccessDenied" error. In case a user misses
"require-storage-class-intelligent-tiering" in the bucket tag, the error
message tells an administrator where to look: "explicit deny in a resource
control policy".

### Permissive Bucket Tag with Object Tag Override

To require Intelligent Tiering but let users override the requirement, tag an
S3 bucket with
`cost-s3-require-storage-class-intelligent-tiering-override-with-object-tag`&nbsp;.
This tag wins if you accidentally apply both bucket tags to the same bucket.

A user can create an object in any storage class by setting the
`cost-s3-override-storage-class-intelligent-tiering` _object tag_. Add:

- `--tagging 'cost-s3-override-storage-class-intelligent-tiering='`<br/>when
  running `aws s3api put-object` (~`aws s3 cp`~ does not support tags.)
- `Tagging="cost-s3-override-storage-class-intelligent-tiering="`<br/>when
  calling `client("s3").put_object()` (or equivalent)
- `x-amz-tagging: cost-s3-override-storage-class-intelligent-tiering=`<br/>
  (Encode `=` as `%3D` if your HTTP library doesn't.)

Also do this when overwriting an object or creating a new version.

## How It Works

Just 40&nbsp;lines of JSON in a resource control policy suffice to deny
`s3:PutObject` requests if the bucket has a particular bucket tag and the
requester has not set the required storage class (or the required object tag,
if overrides are permitted). AWS announced the last necessary feature in
November,&nbsp;2025!

<details>
  <summary>AWS feature announcements that made it possible...</summary>

<br/>

 1. With attribute-based access control, S3 now checks bucket tags when
    authorizing requests. Users can see the bucket tag, so they know the rules.
    A resource control policy won't break existing systems, because an existing
    bucket is excluded until it is tagged and its ABAC setting is enabled.

    November&nbsp;20,&nbsp;2025: [Amazon S3 now supports attribute-based access control](https://aws.amazon.com/about-aws/whats-new/2025/11/amazon-s3-attribute-based-access-control)

 2. S3 errors now mention the kind of policy involved. If users miss
    "require-storage-class-intelligent tiering" in the bucket's tag, they can
    ask an administrator, who will know to check AWS&nbsp;Organizations because
    the error message mentions "explicit deny in a resource control policy".

    June&nbsp;16,&nbsp;2025: [Amazon S3 extends additional context for HTTP 403 Access Denied error messages to AWS Organizations](https://aws.amazon.com/about-aws/whats-new/2025/06/amazon-s3-context-http-403-access-denied-error-message-aws-organizations)

    - &#129668; S3 feature wish: If AWS extends a related improvement, S3 error
      messages will reveal the ARN of the resource control policy. What a shame
      that AWS&nbsp;Organizations uses arbitrary resource identifiers instead
      of letting us specify short names!
      `arn:aws:organizations::112233445566:policy/o-abcdefghij/resource_control_policy/p-abcdefghij`
      doesn't say much.

      January&nbsp;21,&nbsp;2026: [AWS introduces additional policy details to access denied error messages](https://aws.amazon.com/about-aws/whats-new/2026/01/additional-policy-details-access-denied-error)

 3. Resource control policies now make it possible to regulate all the S3
    buckets in one or more AWS accounts without having to edit the bucket
    policy for each individual bucket and check for drift.

    November&nbsp;13,&nbsp;2024: [Introducing resource control policies (RCPs) to centrally restrict access to AWS resources](https://aws.amazon.com/about-aws/whats-new/2024/11/resource-control-policies-restrict-access-aws-resources)

 4. The `s3:x-amz-storage-class` condition key makes it possible to restrict
    the storage class of new objects. The scope was limited: one bucket, with a
    bucket policy, or one role, with an inline IAM policy. Named,
    customer-managed IAM policies that can be attached to multiple roles in the
    same AWS account came later, then service control policies that cover all
    roles in one or more accounts.

    [December&nbsp;14,&nbsp;2015](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WhatsNew.html#WhatsNew-earlier-doc-history#WhatsNew-earlier-doc-history:~:text=December%2014%2C%202015):
    [Condition keys for Amazon S3: s3:x-amz-storage-class](https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazons3.html#amazons3-s3_x-amz-storage-class)

</details>

## Installation

 1. Log in to the AWS Console, in your management AWS account, as an
    administrator. Choose the region where you manage most
    infrastructure-as-code, noting that this template creates non-regional
    resources.

 2. Install using CloudFormation or Terraform.

    - **CloudFormation**<br/>_Easy_ &check;

      [Create a CloudFormation stack](https://console.aws.amazon.com/cloudformation/home?#/stacks/create).

      Select "Upload a template file", then select "Choose file" and navigate
      to a locally-saved copy of
      [cloudformation/aws-rcp-s3-require-intelligent-tiering.yaml](/cloudformation/aws-rcp-s3-require-intelligent-tiering.yaml?raw=true)
      [right-click to save as...].

      On the next page, set:

      - Stack name: `S3RequireIntelligentTiering`
      - RCP root IDs, OU IDs, and/or AWS account ID numbers:
        Enter the account number or the `ou-` ID of the organizational unit
        that you use for testing resource and service control policies.

    - **Terraform**

      Coming soon...

 3. Log in to your test AWS account or an account in your test organizational
    unit. Use a role with permission to create, configure, and fill S3 buckets.

 4. In the AWS Console,
    [create](https://console.aws.amazon.com/s3/bucket/create)
    three S3 general purpose buckets. The first column of the table in
    Step&nbsp;6 indicates tags to apply as you create the buckets. Under
    "Tags - optional", click "Add new tag".

 5. In the list of
    [buckets](https://console.aws.amazon.com/s3/buckets),
    select each bucket in turn, open the "Properties" tab, and scroll down to
    "Bucket ABAC". Click "Edit" and enable ABAC.

 6. Test the RCP by creating objects in the indicated storage classes, with and
    without the override tag.

    |**Create object in storage class** &rarr;|Standard|Intelligent&nbsp;Tiering|Standard|
    |:---|:---:|:---:|:---:|
    |**Tag object** &rarr;|No|No|`cost-s3-override-storage-class-intelligent-tiering`|
    |&darr; **Tag bucket**||||
    |No|&check;|&check;||
    |`cost-s3-require-storage-class-intelligent-tiering`|&cross;|&check;|&cross;|
    |`cost-s3-require-storage-class-intelligent-tiering-override-with-object-tag`|&cross;|&check;|&check;|

    <details>
      <summary>Sample AWS CLI commands...</summary>

    <br/>

    Try these in
    [AWS CloudShell](https://console.aws.amazon.com/cloudshell/home)!

    ```shell
    cd /tmp
    echo 'Test data' > test.txt
    ```

    ```shell
    read -p 'Name of next S3 bucket: ' -e -r S3_BUCKET_NAME
    ```

    ```shell
    aws s3 cp test.txt "s3://${S3_BUCKET_NAME}"
    ```

    ```shell
    aws s3 cp test.txt "s3://${S3_BUCKET_NAME}" --storage-class INTELLIGENT_TIERING
    ```

    ```shell
    aws s3api put-object --body test.txt --bucket "${S3_BUCKET_NAME}" --key test.txt --tagging 'cost-s3-override-storage-class-intelligent-tiering='
    ```

    </details>

 7. Empty and delete the test buckets.

 8. Add other AWS account numbers, `ou-` organization unit IDs, or the `r-`
    root ID to apply the RCP broadly.

## Advanced Options

### Service Control Policy to Protect Bucket Tags

I provide an optional service control policy that you can apply to `ou-`
organizational units to prevent roles from adding the two special tags to, or
removing them from, any S3 bucket. The policy also prevents roles from enabling
or disabling ABAC for any S3 bucket. You should define an exempt role in every
AWS account.

### Customization and Multiple Installations

I parameterized the storage class string, and the tag keys, and appended the
CloudFormation stack name to the RCP and SCP names, to support multiple
installations. In buckets used for log storage, you might require that objects
be created in the low-price `GLACIER` storage class, or even
`DEEP_ARCHIVE`&nbsp;. Perhaps you have some buckets whose objects should always
start in `STANDARD` class.

## Testing

### Resource Control Policy Test

<details>
  <summary>RCP test script instructions</summary>

<br/>

Test the RCP by running
[test/0test-rcp-s3-require-intelligent-tiering.bash](/test/0test-rcp-s3-require-intelligent-tiering.bash?raw=true)&nbsp;.
The script assumes that you have already run:

- [`aws configure`](https://docs.aws.amazon.com/cli/latest/reference/configure)
  or
  [`aws configure sso`](https://docs.aws.amazon.com/cli/latest/reference/configure/sso.html)
- [`aws login`](https://docs.aws.amazon.com/signin/latest/userguide/command-line-sign-in.html#command-line-sign-in-local-development)
  or
  [`aws sso login`](https://docs.aws.amazon.com/signin/latest/userguide/command-line-sign-in.html#command-line-sign-in-sso)

[AWS CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/welcome.html)
is an extremely convenient alternative, if you use the Console.

The IAM role you use for RCP testing must:

- be in an AWS account subject to the resource control policy
- not be in an account subject to the optional service control policy (If
  the SCP applies, then you must use an exempt role. See the
  `ScpPrincipalCondition` parameter.)
- have permission to:
  - create, tag, and delete S3 buckets
  - create, tag, and delete S3 objects
  - enable attribute-based access control for S3 buckets: `s3:PutBucketAbac`
  - enable versioning: `s3:PutBucketVersioning`

</details>

### Service Control Policy Test

Coming soon!

### Bug Reporting

Please
[report bugs](/../../issues).
Thank you!

## Licenses

|Scope|Link|Included Copy|
|:---|:---|:---|
|Source code, and source code in documentation|[GNU General Public License (GPL) 3.0](http://www.gnu.org/licenses/gpl-3.0.html)|[LICENSE-CODE.md](/LICENSE-CODE.md)|
|Documentation, including this ReadMe file|[GNU Free Documentation License (FDL) 1.3](http://www.gnu.org/licenses/fdl-1.3.html)|[LICENSE-DOC.md](/LICENSE-DOC.md)|

Copyright Paul Marcelin

Contact: `marcelin` at `cmu.edu` (replace "at" with `@`)
