resource "aws_secretsmanager_secret" "mountain_race_prod" {
  name                    = "mountain-race/prod"
  description             = "Production secrets for mountain-race application"
  recovery_window_in_days = 0

  tags = {
    Name = "mountain-race-prod"
  }
}

resource "aws_secretsmanager_secret_version" "mountain_race_prod" {
  secret_id = aws_secretsmanager_secret.mountain_race_prod.id
  secret_string = jsonencode({
    #METEOFRANCE_USER = var.meteofrance_user
    #METEOFRANCE_PASS = var.meteofrance_pass
    OPENAI_API_KEY   = var.openai_api_key
    #GEMINI_API_KEY   = var.gemini_api_key
    LLM_PROVIDER     = var.llm_provider
  })
}

output "mountain_race_secret_arn" {
  value = aws_secretsmanager_secret.mountain_race_prod.arn
}
