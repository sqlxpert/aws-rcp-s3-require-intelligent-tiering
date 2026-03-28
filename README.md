# Require S3 Intelligent Tiering!

Still relying on lifecycle policies to transition S3 objects to Intelligent
Tiering after the fact? You're wasting money! Set the storage class in scripts
or code to avoid a transition charge and start the
[savings countdown](https://aws.amazon.com/blogs/aws/amazon-s3-glacier-is-the-best-place-to-archive-your-data-introducing-the-s3-glacier-instant-retrieval-storage-class/#:~:text=No%20tiering%20charges%20apply,S3%20Intelligent%2DTiering%20storage%20class.)
the moment you create each object.

But how do you make sure _everybody_ does it?

AWS&nbsp;Config, CloudFormation Hooks, and third-party Terraform tooling with
Open Policy Agent all let you require lifecycle policies on S3 buckets, but
creating objects directly in `INTELLIGENT_TIERING` makes lifecycle transition
rules unnecessary.

&#128161; I've devised **a practical way to enforce the storage class**...every
time an object is created...by any user...in one bucket or thousands. It's the
closest thing to changing S3's default storage class!

> &#128274; Software supply chain security is on everyone's mind. This solution
does not require executable code or dependencies. It creates a resource control
policy, which you can read before attaching anywhere. I've made GitHub releases
immutable as of `v1.0.1`&nbsp;. In case you do not want to execute a shell
script and/or use the AWS command-line interface for testing, I also explain
how to test manually in the AWS Console.

## How to Use It

### Strict Bucket Tag

`cost-s3-require-storage-class-intelligent-tiering` **&larr; Tag a new S3
bucket to require Intelligent Tiering** for all new objects. Attribute-based
access control must be enabled for the bucket.

Users who forget to add...

- `--storage-class INTELLIGENT_TIERING` when running `aws s3 cp` or
  `aws s3api put-object`
- `StorageClass="INTELLIGENT_TIERING"` when calling
  `client("s3").put_object()` in boto3 (or the equivalent in other AWS SDKs)
- `x-amz-storage-class: INTELLIGENT_TIERING` for the `PutObject` HTTP API
  operation

...get an "AccessDenied" error. In case a user missed
"require-storage-class"... in the bucket tag, the error message tells an
administrator where to look: "explicit deny in a resource control policy".

<details>
  <summary>See the full error message</summary>

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

`cost-s3-require-storage-class-intelligent-tiering-override-with-object-tag`
**&larr; Tag a new S3 bucket to require Intelligent Tiering but permit
overrides.** ABAC must be enabled for the bucket.

`cost-s3-override-storage-class-intelligent-tiering` **&larr; Tag an object to
create it in a different storage class.**

Add:

- `--tagging 'cost-s3-override-storage-class-intelligent-tiering='
   --storage-class STANDARD`<br/>when running `aws s3api put-object`
   (~`aws s3 cp`~ doesn't accept tags.)
- `Tagging="cost-s3-override-storage-class-intelligent-tiering=", StorageClass="STANDARD"`<br/>
  when calling `client("s3").put_object()` (or equivalent)
- `x-amz-tagging: cost-s3-override-storage-class-intelligent-tiering=`<br/>
  `x-amz-storage-class: STANDARD` (Encode `=` as `%3D` if your HTTP library
  doesn't.)

Change `STANDARD` to the storage class of your choice.

Jump to:
[Installation](#installation)
&bull;
[Advanced Topics](#advanced-topics)
&bull;
[Testing](#testing)

## How It Works

This CloudFormation or Terraform template is a practical solution to Cloud
Efficiency Hub report
[CER-0032 Delayed Transition of Objects to Intelligent-Tiering in an S3 Bucket](https://hub.pointfive.co/inefficiencies/delayed-transition-of-objects-to-intelligent-tiering-in-an-s3-bucket).

Just 40&nbsp;lines of JSON (two critical statements) in a resource control
policy suffice to deny `s3:PutObject` requests if the bucket has a particular
bucket tag and the requester has not set the required storage class (or the
required object tag, if overrides are permitted). It works thanks to AWS
features introduced in 2024 and 2025.

<details>
  <summary>AWS feature announcements that made it possible...</summary>

<br/>

 1. With attribute-based access control, S3 now checks bucket tags when
    authorizing requests. Users can _see_ the bucket tag, so they know the
    rules. A resource control policy won't break existing systems, because an
    existing bucket is excluded until it is tagged and its ABAC setting is
    enabled.

    November,&nbsp;2025:
    [Amazon S3 now supports attribute-based access control](https://aws.amazon.com/about-aws/whats-new/2025/11/amazon-s3-attribute-based-access-control)

 2. S3 errors now mention the type of policy. If users miss
    "require-storage-class"... in the bucket's tag, an administrator knows to
    check AWS&nbsp;Organizations because the error message mentions "a resource
    control policy".

    June,&nbsp;2025:
    [Amazon S3 extends additional context for HTTP 403 Access Denied error messages to AWS Organizations](https://aws.amazon.com/about-aws/whats-new/2025/06/amazon-s3-context-http-403-access-denied-error-message-aws-organizations)

    - &#129668; Wish list: Someday, S3 error messages might reveal the resource
      control policy's ARN. What a shame that AWS&nbsp;Organizations assigns an
      arbitrary resource identifier instead of letting me specify a meaningful
      one!
      `arn:aws:organizations::112233445566:policy/o-abcdefghij/resource_control_policy/p-abcdefghij`
      would be more specific than "a resource control policy", but still not
      self-explanatory. Dereferencing an RCP ARN requires substantial
      privileges.

      January,&nbsp;2026:
      [AWS introduces additional policy details to access denied error messages](https://aws.amazon.com/about-aws/whats-new/2026/01/additional-policy-details-access-denied-error)

 3. One resource control policy can cover all S3 buckets in one or more AWS
    accounts. It's no longer necessary to edit the bucket policy for each
    individual bucket and check for drift.

    November,&nbsp;2024:
    [Introducing resource control policies (RCPs) to centrally restrict access to AWS resources](https://aws.amazon.com/about-aws/whats-new/2024/11/resource-control-policies-restrict-access-aws-resources)

 4. The `s3:x-amz-storage-class` condition key makes it possible to restrict
    the storage class of new objects. At first, the available policy scopes
    were limited: a bucket policy affects only one bucket, and a named,
    customer-managed IAM policy can be attached to multiple roles, but only in
    one AWS account. Later, AWS launched AWS&nbsp;Organizations, introducing
    service control policies that can cover all roles in one or more accounts.
    Much later, AWS relaxed limitations on conditions in SCPs.

    February,&nbsp;2015:
    [AWS Identity and Access Management simplifies policy management](https://aws.amazon.com/about-aws/whats-new/2015/02/11/aws-identity-and-access-management-simplifies-policy-management)

    December,&nbsp;2015:
    [IAM policies now support an Amazon S3 s3:x-amz-storage-class condition key](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WhatsNew.html#WhatsNew-earlier-doc-history:~:text=IAM%20policies%20now%20support,condition%20key.)

    February,&nbsp;2017:
    [AWS Organizations Now Generally Available](https://aws.amazon.com/about-aws/whats-new/2017/02/aws-organizations-now-generally-available)

    September,&nbsp;2025:
    [AWS Organizations supports full IAM policy language for service control policies (SCPs)](https://aws.amazon.com/about-aws/whats-new/2025/09/aws-organizations-iam-language-service-control-policies)

    - To understand why not even SCPs provided a sufficient policy scope for
      this application, see
      [Differences between SCPs and RCPs](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_authorization_policies.html#understanding-scps-and-rcps).

</details>

## Installation

 1. Authenticate in your AWS&nbsp;Organizations management account. Choose a
    role with administrative privileges. Choose the region where you manage
    infrastructure-as-code templates that create non-regional resources.

 2. Review
    [AWS&nbsp;Organizations Settings](https://console.aws.amazon.com/organizations/v2/home/settings).
    Make sure that the
    [all features](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_org_support-all-features.html)
    feature set is enabled.

    Review
    [AWS&nbsp;Organizations Policies](https://console.aws.amazon.com/organizations/v2/home/policies).
    Make sure that the...

    - [resource control policy](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_rcps.html)
      and
    - [service control policy](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html)

    ...policy types are both enabled.

 3. Install using CloudFormation or Terraform.

    - **CloudFormation**<br/>_Easy_ &check;

      In the AWS Console,
      [create a CloudFormation stack](https://console.aws.amazon.com/cloudformation/home?#/stacks/create).

      Select "Upload a template file", then select "Choose file" and navigate
      to a locally-saved copy of
      [cloudformation/aws-rcp-s3-require-intelligent-tiering.yaml](/../../blob/v1.0.1/cloudformation/aws-rcp-s3-require-intelligent-tiering.yaml?raw=true)
      [right-click to save as...].

      On the next page, set:

      - Stack name: `S3RequireIntelligentTiering`
      - RCP root IDs, OU IDs, and/or AWS account ID numbers
        (&nbsp;`RcpTargetIds`&nbsp;):
        Enter the number of the account or the `ou-` ID of the organizational
        unit that you use for testing resource control policies.

    - **Terraform**

      Check that you have at least:

      - [Terraform v1.10.0 (2024-11-27)](https://github.com/hashicorp/terraform/releases/tag/v1.10.0)
      - [Terraform AWS provider v6.0.0 (2025-06-18)](https://github.com/hashicorp/terraform-provider-aws/releases/tag/v6.0.0)

      Add the following child module to your existing root module:

      ```terraform
      module "s3_require_intelligent_tiering" {
        source = "git::https://github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering.git//terraform?ref=v1.0.1"
        # Reference a specific version from github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering/releases
        # Check that the release is immutable!

        rcp_target_ids = ["112233445566", "ou-abcd-efghijkl",]
      }
      ```

      Populate the `rcp_target_ids` list with a string for the number of the
      account or the `ou-` ID of the organizational unit that you use for
      testing resource control policies.

      Have Terraform download the module's source code. Review the plan before
      typing `yes` to allow Terraform to proceed with applying the changes.

      ```shell
      terraform init
      terraform apply
      ```

 4. If you're an advanced user, see
    [Testing](#testing),
    below, for test scripts. After testing, return to Step&nbsp;10.

    Otherwise, continue for manual testing...

 5. Authenticate in your test AWS account or an account in your test
    organizational unit. (RCPs do not affect resources, such as S3 buckets,
    created in your AWS&nbsp;Organizations management account.) Choose a role
    with full S3 permissions.

 6. [Create](https://console.aws.amazon.com/s3/bucket/create)
    3&nbsp;"general purpose" S3 buckets. Apply tags from the left column of the
    table in Step&nbsp;8 as you create the buckets. Under "Tags - optional",
    click "Add new tag".

 7. In the list of
    [buckets](https://console.aws.amazon.com/s3/buckets),
    select each bucket in turn, open the "Properties" tab, and scroll down to
    "Bucket ABAC". Click "Edit" and **enable ABAC. The RCP won't work unless
    ABAC is enabled for the bucket**.

 8. Try to create 3&nbsp;objects in each of the 3&nbsp;buckets. Combinations
    marked &cross; should produce "AccessDenied".

    |**Step&nbsp;8: Create objects in these classes &rarr;**|Standard|Intelligent&nbsp;Tiering|Standard|
    |:---|:---:|:---:|:---:|
    |**Step&nbsp;8: Tag the objects &rarr;**|_No&nbsp;object&nbsp;tag_|_No&nbsp;object&nbsp;tag_|`cost-s3-override-storage-class-intelligent-tiering`|
    |**&darr; Step&nbsp;6: Tag the buckets**||||
    |_No bucket tag_|&check;|&check;|&check;|
    |`cost-s3-require-storage-class-intelligent-tiering`|&cross;|&check;|&cross;|
    |`cost-s3-require-storage-class-intelligent-tiering-override-with-object-tag`|&cross;|&check;|&check;|

    You do not need to install or use the AWS command-line interface to test.
    You can create objects in the AWS Console by selecting an S3 bucket and
    clicking "Upload". Scroll down to the "Properties" section to change the
    storage class or add an object tag.

    <details>
      <summary>Sample AWS CLI commands...</summary>

    <br/>

    Try
    [AWS CloudShell](https://console.aws.amazon.com/cloudshell/home)!
    The AWS CLI is pre-installed and there is no need to obtain credentials
    locally.

    ```shell
    cd /tmp
    echo 'Test data' > test.txt
    ```

    ```shell
    read -p 'Next S3 bucket: ' -e -r S3_BUCKET_NAME
    ```

    ```shell
    #
    # STANDARD untagged object
    aws s3 cp test.txt "s3://${S3_BUCKET_NAME}"
    #
    # INTELLIGENT_TIERING untagged object
    aws s3 cp test.txt "s3://${S3_BUCKET_NAME}" --storage-class INTELLIGENT_TIERING
    #
    # STANDARD tagged object
    aws s3api put-object --body test.txt --bucket "${S3_BUCKET_NAME}" --key test.txt --tagging 'cost-s3-override-storage-class-intelligent-tiering='
    #
    aws s3 rm "s3://${S3_BUCKET_NAME}/test.txt"

    ```

    </details>

 9. Delete the test buckets.

10. Add other AWS account numbers, `ou-` organizational unit IDs, or the `r-`
    root ID to apply the RCP broadly.

## Advanced Topics

### Semantics

- **Set the required storage class every time you overwrite an object** or you
  create a new version. If the bucket tag permits overrides and you want to
  override the required storage class, set the object tag when you overwrite an
  object or you create a new version.
- **The permissive bucket tag wins out** over the strict bucket tag. If a
  bucket has _both_ bucket tags, users _can_ override the required storage
  class by setting the object tag. This interpretation avoids contradicting
  what users can _see_: ..."override-with-object-tag" in one of the bucket's
  two tags.
- **You cannot apply the object tag to any bucket** with ABAC enabled.
  Applying the _object_ tag to a _bucket_ has no effect, and could lead to
  confusion. Apply the `cost-s3-override-storage-class-intelligent-tiering`
  object tag to new objects when you want to override the required storage
  class in a bucket tagged with the permissive bucket tag,
  `cost-s3-require-storage-class-intelligent-tiering-override-with-object-tag`&nbsp;.
- **Before disabling ABAC, you must remove the bucket tag.** Linking ABAC and
  bucket tags this way allows delegating permission to enable ABAC without
  necessarily delegating permission to _disable_ it. The optional
  [service control policy](#service-control-policy)
  for protecting bucket tags takes advantage of this feature. (The same
  [s3:PutBucketAbac](https://docs.aws.amazon.com/AmazonS3/latest/API/API_PutBucketAbac.html)
  API action serves to enable or disable ABAC, and there is no
  [condition key](https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazons3.html#amazons3-policy-keys)
  for checking a bucket's ABAC status, but a bucket tag condition passes only
  if ABAC is enabled.)

<details>
  <summary>Resource control policy technical details...</summary>

<br/>

- The RCP restricts only the _initial_ storage class. Lifecycle transition
  rules may later transition an object or object version to a different storage
  class.
  [S3 resource-based policies do not restrict lifecycle rules.](https://docs.aws.amazon.com/AmazonS3/latest/userguide/lifecycle-expire-general-considerations.html#:~:text=You%20can't%20use%20a%20bucket%20policy,S3%20Lifecycle%20rule.)
- The RCP works by denying certain `s3:PutObject` requests. It cannot _add_
  permissions that have been denied by another RCP or by an SCP, or that were
  never allowed by a role's attached or inline policies.
- RCPs do not affect resources, such as S3 buckets, in the
  AWS&nbsp;Organizations management account.

</details>

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
organizational units to prevent non-exempt roles from enabling or disabling
ABAC for any S3 bucket. The policy also prevents non-exempt roles from
adding/changing/removing the strict and permissive bucket tags, if ABAC is
enabled for the bucket. **The lack of such a control undermines the security of
most real-world ABAC applications.**

Test the SCP before applying it, because it generally reduces existing S3
permissions. Human users or automated processes might rely on those
permissions.

You will need at least one SCP-exempt role in every account, to manage S3
buckets. I recommend
[IAM Identity Center permission sets](https://docs.aws.amazon.com/singlesignon/latest/userguide/permissionsets.html).
You can customize `ScpPrincipalCondition` / `scp_principal_condition` to
[reference permission set roles](https://docs.aws.amazon.com/singlesignon/latest/userguide/referencingpermissionsets.html).

SCPs do not affect roles or other IAM principals in the AWS&nbsp;Organizations
management account.

The SCP offers two-way protection: Non-exempt roles can neither remove
restrictions from S3 buckets nor place new restrictions on them. For one-way
protection, that is, allowing non-exempt roles to enroll buckets but not to
disenroll them, allow `s3:TagResource` but deny removal of the strict and
permissive bucket tags. Thanks to the RCP, if the bucket tag can't be removed,
ABAC can't be disabled.

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

Requiring `INTELLIGENT_TIERING` is
[best for most S3 use cases](https://builder.aws.com/content/38nqWWauUbgfDsAzx2FpigrfAMv/intelligent-tiering-is-the-best-s3-storage-class-but-data-retrieval-is-not-free#:~:text=Heuristics),
but in buckets for seldom-accessed logs, you might require that all objects be
created in the `GLACIER_IR` storage class (low storage price, high retrieval
charge), or even in
[`DEEP_ARCHIVE`](https://builder.aws.com/content/38nzuuU92cmS7nEhDEZNrhjAtG5/save-more-on-s3-storage-by-implementing-asynchronous-retrieval)
(very low storage price, two-step asynchronous retrieval). Or, perhaps you have
some buckets whose objects are always frequently-accessed and short-lived, and
you want to be sure that objects can only be created in `STANDARD` class.

</details>

### Existing Buckets

<details details name="advanced-topics">
  <summary>Enroll existing buckets...</summary>

<br/>

> The options, decisions, and engineering actions for existing S3 buckets are
complex. The security and cost consequences are significant. If you need help,
please get in touch. This is part of what I do for a living.

Before applying either the strict or permissive bucket tag to an existing S3
bucket, be sure that all workflows have been updated to specify the required
storage class when creating objects. This is not possible for workflows you
don't control! For a bucket that is the destination of a replication rule,
[set the storage class in the replication rule](https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication-add-config.html#storage-class-configuration).

You must also remove existing lifecycle _transition_ rules if they would
[conflict](https://docs.aws.amazon.com/AmazonS3/latest/userguide/lifecycle-transition-general-considerations.html#lifecycle-general-considerations-transition-sc)
with the new initial storage class. For example, if you require that new
objects be created in the Intelligent Tiering storage class, do not then
transition them to other storage classes.

You may want to add lifecycle transition rules on a temporary basis, to move
existing objects to the storage class in which new objects will be created.

Other lifecycle rules, such as lifecycle _expiration_ rules, are fine.

After ABAC has been enabled for the bucket, calling the old S3 bucket tagging
methods will cause errors:

- ~GetBucketTagging~
- ~PutBucketTagging~

Before enabling ABAC for the bucket, make sure that all workflows and policies
have been updated to reference the new S3 tagging methods,

- [ListTagsForResource](https://docs.aws.amazon.com/AmazonS3/latest/API/API_control_ListTagsForResource.html)
- [TagResource](https://docs.aws.amazon.com/AmazonS3/latest/API/API_control_TagResource.html)
- [UntagResource](https://docs.aws.amazon.com/AmazonS3/latest/API/API_control_UntagResource.html)

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
is a secure and convenient alternative.

The IAM role you use for each test must:

- _not_ be in the AWS&nbsp;Organizations management account (RCPs do not apply
  to resources, such as S3 buckets, in the management account. SCPs do not
  apply to roles or other IAM principals in the management account.)
- have permission to:
  - create, tag, and delete S3 buckets
  - enable and disable attribute-based access control: `s3:PutBucketAbac`
  - create, tag, and delete S3 _objects_

The test scripts also call `sts:GetCallerIdentity`&nbsp;, which requires no
explicit permission.

</details>

### Resource Control Policy Test

<details name="test-scope">
  <summary>Test the RCP...</summary>

<br/>

In addition to the requirements in
[Test Setup](#test-setup),
above, the role you use for testing the **R**CP must:

- be in an AWS account subject to the **resource** control policy
- _not_ be in an account subject to the optional **service** control policy (If
  the **S**CP applies, then you must use an exempt role. See
  `ScpPrincipalCondition` / `scp_principal_condition`&nbsp;.)

Test the RCP by running:

```shell
cd /tmp
git clone --branch 'v1.0.1' --depth 1 --config 'advice.detachedHead=false' \
  'https://github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering.git'
cd aws-rcp-s3-require-intelligent-tiering/test
./00test-rcp-s3-require-intelligent-tiering.bash
```

</details>

### Service Control Policy Test

<details name="test-scope">
  <summary>Test the optional SCP...</summary>

<br/>

Testing the **S**CP requires two roles, one role that is exempt from the SCP
and another that is subject to it. Both roles must be in the same AWS account,
and they must meet the requirements in
[Test Setup](#test-setup),
above. Because the test process requires switching back and forth, steps below
that require the exempt role are marked _(SCP-exempt role)_.

The SCP test scripts default to using the AWS account number and the UTC date
to generate a unique S3 bucket name prefix. Because the scripts might be
executed in different environments, no information is passed between them. If
you complete SCP testing within the same UTC day, you will not have to enter a
non-default value when each script prompts you for the bucket name prefix.

To test the SCP,

 1. Assume the role that is exempt from the SCP.
 2. _(SCP-exempt role)_ Clone the repository and create the test S3 buckets.

    ```shell
    cd /tmp
    git clone --branch 'v1.0.1' --depth 1 --config 'advice.detachedHead=false' \
      'https://github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering.git'
    cd aws-rcp-s3-require-intelligent-tiering/test
    ./10test-scp-s3-bucket-restrict-tag-and-abac-changes.bash
    ```

 3. Assume the role that is subject to the SCP.
 4. If you are using CloudShell, clone the repository in the new file system.

    ```shell
    cd /tmp
    git clone --branch 'v1.0.1' --depth 1 --config 'advice.detachedHead=false' \
      'https://github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering.git'
    cd aws-rcp-s3-require-intelligent-tiering/test
    ```

 5. Confirm that you cannot enable ABAC on a bucket. The first test should
    produce an error, and the script should exit.

    ```shell
    ./12test-scp-s3-bucket-restrict-tag-and-abac-changes.bash
    ```

 6. Assume the role that is exempt from the SCP.
 7. _(SCP-exempt role)_ Enable ABAC for the test buckets.

    ```shell
    ./12test-scp-s3-bucket-restrict-tag-and-abac-changes.bash
    ```

 8. Assume the role that is subject to the SCP.

 9. Confirm that you cannot disable ABAC on a bucket. The first test should
    produce an error, and the script should exit.

    ```shell
    ./14test-scp-s3-bucket-restrict-tag-and-abac-changes.bash
    ```

10. In the list of
    [buckets](https://console.aws.amazon.com/s3/buckets),
    select the first test bucket. The test bucket name prefix is of the form:
    deletable-acct-_112233445566_-dt-_YYYY-MM-DD_ and the first test
    bucket's name ends in:

    - `-no-tags`

    Open the "Properties" tab and scroll down to "Tags".

11. Try to add any tags not already present:

    - `cost-s3-require-storage-class-intelligent-tiering`
    - `cost-s3-require-storage-class-intelligent-tiering-override-with-object-tag`

    Each attempt should produce an error.

12. Try to add an arbitrary tag. This should succeed.

13. Try to delete the arbitrary tag. This should succeed.

14. Try to delete one of these tags, if it is present:

    - `cost-s3-require-storage-class-intelligent-tiering`
    - `cost-s3-require-storage-class-intelligent-tiering-override-with-object-tag`

    This should produce an error.

15. Repeat Step&nbsp;10 through Step&nbsp;14 for the remaining test buckets.
    Their names end in:

    - `-tag`
    - `-override-tag`
    - `-both-tags`

16. Assume the role that is exempt from the SCP.
17. _(SCP-exempt role)_ Delete the test buckets.

    ```shell
    ./18test-scp-s3-bucket-restrict-tag-and-abac-changes.bash
    ```

Unfortunately, as of March,&nbsp;2026, the AWS CLI includes the old command for
tagging non-ABAC-enabled S3 buckets,
[`aws s3api put-bucket-tagging`](https://docs.aws.amazon.com/cli/latest/reference/s3api/put-bucket-tagging.html)&nbsp;,
but not the new command for tagging ABAC-enabled buckets.
[`aws resourcegroupstaggingapi tag-resources`](https://docs.aws.amazon.com/cli/latest/reference/resourcegroupstaggingapi/tag-resources.html)
also lacks support for ABAC-enabled S3 buckets. Hopefully,
~`aws s3api tag-resource`~ and ~`aws s3api untag-resource`~ commands will be
added to the CLI, saving the effort of writing and maintaining a program just
to call two AWS API methods during testing!

[`aws cloudcontrol update-resource`](https://docs.aws.amazon.com/cli/latest/reference/cloudcontrol/update-resource.html)
_can_ tag ABAC-enabled S3 buckets, but checking for completion of an
asynchronous operation is inconvenient in a shell script.

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
