// Github Action configuration for pushing Dockers to ECR repo
resource "aws_iam_role" "apprunner_ecr_role" {
  name = "MountainRaceAppRunnerECRRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "build.apprunner.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "apprunner_ecr_readonly" {
  role       = aws_iam_role.apprunner_ecr_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role" "github_ecr_role" {
  name               = "GitHubActionECRPushRoleForMountainRace"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role_for_mountain_race_repos.json
}

resource "aws_iam_policy" "ecr_policy" {
  name        = "GitHubECRPushPolicyForMountainRace"
  description = "Allow GitHub Actions to push/pull images to ECR"
  policy      = data.aws_iam_policy_document.ecr_access.json
}

// Attach policy to the role
resource "aws_iam_role_policy_attachment" "github_ecr_attach" {
  role       = aws_iam_role.github_ecr_role.name
  policy_arn = aws_iam_policy.ecr_policy.arn
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
      "iam:CreatePolicy",
      "iam:AttachRolePolicy"
    ]
    resources = [
      "arn:aws:iam::${var.aws_account_id}:policy/GitHubECRPushPolicyForMountainRace"
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