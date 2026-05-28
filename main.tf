provider "aws" {
  region = var.region
}

resource "aws_apprunner_service" "mountain_race" {
  service_name = "mountain-race"

  source_configuration {
    authentication_configuration {
      access_role_arn = module.ecr_app.apprunner_ecr_role_arn 
    }
    image_repository {
      image_identifier      = "${var.aws_account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.mountain_race_ecr_repo}:latest"
      image_repository_type = "ECR"
      image_configuration {
        port = "8003"
        runtime_environment_variables = {
          APP_ENV = "production"
        }
        runtime_environment_secrets = {
          #METEOFRANCE_USER = "${aws_secretsmanager_secret.mountain_race_prod.arn}:METEOFRANCE_USER::"
          #METEOFRANCE_PASS = "${aws_secretsmanager_secret.mountain_race_prod.arn}:METEOFRANCE_PASS::"
          OPENAI_API_KEY   = "${aws_secretsmanager_secret.mountain_race_prod.arn}:OPENAI_API_KEY::"
          #GEMINI_API_KEY   = "${aws_secretsmanager_secret.mountain_race_prod.arn}:GEMINI_API_KEY::"
          LLM_PROVIDER     = "${aws_secretsmanager_secret.mountain_race_prod.arn}:LLM_PROVIDER::"
        }
      }
    }
  }

  instance_configuration {
    cpu               = "256"
    memory            = "512"
    instance_role_arn = aws_iam_role.apprunner_instance_role.arn
  }

  tags = {
    Name = "mountain-race"
  }
}

resource "aws_apprunner_custom_domain_association" "mountain_race" {
  service_arn          = aws_apprunner_service.mountain_race.arn
  domain_name          = "mountain-race.eravest.fr"
  enable_www_subdomain = false
}

output "apprunner_service_arn" {
  value = aws_apprunner_service.mountain_race.arn
}

output "apprunner_custom_domain_cname_target" {
  value = aws_apprunner_custom_domain_association.mountain_race.dns_target
}

output "apprunner_certificate_validation_records" {
  value = aws_apprunner_custom_domain_association.mountain_race.certificate_validation_records
}