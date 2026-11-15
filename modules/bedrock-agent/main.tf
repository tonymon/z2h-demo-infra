terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  agent_name = "${var.name_prefix}-${var.demo_name}"
}

# Service role the Bedrock agent assumes. Locked to this account and to agents
# in this account/region (confused-deputy protection).
data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:agent/*"]
    }
  }
}

# Broad on models for the first run; tighten to the single model/profile in use
# after confirming it works (this is a good "least privilege" video).
data "aws_iam_policy_document" "invoke" {
  statement {
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:GetInferenceProfile",
      "bedrock:GetFoundationModel",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/*",
      "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:inference-profile/*",
    ]
  }
}

resource "aws_iam_role" "agent" {
  name               = "z2h-demo-${var.demo_name}-agent"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

resource "aws_iam_role_policy" "agent" {
  name   = "invoke-model"
  role   = aws_iam_role.agent.id
  policy = data.aws_iam_policy_document.invoke.json
}

resource "aws_bedrockagent_agent" "this" {
  agent_name                  = local.agent_name
  agent_resource_role_arn     = aws_iam_role.agent.arn
  foundation_model            = var.foundation_model
  instruction                 = var.instruction
  description                 = "Zero to Hero AI demo agent (ephemeral; destroyed after each recording)."
  idle_session_ttl_in_seconds = 600
  prepare_agent               = true

  depends_on = [aws_iam_role_policy.agent]
}

resource "aws_bedrockagent_agent_alias" "live" {
  agent_alias_name = "live"
  agent_id         = aws_bedrockagent_agent.this.agent_id
  description      = "Alias used for the demo."
}
