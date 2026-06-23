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
data "aws_iam_policy_document" "github_deploy_permissions" {
  statement {
    sid    = "TerraformState"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.terraform_state.arn,
      "${aws_s3_bucket.terraform_state.arn}/*",
    ]
  }

  statement {
    sid    = "TerraformLocking"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]
    resources = [aws_dynamodb_table.terraform_locks.arn]
  }

  statement {
    sid    = "SiteContent"
    effect = "Allow"
    actions = [
      "s3:*",
    ]
    resources = ["arn:aws:s3:::*"]
  }

  statement {
    sid    = "CloudFront"
    effect = "Allow"
    actions = [
      "cloudfront:*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "Route53"
    effect = "Allow"
    actions = [
      "route53:*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ACM"
    effect = "Allow"
    actions = [
      "acm:*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "LambdaApiGateway"
    effect = "Allow"
    actions = [
      "lambda:*",
      "apigateway:*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "SES"
    effect = "Allow"
    actions = [
      "ses:*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchSNS"
    effect = "Allow"
    actions = [
      "cloudwatch:*",
      "sns:*",
      "logs:*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "IAMForLambdaExecRole"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:PassRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:TagRole",
      "iam:GetOpenIDConnectProvider",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "${var.github_repo}-deploy-permissions"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy_permissions.json
}
