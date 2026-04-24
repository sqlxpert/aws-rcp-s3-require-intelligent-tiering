# Tag to Require S3 Intelligent Tiering

Still relying on lifecycle policies to transition S3 objects to Intelligent
Tiering? You're wasting money! Set the storage class in scripts or code to
avoid a transition charge and start the
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

>&#128274; Software supply chain security is on everyone's mind. This solution
does not require executable code or dependencies. It creates a resource control
policy, which you can read before attaching. I've made GitHub releases
immutable as of `v1.0.1`&nbsp;. In case you do not want to execute a shell
script and/or use the AWS command-line interface for testing, I also explain
how to test manually in the AWS Console.

## How to Use It

### Strict Bucket Tag

`cost-s3-require-storage-class-intelligent-tiering` **&larr; Tag a new S3
bucket to require Intelligent Tiering** for all new objects.
[Attribute-based access control](https://docs.aws.amazon.com/AmazonS3/latest/userguide/buckets-tagging-enable-abac.html)
must be enabled for the bucket.

Users who forget to...

|Add this option, parameter or header|To this command or API call|
|:---|:---|
|`--storage-class 'INTELLIGENT_TIERING'`|`aws s3 cp` or<br/>`aws s3api put-object`|
|`StorageClass="INTELLIGENT_TIERING"`|`client("s3").put_object()` in boto3<br/>or the equivalent in other AWS SDKs|
|`x-amz-storage-class: INTELLIGENT_TIERING`|`PutObject`|

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

|Command or API method|Options, parameters or headers to add|
|:---|:---|
|`aws s3api put-object`|`--tagging 'cost-s3-override-storage-class-intelligent-tiering='`|
||`--storage-class 'STANDARD'`|
|`client("s3").put_object()`<br/>or equivalent|`Tagging="cost-s3-override-storage-class-intelligent-tiering="`|
||`StorageClass="STANDARD"`|
|`PutObject`|`x-amz-tagging: cost-s3-override-storage-class-intelligent-tiering=`|
||`x-amz-storage-class: STANDARD`|

- Change `STANDARD` to the storage class of your choice.
- If `STANDARD` _is_ your choice, you can omit the storage class option,
  parameter, or header.
- Encode `=` as `%3D` in the `PutObject` header value, if your HTTP library
  doesn't.
- ~`aws s3 cp`~ does not support setting S3 object tags.

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

Just 41&nbsp;lines of JSON (two critical statements) in a resource control
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
      [cloudformation/aws-rcp-s3-require-intelligent-tiering.yaml](/../../blob/v1.1.0/cloudformation/aws-rcp-s3-require-intelligent-tiering.yaml?raw=true)
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
        source = "git::https://github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering.git//terraform?ref=v1.1.0"
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
    below, for the resource control policy test script.

    Otherwise, continue for manual testing...

 5. Authenticate in your test AWS account or an account in your test
    organizational unit. (RCPs do not affect resources, such as S3 buckets,
    created in your AWS&nbsp;Organizations management account.) Choose a role
    with full S3 permissions.

 6. [Create](https://console.aws.amazon.com/s3/bucket/create)
    3&nbsp;"general purpose" S3 buckets. During creation, tag each bucket as
    indicated. Under "Tags - optional", click "Add new tag".

    ||Bucket tag|
    |:---:|:---|
    |1|_No bucket tag_|
    |2|`cost-s3-require-storage-class-intelligent-tiering`|
    |3|`cost-s3-require-storage-class-intelligent-tiering-override-with-object-tag`|

 7. In the list of
    [buckets](https://console.aws.amazon.com/s3/buckets),
    select each bucket in turn, open the "Properties" tab, and scroll down to
    "Bucket ABAC". Click "Edit" and **enable ABAC. The RCP won't work unless
    ABAC is enabled for the bucket**.

 8. Try to create 3&nbsp;objects in each of the 3&nbsp;buckets. During
    creation, tag the objects as indicated.

    ||Create objects in these classes &rarr;|Standard|Intelligent&nbsp;Tiering|Standard|
    |:---:|:---|:---:|:---:|:---:|
    ||**During creation, tag the objects &rarr;**|_No&nbsp;object&nbsp;tag_|_No&nbsp;object&nbsp;tag_|`cost-s3-override-storage-class-intelligent-tiering`|
    ||**Bucket tag**|**Result<br/>&darr;**|**Result<br/>&darr;**|**Result<br/>&darr;**|
    |1|_No bucket tag_|&check;|&check;|&check;|
    |2|`cost-s3-require-storage-class-intelligent-tiering`|AccessDenied|&check;|AccessDenied|
    |3|`cost-s3-require-storage-class-intelligent-tiering-override-with-object-tag`|AccessDenied|&check;|&check;|

    You do not need to install or use the AWS command-line interface to test.
    You can create objects in the AWS Console by selecting an S3 bucket and
    clicking "Upload". Scroll down to the "Properties" section to change the
    storage class or add an object tag.

    <details>
      <summary>Sample AWS CLI commands...</summary>

    <br/>

    I recommend using
    [AWS CloudShell](https://console.aws.amazon.com/cloudshell/home).
    The AWS CLI is pre-installed, AWS keeps it up-to-date for you, and there is
    no need to obtain AWS credentials, whether long- or hopefully short-lived,
    on your local computer.

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

10. <a id="install-step-10"></a>Add other AWS account numbers, `ou-`
    organizational unit IDs, or the `r-` root ID to apply the RCP broadly.

## Advanced Topics

### Semantics

- **Set the required storage class every time that you overwrite an object** or
  that you create a new version. If the bucket tag permits overrides and you
  want to override the required storage class, set the object tag every time
  that you overwrite an object or that you create a new version.
- **The permissive bucket tag wins out** over the strict bucket tag. If a
  bucket has _both_ bucket tags, users _can_ override the required storage
  class by setting the object tag. This interpretation avoids contradicting
  what users _see_: ..."override-with-object-tag" in one of the two bucket
  tags.
- **You cannot apply the object tag to any bucket** with ABAC enabled.
  Applying the _object_ tag to a _bucket_ has no effect, and could lead to
  confusion. Apply the `cost-s3-override-storage-class-intelligent-tiering`
  object tag to new objects when you want to override the required storage
  class in a bucket tagged with the permissive bucket tag,
  `cost-s3-require-storage-class-intelligent-tiering-override-with-object-tag`&nbsp;.
- **Before disabling ABAC, you must remove the bucket tag.** Linking ABAC and
  bucket tags this way allows delegating permission to enable ABAC without
  necessarily delegating permission to _disable_ it. The section for the
  optional
  [service control policy](#service-control-policy)
  for protecting bucket tags explains how to take advantage of this feature.
  (The same
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

>I'm not the only AWS security expert who favors tag key prefixes and, where
feasible, encoding information in tag keys rather than in tag values. See
"[Locking down AWS principal tags with RCPs and SCPs](https://awsteele.com/blog/2026/02/21/locking-down-aws-principal-tags-with-rcps-and-scps.html#:~:text=I%20prefer%20to%20lock%20down%20a%20tag%20key,per%20%22use%20case%22)",
_Aidan Steele's blog_, 2026-02-21.
>
>My follow-on S3 RCP,
[github.com/sqlxpert/**aws-rcp-s3-require-encryption-kms**](https://github.com/sqlxpert/aws-rcp-s3-require-encryption-kms)&nbsp;,
does keep KMS encryption key identifiers in tag values, but the set of S3
storage class strings is small, and the set of worthwhile ones, even smaller.
Most users of the present RCP will only ever need S3 bucket tag keys for
`INTELLIGENT_TIERING`&nbsp;, `STANDARD`&nbsp;, `GLACIER_IR`&nbsp;, and
`DEEP_ARCHIVE`&nbsp;.
[Other S3 storage classes are of little benefit.](https://builder.aws.com/content/38nqWWauUbgfDsAzx2FpigrfAMv/intelligent-tiering-is-the-best-s3-storage-class-but-data-retrieval-is-not-free#:~:text=Heuristics)
Encoding the storage class in the tag key removes any uncertainty on the part
of the end-user about what the tag value should be. There's less need for usage
documentation, which tends not reach _end_-users anyway, or for validation and
branching, which requires
[quite a lot of extra IAM policy code](https://github.com/sqlxpert/aws-rcp-s3-require-encryption-kms/blob/3261eb8/cloudformation/aws-rcp-s3-require-encryption-kms.yaml#L329-L399).
Editing parameter values and creating a second stack from the same template is
much less error-prone than extending an IAM policy.

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
a bucket whose objects are always frequently-accessed and short-lived, and you
want to be sure they can only be created in `STANDARD` class.

</details>

### Existing Buckets

<details details name="advanced-topics">
  <summary>Enroll existing buckets...</summary>

<br/>

>The options, decisions, and engineering actions for existing S3 buckets are
complex. The security and cost consequences are significant. If you need help,
please get in touch. This is part of what I do for a living.

#### Specify the Storage Class in Code

Before applying either the strict or permissive bucket tag to an existing S3
bucket, be sure that all workflows have been updated to specify the required
storage class when creating objects. This is not possible for workflows you
don't control!

For a bucket that is the destination of a replication rule,
[set the storage class in the replication rule](https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication-add-config.html#storage-class-configuration).

#### Retire Lifecycle Transition Rules

You must also remove existing lifecycle _transition_ rules if they would
[conflict](https://docs.aws.amazon.com/AmazonS3/latest/userguide/lifecycle-transition-general-considerations.html#lifecycle-general-considerations-transition-sc)
with the new initial storage class. For example, if you require that new
objects be created in the Intelligent Tiering storage class, do not then
transition them to other storage classes.

You may want to add lifecycle transition rules on a temporary basis, to move
existing objects to the storage class in which new objects will be created.

Other lifecycle rules, such as lifecycle _expiration_ rules, are fine.

#### Update Bucket Tagging Policies and Code

After ABAC has been enabled for the bucket, calling the old S3 bucket tagging
methods will cause errors:

- ~PutBucketTagging~
- ~DeleteBucketTagging~

Make sure that all policies and workflows have been updated to reference the
new S3 tagging methods,

- [`TagResource`](https://docs.aws.amazon.com/AmazonS3/latest/API/API_control_TagResource.html)
- [`UntagResource`](https://docs.aws.amazon.com/AmazonS3/latest/API/API_control_UntagResource.html) (To delete a tag, you must now list its tag key
  explicitly.)
- Optional:
  [`ListTagsForResource`](https://docs.aws.amazon.com/AmazonS3/latest/API/API_control_ListTagsForResource.html)
  (GetBucketTagging will still work.)

`s3control` is the service for the new methods, but `s3:` remains the service
prefix in policies.

Replace `*` (if you used it) with
[`arn:aws:s3:::*`](https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazons3.html#amazons3-bucket)
to write tags on buckets only. The new methods cover other resource types, but
not objects _in_ buckets, so the `*` wildcard at the end of the bucket ARN
pattern will not add ambiguity. (Change `aws` if your partition differs.)

If the resource in a policy statement is an S3 bucket, the following
[condition keys](https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazons3.html#amazons3-policy-keys)
become available when ABAC is enabled. Check for pre-existing references and
know the consequences!

|From the request|From the resource|
|:---:|:---:|
|`aws:RequestTag/`_TAG_KEY_|`s3:BucketTag/`_TAG_KEY_<br/> `aws:ResourceTag/`_TAG_KEY_|
|`aws:TagKeys`||

</details>

## Testing

### Resource Control Policy Test

<details name="test-scope">
  <summary>Test the RCP...</summary>

<br/>

The test script assumes that you have already run:

- [`aws configure`](https://docs.aws.amazon.com/cli/latest/reference/configure)
  or
  [`aws configure sso`](https://docs.aws.amazon.com/cli/latest/reference/configure/sso.html)
- [`aws login`](https://docs.aws.amazon.com/signin/latest/userguide/command-line-sign-in.html#command-line-sign-in-local-development)
  or
  [`aws sso login`](https://docs.aws.amazon.com/signin/latest/userguide/command-line-sign-in.html#command-line-sign-in-sso)

I recommend using
[AWS CloudShell](https://console.aws.amazon.com/cloudshell/home)
as an alternative. The AWS CLI is pre-installed, AWS keeps it up-to-date for
you, and there is no need to obtain AWS credentials, whether long- or hopefully
short-lived, on your local computer.

The IAM role you use must:

- _not_ be in the AWS&nbsp;Organizations management account (RCPs do not apply
  to resources, such as S3 buckets, in the management account.)
- be in an AWS account subject to the **resource** control policy
- _not_ be in an account subject to the optional **service** control policy (If
  the **S**CP applies, then you must use an exempt role. See
  `ScpPrincipalCondition` / `scp_principal_condition`&nbsp;.)
- have permission to:
  - create, tag, and delete S3 buckets
  - enable and disable attribute-based access control: `s3:PutBucketAbac`
  - create, tag, and delete S3 _objects_

The test scripts also call `sts:GetCallerIdentity`&nbsp;, which requires no
explicit permission.

Test the RCP by running:

```shell
cd /tmp
git clone --branch 'v1.1.0' --depth 1 --config 'advice.detachedHead=false' \
  'https://github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering.git'
cd aws-rcp-s3-require-intelligent-tiering/test
./test-s3-storage-class-tag-rcp.bash
```

After testing, return to
[Step&nbsp;10](#install-step-10)
of the installation instructions.

</details>

### Service Control Policy Test

<details name="test-scope">
  <summary>Test the optional SCP...</summary>

<br/>

 1. Choose an AWS account number for testing. The AWS account must be **subject
    to the RCP and the SCP.** (RCPs never affect resources in your
    AWS&nbsp;Organizations management account.)

 2. Before creating the **S**CP test CloudFormation stack, temporarily detach
    the **S**CP from the AWS account in which the stack will be created. Make
    this change in your AWS&nbsp;Organizations management account.

 3. Authenticate to the AWS Console, in the test AWS account. Choose a role
    with full S3 permissions.

 4. [Create a CloudFormation stack](https://console.aws.amazon.com/cloudformation/home?#/stacks/create)
    from
    [test/test-scp-protect-s3-storage-class-tag.yaml](/../../blob/v1.1.0/test/test-scp-protect-s3-storage-class-tag.yaml?raw=true)&nbsp;.

    - Copy and paste the **suggested stack name. Do not change it.** Creating
      more than one stack from this template is not supported.
    - Because this is for temporary use during testing, I do not provide a
      Terraform alternative.
    - Trouble creating the stack usually signals a local permissions problem,
      such as insufficient permissions attached to your IAM role, or the effect
      of a hidden policy such as a permissions boundary or a service control
      policy. For example, make sure that the AWS account number is not subject
      to the optional SCP, or that your role is exempt from the SCP. If you
      cannot resolve the problem, check with your local AWS administrator.

 5. Optional: If you are an advanced user, you can re-attach the **S**CP after
    creating the SCP test CloudFormation stack but before testing. For the
    first round of testing, exempt
    `TestScpProtectS3StorageClassTag-TesterLambdaFnRole` from the SCP by
    customizing `ScpPrincipalCondition` / `scp_principal_condition` in the main
    CloudFormation stack or Terraform module. Make these changes in your
    AWS&nbsp;Organizations management account.

 6. Open the
    [TestDirector](https://console.aws.amazon.com/lambda/home#/functions/TestScpProtectS3StorageClassTagTestDirector?tab=testing)
    Lambda function's "Test" tab and click the orange "Test" button.

    - The "Event JSON" value will be ignored.

 7. Open the "All events" search page for the
    [Test](https://console.aws.amazon.com/cloudwatch/home#logsV2:log-groups/log-group/TestScpProtectS3StorageClassTag/log-events)
    CloudWatch log group, and filter for `error`&nbsp;. Review any errors.

    - Uncaught exceptions are unexpected, and usually signal local permission
      problems.
    - Service control policy tests cover a set of 4 numbered S3 buckets with
      various ABAC and bucket tag combinations. Each test result is a JSON
      object.
    - Useful
      [CloudWatch Logs filter patterns](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html#matching-terms-events):

      |Filter Pattern|Scope|
      |:---:|:---|
      |`error`|All errors|
      |`timeout`|Lambda function timeouts (unlikely)|
      |`%TEST-\d+%`|All tests|
      |`"TEST-3."`|Tests on S3 bucket&nbsp;3 (for example)|
      |`%TEST-\d+\.[0-4]%`|Tests that tag buckets|
      |`%TEST-\d+\.[5-7]%`|Tests that change the ABAC setting|

 8. To prepare to re-test, open the list of log streams in the
    [Test](https://console.aws.amazon.com/cloudwatch/home#logsV2:log-groups/log-group/TestRcpS3EncryptionTag)
    log group, check the topmost checkbox to select all of the log streams,
    then click "Delete".

    - If there were timeouts or errors, check the
      [Test](https://console.aws.amazon.com/cloudwatch/home#logsV2:log-groups/log-group/TestScpProtectS3StorageClassTag)
      CloudFormation stack for drift and correct any drift before re-testing
      ("Stack actions" &rarr; "Detect drift", then "Stack actions" &rarr;
      "View drift results").

 9. After testing _without_ the SCP, you must re-test _with_ the SCP.

10. Re-attach the **S**CP to the AWS account containing the CloudFormation
    stack. (Advanced users, revert to the default `ScpPrincipalCondition` /
    `scp_principal_condition` value, in the main CloudFormation stack or
    Terraform module.) Make this change in your AWS&nbsp;Organizations
    management account.

11. Update the SCP test CloudFormation stack, changing `ScpOn` to `true`&nbsp;.

12. Return to Step&nbsp;3 of these SCP testing instructions.

13. When you are finished, delete the
    [Test](https://console.aws.amazon.com/cloudformation/home#/stacks?filteringText=TestScpProtectS3StorageClassTag&filteringStatus=active&viewNested=true)
    CloudFormation stack.

    - If there was an unexpected error, you might first have to delete all
      objects from the S3 buckets listed in the stack's "Resources" tab.

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
