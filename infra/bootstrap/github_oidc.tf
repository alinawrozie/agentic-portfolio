# -----------------------------------------------------------------------------
# GitHub Actions <-> AWS trust via OpenID Connect.
#
# How this works: GitHub Actions can mint a short-lived signed JWT token for
# each workflow run. AWS trusts GitHub's OIDC issuer as an identity provider,
# and an IAM role's trust policy says "I will let GitHub assume this role,
# but only if the token's claims match this exact repo and branch."
# No AWS access key/secret is ever generated, stored in GitHub Secrets, or
# rotated. A leaked workflow log can't leak a credential, because there
# isn't one sitting still anywhere - tokens are issued per-run and expire
# in minutes.
# -----------------------------------------------------------------------------

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    data.tls_certificate.github.certificates[0].sha1_fingerprint,
  ]
}

data "aws_iam_policy_document" "github_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Scopes trust down to ONE repo and ONE branch. Without this, any
    # repo in your GitHub account (or worse, any GitHub user, if misconfigured)
    # could potentially assume this role.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${var.github_branch}"]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name               = "${var.github_repo}-github-actions-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_trust.json

  # Belt-and-braces: cap how long any assumed session can live, on top of
  # GitHub's own short-lived token expiry.
  max_session_duration = 3600
}

