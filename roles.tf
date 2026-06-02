module "ecr_app" {
  source = "git::https://github.com/yarichard/terraform-bootstrap.git//modules/ecr-app?ref=main"

  app_name                 = "mountain-race"
  github_repositories      = var.github_repositories
  github_oidc_provider_arn = data.terraform_remote_state.bootstrap-tfstate.outputs.github_oidc_provider_arn
  ecr_push_pull_policy_arn = data.terraform_remote_state.bootstrap-tfstate.outputs.ecr_push_pull_policy_arn
  # apprunner_ecr_role_arn output from this module is no longer referenced
}

data "aws_iam_policy_document" "terraform_state" {
  statement {
    sid    = "ECRAccess"
    effect = "Allow"
    actions = [
      "ecr:DescribeRepositories",
      "ecr:GetRepositoryPolicy",
      "ecr:ListTagsForResource",
      "ecr:CreateRepository",
      "ecr:DeleteRepository",
      "ecr:PutImageScanningConfiguration",
      "ecr:PutEncryptionConfiguration"
    ]
    resources = ["arn:aws:ecr:${var.region}:${var.aws_account_id}:repository/mountain-race"]
  }

  statement {
    sid    = "IAMAccess"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:PassRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:GetPolicy",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:TagPolicy",
      "iam:ListInstanceProfilesForRole"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "SSMParamAccess"
    effect = "Allow"
    actions = [
      "ssm:PutParameter",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:DeleteParameter",
      "ssm:AddTagsToResource",
      "ssm:ListTagsForResource"
    ]
    resources = ["arn:aws:ssm:${var.region}:${var.aws_account_id}:parameter/mountain-race/*"]
  }

  statement {
    sid    = "SSMListAccess"
    effect = "Allow"
    actions = [
      "ssm:DescribeParameters" # list action — does not support resource-level restrictions
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ECSAccess"
    effect = "Allow"
    actions = [
      "ecs:CreateCluster",
      "ecs:DeleteCluster",
      "ecs:DescribeClusters",
      "ecs:TagResource",
      "ecs:ListTagsForResource",
      "ecs:RegisterTaskDefinition",
      "ecs:DeregisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
      "ecs:CreateService",
      "ecs:UpdateService",
      "ecs:DeleteService",
      "ecs:DescribeServices"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AppAutoScalingAccess"
    effect = "Allow"
    actions = [
      "application-autoscaling:RegisterScalableTarget",
      "application-autoscaling:DeregisterScalableTarget",
      "application-autoscaling:DescribeScalableTargets",
      "application-autoscaling:PutScheduledAction",
      "application-autoscaling:DeleteScheduledAction",
      "application-autoscaling:DescribeScheduledActions",
      "application-autoscaling:ListTagsForResource",
      "application-autoscaling:TagResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "LogsAccess"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy",
      "logs:ListTagsForResource",
      "logs:TagResource"
    ]
    resources = [
      "arn:aws:logs:${var.region}:${var.aws_account_id}:log-group:/ecs/mountain-race*",
      "arn:aws:logs:${var.region}:${var.aws_account_id}:log-group:/aws/lambda/mountain-race-*"
    ]
  }

  statement {
    sid    = "LogsListAccess"
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups" # list action — does not support resource-level restrictions
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EC2VPCAccess"
    effect = "Allow"
    actions = [
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:DescribeSecurityGroupRules",
      "ec2:CreateTags"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "LambdaAccess"
    effect = "Allow"
    actions = [
      "lambda:CreateFunction",
      "lambda:DeleteFunction",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:GetFunctionCodeSigningConfig",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:GetPolicy",
      "lambda:ListVersionsByFunction",
      "lambda:PublishVersion",
      "lambda:TagResource",
      "lambda:ListTags"
    ]
    resources = ["arn:aws:lambda:${var.region}:${var.aws_account_id}:function:mountain-race-*"]
  }

  statement {
    sid    = "EventBridgeAccess"
    effect = "Allow"
    actions = [
      "events:PutRule",
      "events:DeleteRule",
      "events:DescribeRule",
      "events:PutTargets",
      "events:RemoveTargets",
      "events:ListTargetsByRule",
      "events:TagResource",
      "events:ListTagsForResource"
    ]
    resources = ["arn:aws:events:${var.region}:${var.aws_account_id}:rule/mountain-race-*"]
  }

  statement {
    sid    = "Route53Access"
    effect = "Allow"
    actions = [
      "route53:CreateHostedZone",
      "route53:DeleteHostedZone",
      "route53:GetHostedZone",
      "route53:ListHostedZones",
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets",
      "route53:GetChange",
      "route53:ListTagsForResource",
      "route53:ChangeTagsForResource",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudFrontAccess"
    effect = "Allow"
    actions = [
      "cloudfront:CreateDistribution",
      "cloudfront:CreateDistributionWithTags", # Terraform uses this when tags are set
      "cloudfront:UpdateDistribution",
      "cloudfront:GetDistribution",
      "cloudfront:GetDistributionConfig",
      "cloudfront:DeleteDistribution",
      "cloudfront:TagResource",
      "cloudfront:ListTagsForResource",
    ]
    resources = ["arn:aws:cloudfront::${var.aws_account_id}:distribution/*"]
  }

  statement {
    sid    = "CloudFrontListAccess"
    effect = "Allow"
    actions = [
      "cloudfront:ListDistributions" # list action — does not support resource-level restrictions
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ACMAccess"
    effect = "Allow"
    actions = [
      "acm:RequestCertificate",
      "acm:DescribeCertificate",
      "acm:DeleteCertificate",
      "acm:ListTagsForCertificate",
      "acm:AddTagsToCertificate",
    ]
    resources = ["arn:aws:acm:us-east-1:${var.aws_account_id}:certificate/*"]
  }

  statement {
    sid    = "ACMListAccess"
    effect = "Allow"
    actions = [
      "acm:ListCertificates" # list action — does not support resource-level restrictions
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ecr_terraform_state_policy" {
  name        = "GithubMountainRaceTerraformStatePolicy"
  description = "Allow GitHub Actions to perform terraform apply for mountain-race resources"
  policy      = data.aws_iam_policy_document.terraform_state.json
}

resource "aws_iam_role_policy_attachment" "mountain_race_ecr_terraform_state_attach" {
  role       = data.terraform_remote_state.bootstrap-tfstate.outputs.github_actions_terraform_role_name
  policy_arn = aws_iam_policy.ecr_terraform_state_policy.arn
}

# --- ECS roles ---

data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_execution_role" {
  name               = "MountainRaceECSExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
  tags               = { Name = "mountain-race-ecs-execution" }
}

resource "aws_iam_role_policy_attachment" "ecs_execution_basic" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ssm:GetParameters (plural) is what ECS uses when injecting secrets at task launch
resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "SSMReadPolicy"
  role = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameters"]
      Resource = ["arn:aws:ssm:${var.region}:${var.aws_account_id}:parameter/mountain-race/*"]
    }]
  })
}

resource "aws_iam_role" "ecs_task_role" {
  name               = "MountainRaceECSTaskRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
  tags               = { Name = "mountain-race-ecs-task" }
}
