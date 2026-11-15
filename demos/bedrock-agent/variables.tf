variable "region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  description = "Local runs only: pass \"personal\". Leave null in CI."
  type        = string
  default     = null
}

variable "expected_account_id" {
  description = "Provider refuses to run against any other account. Set via local.mk (local) or the AWS_ACCOUNT_ID secret (CI); no default so no account ID is committed."
  type        = string
}

variable "foundation_model" {
  description = "Model or inference-profile ID for the agent. No default on purpose."
  type        = string
}
