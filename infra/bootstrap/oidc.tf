# Fetches GitHub's current TLS certificate chain so the OIDC provider's
# thumbprint is always correct, instead of hardcoding a value that could go
# stale if GitHub ever rotates their certificate authority.
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

# One-time, account-wide trust registration: "I trust ID tokens signed by
# GitHub Actions' OIDC issuer." Only one of these can exist per issuer URL
# per AWS account - this repo's account has none yet (confirmed before
# writing this), so it's created here rather than looked up via data source.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

# The trust policy is where the actual security boundary lives: it doesn't
# just trust "GitHub" in general, it only allows a workflow run whose OIDC
# token's `sub` claim matches this exact repo + branch to assume the role.
# A run from a fork, a different branch, or a different repo entirely is
# denied by AWS before this role's permissions even come into play.
data "aws_iam_policy_document" "github_oidc_trust" {
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

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${var.github_branch}"]
    }
  }
}

resource "aws_iam_role" "github_actions_ecr_push" {
  name               = "calendar-github-actions-ecr-push"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_trust.json
}

# Least-privilege: push-only permissions, scoped to just these two
# repositories - not ecr:* and not "Resource": "*" beyond the one action
# (GetAuthorizationToken) that AWS requires to be unscoped.
data "aws_iam_policy_document" "ecr_push" {
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = [
      aws_ecr_repository.backend.arn,
      aws_ecr_repository.frontend.arn,
    ]
  }
}

resource "aws_iam_policy" "ecr_push" {
  name   = "calendar-ecr-push"
  policy = data.aws_iam_policy_document.ecr_push.json
}

resource "aws_iam_role_policy_attachment" "ecr_push" {
  role       = aws_iam_role.github_actions_ecr_push.name
  policy_arn = aws_iam_policy.ecr_push.arn
}
