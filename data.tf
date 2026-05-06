// Reference for tfstate bucket policy
data "terraform_remote_state" "bootstrap-tfstate" {
  backend = "s3"
  config = {
    bucket = "terraform-state-bucket-yrichard"
    key    = "bootstrap/terraform.tfstate"
    region = "eu-west-3"
  }
}

// OIDC Provider for GitHub
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

// IAM Role for GitHub Actions
data "aws_iam_policy_document" "github_assume_role_for_mountain_race_repos" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.terraform_remote_state.bootstrap-tfstate.outputs.github_oidc_provider_arn]
    }

    # Must always match
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Allow every branch for all projects
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = flatten([
        for repo in var.github_repositories : [
          "repo:yarichard/${repo}:ref:refs/heads/*",
          "repo:yarichard/${repo}:ref:refs/tags/*",
          "repo:yarichard/${repo}:pull_request"
        ]
      ])
    }
  }
}

// Policy for ECR Push/Pull
data "aws_iam_policy_document" "ecr_access" {
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:BatchGetImage"
    ]
    resources = ["*"]
  }
}