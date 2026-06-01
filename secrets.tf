resource "aws_ssm_parameter" "openai_api_key" {
  name      = "/mountain-race/OPENAI_API_KEY"
  type      = "SecureString"
  value     = var.openai_api_key
  overwrite = true
  lifecycle { ignore_changes = [value] }
}

resource "aws_ssm_parameter" "llm_provider" {
  name      = "/mountain-race/LLM_PROVIDER"
  type      = "SecureString"
  value     = var.llm_provider
  overwrite = true
}
