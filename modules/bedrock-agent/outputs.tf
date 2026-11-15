output "agent_id" {
  value = aws_bedrockagent_agent.this.agent_id
}

output "agent_alias_id" {
  value = aws_bedrockagent_agent_alias.live.agent_alias_id
}

output "agent_role_arn" {
  value = aws_iam_role.agent.arn
}
