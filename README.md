# infra/mountain-race

Terraform module managing AWS infrastructure for the [mountain-race](../../mountain-race) application.

- **Region:** `eu-west-3` (Paris)
- **Account:** `704496393752`
- **Remote state:** S3 bucket `terraform-state-bucket-yrichard`, key `mountain-race/terraform.tfstate`

## Resources

| Resource | Name |
|---|---|
| ECR repository | `mountain-race` |
| Secrets Manager secret | `mountain-race/prod` |
| IAM role | `MountainRaceAppRunnerECRRole` — lets AppRunner pull from ECR |
| IAM role | `AppRunnerInstanceRoleMountainRace` — lets the container read prod secrets |
| IAM role | `GitHubActionECRPushRoleForMountainRace` — lets GitHub Actions push images via OIDC |
| IAM policy | `GitHubECRPushPolicyForMountainRace` — ECR push/pull permissions |
| IAM policy | `GithubMountainECRTerraformStatePolicy` — least-privilege `terraform apply` permissions |

> The AppRunner service definition is currently commented out in `main.tf`.

## Secrets

Stored as a JSON object in `mountain-race/prod`. Currently active keys:

| Key | Source |
|---|---|
| `OPENAI_API_KEY` | `var.openai_api_key` |
| `LLM_PROVIDER` | `var.llm_provider` (default: `openai`) |

## CI/CD

GitHub Actions authenticates via OIDC (no long-lived credentials). The trust policy on `GitHubActionECRPushRoleForMountainRace` allows all branches, tags, and PRs from `yarichard/mountain-race`. The OIDC provider ARN is read from the bootstrap remote state.

## Usage

```sh
terraform init
terraform plan -var="openai_api_key=sk-..."
terraform apply -var="openai_api_key=sk-..."
```

Sensitive variables (`openai_api_key`) must be supplied at plan/apply time or via a `.tfvars` file (not committed).
