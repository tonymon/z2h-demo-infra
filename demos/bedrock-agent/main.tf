# Demo 1: a Bedrock agent, deployed and destroyed from CI.
#
# State lives in the S3 bucket created by bootstrap/. Bucket and key are passed
# at init time (see Makefile and the workflows) so no account IDs are committed.

terraform {
  required_version = ">= 1.10"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
  # null in CI (credentials come from OIDC); "personal" for local runs.
  profile             = var.aws_profile
  allowed_account_ids = [var.expected_account_id]

  default_tags {
    tags = {
      Project   = "z2h-demo-infra"
      Demo      = "bedrock-agent"
      ManagedBy = "terraform"
      Owner     = "zero2heroai"
      Teardown  = "nightly"
    }
  }
}

module "agent" {
  source           = "../../modules/bedrock-agent"
  demo_name        = "bedrock-agent"
  foundation_model = var.foundation_model
}
