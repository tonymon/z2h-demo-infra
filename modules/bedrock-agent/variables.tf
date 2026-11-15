variable "name_prefix" {
  type    = string
  default = "z2h-demo"
}

variable "demo_name" {
  description = "Short name for this demo, used in resource names."
  type        = string
}

variable "foundation_model" {
  description = "Model ID or inference-profile ID the agent uses. Deliberately has no default: pick a current model you have access to in this account/region (Bedrock console > Model access)."
  type        = string
}

variable "instruction" {
  description = "System instruction for the agent (Bedrock requires at least 40 characters)."
  type        = string
  default     = "You are the First Meeting Agent for a small business. Greet visitors politely, ask what they need, collect their name, contact details and a short description of the request, and say a human will follow up. Never invent prices, promises or availability. Reply in the language the visitor writes in (English or Spanish)."
}