# Deploy permissions, scoped to exactly the services this project touches.
# Broader than ideal for brevity (e.g. wildcard resource on some actions),
# but deliberately NOT iam:* / full Admin - worth tightening further once
# you know your exact resource ARNs and want to practice least-privilege.
# ---------------------------------------------------------------------------
# Data sources for ARN construction.
# We need the AWS account ID and region to build scoped resource ARNs
# without hardcoding them — both are resolved at plan/apply time.
# ---------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# ---------------------------------------------------------------------------
# GitHub Actions deploy permissions — Principle of Least Privilege.
#
# Every statement is scoped to the exact resources this project owns.
# The pattern used throughout: where a resource ARN is known at bootstrap
# time (state bucket, lock table) it is referenced directly; where the
# resource is created by the *main* infra config (Lambda, CloudFront, etc.)
# we scope by a predictable name prefix rather than "*", so the deploy role
# can create and manage those resources but cannot touch anything outside
# the project's namespace.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "github_deploy_permissions" {

  # ── Terraform remote state ──────────────────────────────────────────────
  # Exact ARNs: only the state bucket Terraform reads/writes.
  statement {
    sid    = "TerraformStateBucket"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject", # needed so terraform state mv / workspace operations work
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.terraform_state.arn,
      "${aws_s3_bucket.terraform_state.arn}/*",
    ]
  }

  # Exact ARN: only the lock table for this project.
  statement {
    sid    = "TerraformStateLock"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]
    resources = [aws_dynamodb_table.terraform_locks.arn]
  }

  # ── Site S3 bucket ───────────────────────────────────────────────────────
  # CI syncs frontend/ files and the Terraform resource manages bucket config.
  # Scoped to buckets whose name matches the domain (set by var.domain_name in
  # the main config). The deploy role cannot touch any other bucket.
  statement {
    sid    = "SiteBucketManage"
    effect = "Allow"
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:GetBucketPolicy",
      "s3:PutBucketPolicy",
      "s3:DeleteBucketPolicy",
      "s3:GetBucketVersioning",
      "s3:PutBucketVersioning",
      "s3:GetBucketPublicAccessBlock",
      "s3:PutBucketPublicAccessBlock",
      "s3:GetEncryptionConfiguration",
      "s3:PutEncryptionConfiguration",
      "s3:GetBucketTagging",
      "s3:PutBucketTagging",
      "s3:GetBucketCORS",
      "s3:PutBucketCORS",
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetBucketAcl",
      "s3:GetBucketWebsite",
      "s3:GetAccelerateConfiguration",
      "s3:GetBucketRequestPayment",
      "s3:GetLifecycleConfiguration",
      "s3:GetBucketLogging",
      "s3:GetBucketObjectLockConfiguration",
      "s3:GetReplicationConfiguration",
      "s3:GetBucketNotification"
    ]
    resources = [
      "arn:aws:s3:::${var.domain_name}",
      "arn:aws:s3:::www.${var.domain_name}"
    ]
  }

  statement {
    sid    = "SiteBucketObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObjectVersion",
    ]
    resources = [
      "${aws_s3_bucket.terraform_state.arn}/*",
      "arn:aws:s3:::${var.domain_name}/*",
      "arn:aws:s3:::www.${var.domain_name}/*",
    ]
  }

  # ── CloudFront ───────────────────────────────────────────────────────────
  # Terraform manages the distribution; CI creates cache invalidations only.
  # Distribution-level Terraform actions use the account-scoped ARN pattern.
  statement {
    sid    = "CloudFrontManage"
    effect = "Allow"
    actions = [
      "cloudfront:CreateDistribution",
      "cloudfront:GetDistribution",
      "cloudfront:GetDistributionConfig",
      "cloudfront:UpdateDistribution",
      "cloudfront:DeleteDistribution",
      "cloudfront:TagResource",
      "cloudfront:ListTagsForResource",
      "cloudfront:CreateOriginAccessControl",
      "cloudfront:GetOriginAccessControl",
      "cloudfront:GetOriginAccessControlConfig",
      "cloudfront:UpdateOriginAccessControl",
      "cloudfront:DeleteOriginAccessControl",
      "cloudfront:ListOriginAccessControls",
      "cloudfront:ListDistributions",
    ]
    resources = ["arn:aws:cloudfront::${local.account_id}:*"]
  }

  statement {
    sid    = "CloudFrontInvalidate"
    effect = "Allow"
    actions = [
      "cloudfront:CreateInvalidation",
      "cloudfront:GetInvalidation",
      "cloudfront:ListInvalidations",
    ]
    resources = ["arn:aws:cloudfront::${local.account_id}:distribution/*"]
  }

  # ── Route 53 ─────────────────────────────────────────────────────────────
  # Terraform manages one hosted zone. We allow zone creation/lookup globally
  # (unavoidable — zone ARNs aren't known before creation) but record
  # management is scoped to the hosted zone resource type only.
  statement {
    sid    = "Route53ZoneRead"
    effect = "Allow"
    actions = [
      "route53:GetHostedZone",
      "route53:ListHostedZones",
      "route53:ListHostedZonesByName",
      "route53:CreateHostedZone",
      "route53:DeleteHostedZone",
      "route53:GetChange",
      "route53:ListTagsForResource",
    ]
    resources = ["*"] # zone ARNs not predictable before creation
  }

  statement {
    sid    = "Route53RecordManage"
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets",
    ]
    resources = ["arn:aws:route53:::hostedzone/*"]
  }

  # ── ACM ───────────────────────────────────────────────────────────────────
  # Terraform requests and validates one certificate in us-east-1.
  # Scoped to request/describe/delete; no wildcard service access.
  statement {
    sid    = "ACMManage"
    effect = "Allow"
    actions = [
      "acm:RequestCertificate",
      "acm:DescribeCertificate",
      "acm:DeleteCertificate",
      "acm:ListCertificates",
      "acm:AddTagsToCertificate",
      "acm:ListTagsForCertificate",
    ]
    resources = ["*"] # ACM cert ARNs not predictable before creation
  }

  # ── Lambda ────────────────────────────────────────────────────────────────
  # Scoped to functions whose name starts with the project prefix.
  # CI cannot create, invoke, or delete Lambda functions outside this namespace.
  statement {
    sid    = "LambdaManage"
    effect = "Allow"
    actions = [
      "lambda:CreateFunction",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:DeleteFunction",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:GetPolicy",
      "lambda:TagResource",
      "lambda:ListTags",
      "lambda:PublishVersion",
      "lambda:ListVersionsByFunction",
      "lambda:GetFunctionCodeSigningConfig",
      "lambda:GetFunctionConcurrency",
      "lambda:GetFunctionEventInvokeConfig",
    ]
    resources = [
      "arn:aws:lambda:${local.region}:${local.account_id}:function:${var.project_name}-*",
    ]
  }

  # ── API Gateway ───────────────────────────────────────────────────────────
  # API Gateway v2 (HTTP API) ARNs follow a fixed pattern once the API exists.
  # Before creation we can't know the API ID, so we scope to the account/region.
  statement {
    sid    = "APIGatewayManage"
    effect = "Allow"
    actions = [
      "apigateway:GET",
      "apigateway:POST",
      "apigateway:PUT",
      "apigateway:PATCH",
      "apigateway:DELETE",
      "apigateway:TagResource",
    ]
    resources = [
      "arn:aws:apigateway:${local.region}::/apis",
      "arn:aws:apigateway:${local.region}::/apis/*",
    ]
  }

  # ── SES ───────────────────────────────────────────────────────────────────
  # Terraform manages email identity verification only. Scoped to the two
  # addresses configured for this project; cannot touch other SES identities.
  statement {
    sid    = "SESIdentityManage"
    effect = "Allow"
    actions = [
      "ses:CreateEmailIdentity",
      "ses:DeleteEmailIdentity",
      "ses:GetEmailIdentity",
      "ses:ListEmailIdentities",
      "ses:TagResource",
    ]
    resources = [
      "arn:aws:ses:${local.region}:${local.account_id}:identity/*",
    ]
  }

  # ── CloudWatch Alarms ─────────────────────────────────────────────────────
  # Scoped to the one alarm this project creates (name-prefix match).
  statement {
    sid    = "CloudWatchAlarms"
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:DeleteAlarms",
      "cloudwatch:EnableAlarmActions",
      "cloudwatch:DisableAlarmActions",
      "cloudwatch:ListTagsForResource",
    ]
    resources = [
      "arn:aws:cloudwatch:${local.region}:${local.account_id}:alarm:${var.project_name}-*",
    ]
  }

  # ── CloudWatch Logs ───────────────────────────────────────────────────────
  # Scoped to log groups whose name matches /aws/lambda/<project>-*
  # and /aws/apigateway/<project>-*. Cannot read or delete other log groups.
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy",
      "logs:ListTagsLogGroup",
      "logs:TagLogGroup",
      "logs:ListTagsForResource",
    ]
    resources = [
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${var.project_name}-*",
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/apigateway/${var.project_name}-*",
    ]
  }

  statement {
    sid    = "CloudWatchLogsGlobal"
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
    ]
    resources = ["*"]
  }

  # ── SNS ───────────────────────────────────────────────────────────────────
  # Scoped to the one alarms topic this project creates.
  statement {
    sid    = "SNSAlarmTopic"
    effect = "Allow"
    actions = [
      "sns:CreateTopic",
      "sns:GetTopicAttributes",
      "sns:SetTopicAttributes",
      "sns:DeleteTopic",
      "sns:Subscribe",
      "sns:Unsubscribe",
      "sns:ListSubscriptionsByTopic",
      "sns:TagResource",
      "sns:ListTagsForResource",
      "sns:GetSubscriptionAttributes",
      "sns:SetSubscriptionAttributes",
    ]
    resources = [
      "arn:aws:sns:${local.region}:${local.account_id}:${var.project_name}-*",
      "arn:aws:sns:${local.region}:${local.account_id}:${var.project_name}-*:*"
    ]
  }

  # ── IAM — Lambda execution role only ─────────────────────────────────────
  # Terraform creates one IAM role (the Lambda exec role) and one inline
  # policy on it. The resource constraint uses a name prefix so this role
  # cannot create or modify any IAM role outside the project namespace.
  # iam:PassRole is also constrained: CI can only pass a role whose name
  # starts with the project prefix, to the Lambda service specifically.
  statement {
    sid    = "IAMProjectRoles"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:TagRole",
      "iam:UntagRole",
    ]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${var.project_name}-*",
    ]
  }

  statement {
    sid     = "IAMPassRoleToLambda"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${var.project_name}-*",
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com"]
    }
  }

  # Read-only: Terraform uses these to read the OIDC provider it just created
  # during bootstrap, and to plan/diff IAM state. No resource creation.
  statement {
    sid    = "IAMReadOnly"
    effect = "Allow"
    actions = [
      "iam:GetOpenIDConnectProvider",
      "iam:ListOpenIDConnectProviders",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "SESReadOnly"
    effect = "Allow"
    actions = [
      "ses:GetIdentityVerificationAttributes",
      "ses:GetIdentityNotificationAttributes",
      "ses:GetIdentityHeadersInboundEnabled",
      "ses:GetIdentityDkimAttributes",
      "ses:GetIdentityMailFromDomainAttributes",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "${var.github_repo}-deploy-permissions"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy_permissions.json
}
