module "ecr_app" {
  source = "git::https://github.com/yarichard/terraform-bootstrap.git//modules/ecr-app?ref=main"

  app_name                 = "mountain-race"
  github_repositories      = var.github_repositories
  github_oidc_provider_arn = data.terraform_remote_state.bootstrap-tfstate.outputs.github_oidc_provider_arn
  ecr_push_pull_policy_arn = data.terraform_remote_state.bootstrap-tfstate.outputs.ecr_push_pull_policy_arn
}

// IAM Policy for Terraform State Access
data "aws_iam_policy_document" "terraform_state" {

  statement {
    actions = [
      "ecr:DescribeRepositories",
      "ecr:ListTagsForResource",
      "ecr:CreateRepository"
    ]
    resources = [
      "arn:aws:ecr:${var.region}:${var.aws_account_id}:repository/mountain-race"
    ]
  }

  statement {
    actions = [
      "iam:GetRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:CreateRole",
      "iam:AttachRolePolicy"
    ]
    resources = [
      "arn:aws:iam::${var.aws_account_id}:role/MountainRaceAppRunnerECRRole"
    ]
  }

  statement {
    actions = [
      "iam:GetRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:CreateRole",
      "iam:AttachRolePolicy"
    ]
    resources = [
      "arn:aws:iam::${var.aws_account_id}:role/GitHubActionECRPushRoleForMountainRace"
    ]
  }

  statement {
    actions = [
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion"
    ]
    resources = [
      "arn:aws:iam::${var.aws_account_id}:policy/GithubMountainRaceTerraformStatePolicy"
    ]
  }

  statement {
    actions = [
      "iam:GetRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:CreateRole",
      "iam:AttachRolePolicy",
      "iam:GetRolePolicy",
      "iam:PutRolePolicy"
    ]
    resources = [
      "arn:aws:iam::${var.aws_account_id}:role/AppRunnerInstanceRoleMountainRace"
    ]
  }

  statement {
    actions = [ 
      "secretsmanager:DescribeSecret", 
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      aws_secretsmanager_secret.mountain_race_prod.arn
    ]
  }

  /*statement {
    actions = [
      "apprunner:CreateService",
      "apprunner:DescribeService",
      "apprunner:ListTagsForResource"
    ]
    resources = [
      aws_apprunner_service.mountain_race.arn
    ]
  }*/
}

resource "aws_iam_policy" "ecr_terraform_state_policy" {
  name        = "GithubMountainRaceTerraformStatePolicy"
  description = "Allow GitHub Actions to perform terraform apply for mountain_race resources related"
  policy      = data.aws_iam_policy_document.terraform_state.json
}

// Attach Policy to the Github Role (reference from bootstrap tfstate)
resource "aws_iam_role_policy_attachment" "mountain_race_ecr_terraform_state_attach" {
  role       = data.terraform_remote_state.bootstrap-tfstate.outputs.github_actions_terraform_role_name
  policy_arn = aws_iam_policy.ecr_terraform_state_policy.arn
}

// AppRunner instance role — allows the running container to read prod secrets
resource "aws_iam_role" "apprunner_instance_role" {
  name = "AppRunnerInstanceRoleMountainRace"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "tasks.apprunner.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "apprunner_secrets_policy" {
  name = "AppRunnerSecretsPolicy"
  role = aws_iam_role.apprunner_instance_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "secretsmanager:GetSecretValue",
      Resource = aws_secretsmanager_secret.mountain_race_prod.arn
    }]
  })
}