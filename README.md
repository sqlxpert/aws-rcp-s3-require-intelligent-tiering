# Require S3 Intelligent Tiering!

Still relying on lifecycle policies to transition S3 objects to
[Intelligent Tiering](https://builder.aws.com/content/38nqWWauUbgfDsAzx2FpigrfAMv/intelligent-tiering-is-the-best-s3-storage-class-but-data-retrieval-is-not-free)
after the fact? You're wasting money! Set `--storage-class`&nbsp;,
`StorageClass`&nbsp;, or `x-amz-storage-class` in scripts or code to avoid a
transition charge and start the
[savings countdown](https://aws.amazon.com/blogs/aws/amazon-s3-glacier-is-the-best-place-to-archive-your-data-introducing-the-s3-glacier-instant-retrieval-storage-class/#:~:text=No%20tiering%20charges%20apply,S3%20Intelligent%2DTiering%20storage%20class.)
the moment you create each object.

But how do you make sure _everybody_ is using Intelligent Tiering?

AWS&nbsp;Config, CloudFormation Hooks, and third-party Terraform tooling with
Open Policy Agent all let you require lifecycle policies on S3 buckets, but
creating objects directly in `INTELLIGENT_TIERING` makes lifecycle transition
rules unnecessary.

&#128161; I've devised **a practical way to enforce the _initial_ S3 storage
class**...every time an object is created...by any user...in one bucket or
thousands of buckets.

## How to Use It

### Strict Bucket Tag

To require Intelligent Tiering for all new objects, tag a new S3 bucket with
`cost-s3-require-storage-class-intelligent-tiering` and enable
[attribute-based access control](https://aws.amazon.com/blogs/aws/introducing-attribute-based-access-control-for-amazon-s3-general-purpose-buckets)
for the bucket.

Users who forget to add...

- `--storage-class INTELLIGENT_TIERING` when running `aws s3 cp` or
  `aws s3api put-object`
- `StorageClass="INTELLIGENT_TIERING"` when calling
  `client("s3").put_object()` in boto3 (or the equivalent in other AWS SDKs)
- `x-amz-storage-class: INTELLIGENT_TIERING` for the `PubObject` HTTP API
  operation

...get an "AccessDenied" error. In case a user missed
"require-storage-class"... in the bucket tag, the error message tells an
administrator where to look: "explicit deny in a resource control policy".

<details>
  <summary>See the complete error message</summary>

<br/>

```text
An error occurred (AccessDenied) when calling the PutObject operation:
User: arn:aws:sts::112233445566:assumed-role/AWSReservedSSO_PermSetName_0123456789abcdef/abcde
is not authorized to perform: s3:PutObject
on resource: "arn:aws:s3:::test-intelligent-tiering-class-only/standard.txt"
with an explicit deny in a resource control policy
```

</details>

Jump to:
[Installation](#installation)
&bull;
[Advanced Topics](#advanced-topics)
&bull;
[Testing](#testing)

### Object Tag Override

To require Intelligent Tiering but permit occasional overrides, tag a new S3
bucket with
`cost-s3-require-storage-class-intelligent-tiering-override-with-object-tag`&nbsp;.

In this bucket, a user can create an object in any storage class by setting the
`cost-s3-override-storage-class-intelligent-tiering` _object tag_. Add:

- `--tagging 'cost-s3-override-storage-class-intelligent-tiering='`<br/>when
  running `aws s3api put-object` (~`aws s3 cp`~ does not support tags.)
- `Tagging="cost-s3-override-storage-class-intelligent-tiering="`<br/>when
  calling `client("s3").put_object()` (or equivalent)
- `x-amz-tagging: cost-s3-override-storage-class-intelligent-tiering=`<br/>
  (Encode `=` as `%3D` if your HTTP library doesn't.)

Jump to:
[Installation](#installation)
&bull;
[Advanced Topics](#advanced-topics)
&bull;
[Testing](#testing)

## How It Works

Just 40&nbsp;lines of JSON in a resource control policy suffice to deny
`s3:PutObject` requests if the bucket has a particular bucket tag and the
requester has not set the required storage class (or the required object tag,
if overrides are permitted). It works thanks to AWS features introduced in 2024
and 2025.

<details>
  <summary>AWS feature announcements that made it possible...</summary>

<br/>

 1. With attribute-based access control, S3 now checks bucket tags when
    authorizing requests. Users can see the bucket tag, so they know the rules.
    A resource control policy won't break existing systems, because an existing
    bucket is excluded until it is tagged and its ABAC setting is enabled.

    November&nbsp;20,&nbsp;2025:
    [Amazon S3 now supports attribute-based access control](https://aws.amazon.com/about-aws/whats-new/2025/11/amazon-s3-attribute-based-access-control)

 2. S3 errors now mention the type of policy. If users miss
    "require-storage-class"... in the bucket's tag, an administrator knows to
    check AWS&nbsp;Organizations because the error message mentions "a resource
    control policy".

    June&nbsp;16,&nbsp;2025:
    [Amazon S3 extends additional context for HTTP 403 Access Denied error messages to AWS Organizations](https://aws.amazon.com/about-aws/whats-new/2025/06/amazon-s3-context-http-403-access-denied-error-message-aws-organizations)

    - &#129668; S3 wish list: If AWS extended a related feature, S3 error
      messages would reveal the resource control policy's ARN. (What a shame
      that AWS&nbsp;Organizations uses arbitrary resource identifiers instead
      of letting us specify short, meaningful names!
      `arn:aws:organizations::112233445566:policy/o-abcdefghij/resource_control_policy/p-abcdefghij`
      would be more informative than "a resource control policy", but still not
      perfect.)

      January&nbsp;21,&nbsp;2026:
      [AWS introduces additional policy details to access denied error messages](https://aws.amazon.com/about-aws/whats-new/2026/01/additional-policy-details-access-denied-error)

 3. One resource control policy can cover all S3 buckets in one or more AWS
    accounts. It's no longer necessary to edit the bucket policy for each
    individual bucket and check for drift.

    November&nbsp;13,&nbsp;2024:
    [Introducing resource control policies (RCPs) to centrally restrict access to AWS resources](https://aws.amazon.com/about-aws/whats-new/2024/11/resource-control-policies-restrict-access-aws-resources)

 4. The `s3:x-amz-storage-class` condition key makes it possible to restrict
    the storage class of new objects. At first, the available policy scopes
    were limited: a bucket policy affects only one bucket, and a named,
    customer-managed IAM policy can be attached to multiple roles, but only in
    one AWS account. Later, AWS launched AWS&nbsp;Organizations, introducing
    service control policies that can cover all roles in one or more accounts.
    Even later, AWS relaxed limitations on conditions in SCPs.

    February&nbsp;11,&nbsp;2015:
    [AWS Identity and Access Management simplifies policy management](https://aws.amazon.com/about-aws/whats-new/2015/02/11/aws-identity-and-access-management-simplifies-policy-management)

    December&nbsp;14,&nbsp;2015:
    [Condition keys for Amazon S3: s3:x-amz-storage-class](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WhatsNew.html#WhatsNew-earlier-doc-history:~:text=IAM%20policies%20now%20support,x%2Damz%2Dstorage%2Dclass%20condition%20key.)

    February&nbsp;27,&nbsp;2017:
    [AWS Organizations Now Generally Available](https://aws.amazon.com/about-aws/whats-new/2017/02/aws-organizations-now-generally-available)

    September&nbsp;19,&nbsp;2025:
    [AWS Organizations supports full IAM policy language for service control policies (SCPs)](https://aws.amazon.com/about-aws/whats-new/2025/09/aws-organizations-iam-language-service-control-policies)

    - To understand why not even SCPs provided a sufficient policy scope for
      this application, see
      [Differences between SCPs and RCPs](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_authorization_policies.html#understanding-scps-and-rcps)

</details>

## Installation

 1. Log in to the AWS Console, in your management AWS account. Use an
    administrative role. Choose the region where you manage
    infrastructure-as-code templates that creates non-regional resources.

 2. Install using CloudFormation or Terraform.

    - **CloudFormation**<br/>_Easy_ &check;

      [Create a CloudFormation stack](https://console.aws.amazon.com/cloudformation/home?#/stacks/create).

      Select "Upload a template file", then select "Choose file" and navigate
      to a locally-saved copy of
      [cloudformation/aws-rcp-s3-require-intelligent-tiering.yaml](/cloudformation/aws-rcp-s3-require-intelligent-tiering.yaml?raw=true)
      [right-click to save as...].

      On the next page, set:

      - Stack name: `S3RequireIntelligentTiering`
      - RCP root IDs, OU IDs, and/or AWS account ID numbers
        (&nbsp;`RcpTargetIds`&nbsp;):
        Enter the number of the account or the `ou-` ID of the organizational
        unit that you use for testing resource control policies.
      - See
        [Advanced Topics](#advanced-topics),
        below, for potential customizations.

    - **Terraform**

      Check that you have at least:

      - [Terraform v1.10.0 (2024-11-27)](https://github.com/hashicorp/terraform/releases/tag/v1.10.0)
      - [Terraform AWS provider v6.0.0 (2025-06-18)](https://github.com/hashicorp/terraform-provider-aws/releases/tag/v6.0.0)

      Add the following child module to your existing root module:

      ```terraform
      module "rcp_s3_require_intelligent_tiering" {
        source = "git::https://github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering.git//terraform?ref=v1.0.0"
        # Reference a specific version from github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering/releases

        rcp_target_ids = ["112233445566", "ou-abcd-efghijkl",]
      }
      ```

      Populate the `rcp_target_ids` array with a string for the number of the
      account or the `ou-` ID of the organizational unit that you use for
      testing resource control policies.

      See
      [Advanced Topics](#advanced-topics),
      below, for potential customizations.

      Have Terraform download the module's source code. Review the plan before
      typing `yes` to allow Terraform to proceed with applying the changes.

      ```shell
      terraform init
      terraform apply
      ```

 3. Log in to your test AWS account or an account in your test organizational
    unit. Use a role with full S3 permissions.

 4. If you're advanced user, see
    [Testing](#testing),
    below, for test scripts. After testing, return to Step&nbsp;9.

    Otherwise, continue with manual testing.

 5. [Create](https://console.aws.amazon.com/s3/bucket/create)
    three "general purpose" S3 buckets. Apply tags from the left column of the
    table in Step&nbsp;7 as you create the buckets. Under "Tags - optional",
    click "Add new tag".

 6. In the list of
    [buckets](https://console.aws.amazon.com/s3/buckets),
    select each bucket in turn, open the "Properties" tab, and scroll down to
    "Bucket ABAC". Click "Edit" and enable ABAC.

 7. Try to create three objects in each of the three buckets. Combinations
    marked &check; should succeed, and ones marked &cross; should produce the
    "AccessDenied" error.

    |**Step&nbsp;7: Create objects in these classes &rarr;**|Standard|Intelligent&nbsp;Tiering|Standard|
    |:---|:---:|:---:|:---:|
    |**Step&nbsp;7: Tag the objects &rarr;**|_No&nbsp;object&nbsp;tag_|_No&nbsp;object&nbsp;tag_|`cost-s3-override-storage-class-intelligent-tiering`|
    |**&darr; Step&nbsp;5: Tag the buckets**||||
    |_No bucket tag_|&check;|&check;|&check;|
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
    read -p 'Next S3 bucket: ' -e -r S3_BUCKET_NAME
    ```

    ```shell
    aws s3 cp test.txt "s3://${S3_BUCKET_NAME}"
    aws s3 cp test.txt "s3://${S3_BUCKET_NAME}" --storage-class INTELLIGENT_TIERING
    aws s3api put-object --body test.txt --bucket "${S3_BUCKET_NAME}" --key test.txt --tagging 'cost-s3-override-storage-class-intelligent-tiering='
    ```

    </details>

 8. Empty and delete the test buckets.

 9. Add other AWS account numbers, `ou-` organizational unit IDs, or the `r-`
    root ID to apply the RCP broadly.

## Advanced Topics

### Semantics

- If _both_ bucket tags are applied to the same S3 bucket, the strict bucket
  tag loses and the permissive bucket tag wins; users can override the required
  storage class with the object tag. I chose this interpretation to avoid
  contradicting what users can see: "-override-with-object-tag" in one of the
  bucket's two tags.
- Set the required storage class (or the override tag, if the bucket tag
  allows overrides) when overwriting an object or creating a new version.
- The resource control policy regulates only the _initial_ storage class.
  Lifecycle transition rules may later transition an object or object version
  to a different storage class.
  [S3 resource-based policies do not restrict lifecycle rules.](https://docs.aws.amazon.com/AmazonS3/latest/userguide/lifecycle-expire-general-considerations.html#:~:text=You%20can't%20use%20a%20bucket%20,S3%20Lifecycle%20rule.)

### Custom Tag Keys

<details details name="advanced-topics">
  <summary>Choose your own tags...</summary>

<br/>

Although you can choose whatever tag keys you like, subject to
[S3 bucket tag rules](https://docs.aws.amazon.com/AmazonS3/latest/userguide/tagging.html#tag-key)
and
[S3 object tag rules](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-tagging.html),
the defaults reflect a key prefix hierarchy that I have been recommending to
employers and clients for more than a decade. It is easy to use the
`StringLike` or `StringNotLike` operators to write
[policy conditions](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_condition.html)
that restrict permission to set all `cost-*` tags, or all `cost-s3-*` tags. By
reserving tag key prefixes for
[cost allocation](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/cost-alloc-tags.html),
[attribute-based access control](https://docs.aws.amazon.com/IAM/latest/UserGuide/tutorial_attribute-based-access-control.html),
and other system-level uses, you can safely delegate permission for users to
set other tags.

Watch out for automated processes, like backup systems, that try to copy all of
a resource's tags to a new resource! Where a system automatically copies tags
to related resources, as in the case of CloudFormation (stack tags copied to
most stack resources) or EC2 (instance tags copied to EBS volumes and their
snapshots), include the resource type in the tag key to make the tag's origin
and scope unambiguous.

</details>

### Service Control Policy

<details details name="advanced-topics">
  <summary>Protect S3 bucket tags...</summary>

<br/>

I provide an optional service control policy that you can apply to
organizational units to prevent most roles from adding the two special tags to,
or removing them from, any S3 bucket. The policy also prevents enabling or
disabling ABAC for any S3 bucket. **The lack of such a control undermines the
security of most real-world uses of ABAC.**

Test the SCP first, because it generally reduces existing S3 permissions. Human
users or automated processes might rely on those permissions.

You will need at least one exempt role in every account, to manage S3 buckets.
I recommend
[IAM Identity Center permission sets](https://docs.aws.amazon.com/singlesignon/latest/userguide/permissionsets.html).
You can customize `ScpPrincipalCondition` / `scp_principal_condition` to
[reference permission set roles](https://docs.aws.amazon.com/singlesignon/latest/userguide/referencingpermissionsets.html).

The SCP offers two-way protection: Most roles can neither remove restrictions
from S3 buckets nor place new restrictions on them. You could adapt the SCP to
provide one-way protection: most roles would not be prevented from applying the
special bucket tags in an
[`s3:CreateBucket`](https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazons3.html#amazons3-CreateBucket)
request. An exempt role would still have to enable ABAC for the new bucket.
Unfortunately, it is not possible to delegate permission to enable ABAC without
also delegating permission to disable it. A single API action,
[s3:PutBucket](https://docs.aws.amazon.com/AmazonS3/latest/API/API_PutBucketAbac.html),
serves to enable _and_ disable ABAC, and as of March,&nbsp;2026, S3 lacks a
[condition key](https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazons3.html#amazons3-policy-keys)
for checking a bucket's current ABAC status.

</details>

### Multiple Installations

<details details name="advanced-topics">
  <summary>Choose different storage classes for different applications...</summary>

<br/>

To support multiple concurrent installations, I have parameterized:

- the required storage class
- all three tag keys
- the name suffix for the RCP and SCP (It's the CloudFormation stack name, or
  the `rcp_scp_name_suffix` variable in the Terraform module.)

[Requiring `INTELLIGENT_TIERING` is best for most S3 use cases](https://builder.aws.com/content/38nqWWauUbgfDsAzx2FpigrfAMv/intelligent-tiering-is-the-best-s3-storage-class-but-data-retrieval-is-not-free#:~:text=Heuristics),
but in buckets for seldom-accessed logs, you might require that all objects be
created in `GLACIER_IR` storage class (low storage price, high retrieval
charge), or even in
[`DEEP_ARCHIVE`](https://builder.aws.com/content/38nzuuU92cmS7nEhDEZNrhjAtG5/save-more-on-s3-storage-by-implementing-asynchronous-retrieval)
(very low storage price, two-step asynchronous retrieval semantics). Perhaps
you have some buckets whose objects are always frequently-accessed and
short-lived, and you want to be sure that objects can only be created in
`STANDARD` class.

</details>

### Existing Buckets

<details details name="advanced-topics">
  <summary>Enroll existing buckets...</summary>

<br/>

Before applying either the strict or permissive bucket tag to an existing S3
bucket, be sure that all workflows have been updated to specify the required
storage class when creating objects. This is not possible for workflows you
don't control! For a bucket that is the destination of a replication rule,
[set the storage class in the replication rule](https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication-add-config.html#storage-class-configuration).

You must also remove existing lifecycle _transition_ rules if they would
[conflict](https://docs.aws.amazon.com/AmazonS3/latest/userguide/lifecycle-transition-general-considerations.html#lifecycle-general-considerations-transition-sc) with the new initial storage class. For example, if you require that new
objects be created in the Intelligent Tiering storage class, do not then
transition them to other storage classes.

You may want to add lifecycle transition rules on a temporary basis, to move
existing objects to the storage class in which new objects will be created.

Other lifecycle rules, such as lifecycle _expiration_ rules, are fine.

The options, decisions, and engineering actions are complex. The security and
cost consequences are significant. If you need help, please get in touch. This
is part of what I do for a living.

</details>

## Testing

### Test Setup

<details>
  <summary>Choose a role and authenticate...</summary>

<br/>

The test scripts assume that you have already run:

- [`aws configure`](https://docs.aws.amazon.com/cli/latest/reference/configure)
  or
  [`aws configure sso`](https://docs.aws.amazon.com/cli/latest/reference/configure/sso.html)
- [`aws login`](https://docs.aws.amazon.com/signin/latest/userguide/command-line-sign-in.html#command-line-sign-in-local-development)
  or
  [`aws sso login`](https://docs.aws.amazon.com/signin/latest/userguide/command-line-sign-in.html#command-line-sign-in-sso)

[AWS CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/welcome.html)
is an extremely convenient alternative.

The IAM role you use for each test must:

- be in an AWS account subject to the **resource** control policy
- have permission to:
  - create, tag, and delete S3 buckets
  - enable attribute-based access control: `s3:PutBucketAbac`
  - create, tag, and delete S3 _objects_

</details>

### Resource Control Policy Test

<details name="test-scope">
  <summary>Test the RCP...</summary>

<br/>

In addition to the requirements in
[Test Setup](#test-setup),
above, the role you use for testing the **R**CP must:

- not be in an account subject to the optional **service** control policy (If
  the **S**CP applies, then you must use an exempt role. See
  `ScpPrincipalCondition` / `scp_principal_condition`&nbsp;.)

Test the RCP by cloning this repository and running:

```shell
cd aws-rcp-s3-require-intelligent-tiering
./test/0test-rcp-s3-require-intelligent-tiering.bash
```

</details>

### Service Control Policy Test

<details name="test-scope">
  <summary>Test the optional SCP...</summary>

<br/>

Coming soon...

</details>

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
