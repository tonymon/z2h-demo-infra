variable "aws_profile" {
  description = "Named AWS CLI profile. Always pass this explicitly; never rely on the default profile."
  type        = string
  default     = "personal"
}

variable "expected_account_id" {
  description = "The provider refuses to run against any other account. Set via local.mk / TF_VAR_expected_account_id; no default so no account ID is committed."
  type        = string
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "github_repo" {
  description = "owner/name of the GitHub repo allowed to assume the CI roles."
  type        = string
  default     = "tonymon/z2h-demo-infra"
}

variable "monthly_budget_usd" {
  description = "Monthly spend that triggers the alarm emails."
  type        = string
  default     = "10"
}

variable "budget_email" {
  description = "Where budget alarms are sent."
  type        = string
}
