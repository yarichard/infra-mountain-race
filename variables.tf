variable "region" {
  description = "Default region for resources."
  type        = string
  default     = "eu-west-3"
}

variable "mountain_race_ecr_repo" {
  description = "Repo for mountain-race app"
  type        = string
  default     = "mountain-race"
}

variable "aws_account_id" {
  description = "AWS Account ID for ECR image URI."
  type        = string
  default     = "704496393752"
}

variable "github_repositories" {
  description = "List of GitHub repositories allowed for OIDC."
  type        = list(string)
  default     = ["mountain-race"]
}

variable "terraform_repo" {
  description = "GitHub repository name for Terraform state access."
  type        = string
  default     = "infra-wam_message"
}

# variable "meteofrance_user" {
#   description = "MeteoFrance API username."
#   type        = string
#   sensitive   = true
# }

# variable "meteofrance_pass" {
#   description = "MeteoFrance API password."
#   type        = string
#   sensitive   = true
# }

variable "openai_api_key" {
  description = "OpenAI API key."
  type        = string
  sensitive   = true
}

# variable "gemini_api_key" {
#   description = "Google Gemini API key."
#   type        = string
#   sensitive   = true
# }

variable "llm_provider" {
  description = "Active LLM provider (openai or gemini)."
  type        = string
  default     = "openai"
}