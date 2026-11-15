# Bootstrap: the only layer applied by hand (once), from a laptop, with the
# `personal` AWS profile. It creates what CI needs in order to run everything
# else: remote state, GitHub OIDC trust (no stored AWS keys), two scoped roles,
# and a spend alarm.
#
# Account guard: allowed_account_ids makes the AWS provider refuse to run
# against any account other than the expected personal one.

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region              = var.region
  profile             = var.aws_profile
  allowed_account_ids = [var.expected_account_id]

  default_tags {
    tags = {
      Project   = "z2h-demo-infra"
      ManagedBy = "terraform"
      Owner     = "zero2heroai"
      Layer     = "bootstrap"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  state_bucket = "z2h-demo-tfstate-${local.account_id}"

  # OIDC subject claims GitHub will present.
  plan_subjects = ["repo:${var.github_repo}:pull_request"]
  apply_subjects = [
    "repo:${var.github_repo}:environment:demo",        # manual approval required
    "repo:${var.github_repo}:environment:demo-reaper", # nightly teardown, no approver
  ]
}

# ---------------------------------------------------------------- state bucket

resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ------------------------------------------------------------- GitHub OIDC trust

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "plan_trust" {
  statement {
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
      values   = local.plan_subjects
    }
  }
}

data "aws_iam_policy_document" "apply_trust" {
  statement {
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
      values   = local.apply_subjects
    }
  }
}

# ------------------------------------------------------------------ plan role
# Narrow, read-only. Used on pull requests. Cannot change anything and,
# deliberately, cannot read application data (no DynamoDB, no S3 objects other
# than the Terraform state, no Secrets Manager, no SES). It only sees what a
# `terraform plan` of the demo stacks needs: Bedrock agent metadata, the
# z2h-demo-* IAM roles, and the state file.

resource "aws_iam_role" "plan" {
  name                 = "z2h-demo-gha-plan"
  assume_role_policy   = data.aws_iam_policy_document.plan_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "plan" {
  statement {
    sid       = "StateBucketList"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }
  statement {
    sid       = "StateObjectRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.state.arn}/*"]
  }
  statement {
    sid = "BedrockMetadataRead"
    actions = [
      "bedrock:GetAgent",
      "bedrock:GetAgentAlias",
      "bedrock:ListAgents",
      "bedrock:ListAgentAliases",
      "bedrock:ListAgentVersions",
      "bedrock:GetAgentVersion",
      "bedrock:ListTagsForResource",
      "bedrock:GetFoundationModel",
      "bedrock:GetInferenceProfile",
    ]
    resources = ["*"]
  }
  statement {
    sid = "DemoRoleRead"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/z2h-demo-*"]
  }
}

resource "aws_iam_role_policy" "plan" {
  name   = "plan-read"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan.json
}

# ----------------------------------------------------------------- apply role
# Scoped to what the demos create. Tighten further after the first real run
# using CloudTrail / IAM Access Analyzer policy generation.

data "aws_iam_policy_document" "apply" {
  statement {
    sid       = "StateBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }
  statement {
    sid       = "StateObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/*"]
  }
  statement {
    sid = "BedrockAgents"
    actions = [
      "bedrock:*Agent*",
      "bedrock:TagResource",
      "bedrock:UntagResource",
      "bedrock:ListTagsForResource",
      "bedrock:GetFoundationModel",
      "bedrock:GetInferenceProfile",
      "bedrock:ListFoundationModels",
    ]
    resources = ["*"]
  }
  statement {
    sid = "DemoRolesOnly"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:TagRole", "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy",
      "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/z2h-demo-*"]
  }
  statement {
    sid       = "PassOnlyToBedrock"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/z2h-demo-*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["bedrock.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "apply" {
  name                 = "z2h-demo-gha-apply"
  assume_role_policy   = data.aws_iam_policy_document.apply_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "apply" {
  name   = "demo-apply"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.apply.json
}

# --------------------------------------------------------------- spend alarm

resource "aws_budgets_budget" "monthly" {
  name         = "z2h-demo-monthly"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_email]
  }
}
