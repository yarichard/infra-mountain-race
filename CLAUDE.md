## Terraform infrastructure for mountain-race project

Manages AWS resources for the mountain-race app. The application code lives at `../../mountain-race`; see its CLAUDE.md for app-level details.

### Terraform architecture

Two projects, both backed by the same S3 bucket (`terraform-state-bucket-yrichard`, eu-west-3):

| Project | Path | State key | Purpose |
|---|---|---|---|
| `terraform-bootstrap` | `../terraform-bootstrap` | `bootstrap/terraform.tfstate` | Shared foundations: S3 state bucket, GitHub OIDC provider, `GitHubActionTerraformRole` (used by all infra CI pipelines) |
| `infra-mountain-race` | `.` (this project) | `mountain-race/terraform.tfstate` | App-specific resources: ECR, Secrets Manager, IAM roles for ECR push and AppRunner |

This project reads bootstrap outputs via `terraform_remote_state` to get `github_oidc_provider_arn`, `github_actions_terraform_role_name`, and `ecr_push_pull_policy_arn`.

**To add a new infra repo's CI pipeline**, add its GitHub repo name to `github_repositories_allowed_for_terraform` in `terraform-bootstrap/variables.tf` and re-apply bootstrap.

### Shared module

The AppRunner ECR role and GitHub ECR push role are defined via the local module `../modules/ecr-app` (instantiated as `module.ecr_app`). The shared ECR push/pull policy (`GitHubECRPushPullPolicy`) lives in `terraform-bootstrap` and is referenced by ARN.

### AWS resources managed

| Resource | Name | Notes |
|---|---|---|
| AppRunner service | `mountain-race` | pulls from ECR, reads prod secrets |
| ECR repository | `mountain-race` | scan on push, AES256 encryption, force_delete=true |
| Secrets Manager secret | `mountain-race/prod` | JSON object: OPENAI_API_KEY, LLM_PROVIDER |
| IAM role | `MountainRaceAppRunnerECRRole` | lets AppRunner pull from ECR (ECRReadOnly); managed via `module.ecr_app` |
| IAM role | `AppRunnerInstanceRoleMountainRace` | instance role for the running container; allows `secretsmanager:GetSecretValue` on the prod secret |
| IAM role | `GitHubActionECRPushRoleForMountainRace` | lets `yarichard/mountain-race` push/pull images via OIDC; managed via `module.ecr_app` |
| IAM policy | `GithubMountainRaceTerraformStatePolicy` | least-privilege `terraform apply` permissions for this module; attached to `GitHubActionTerraformRole` (bootstrap) |

Region: `eu-west-3` (Paris). Account: `704496393752`.

### CI/CD wiring

Two GitHub Actions workflows in `.github/workflows/`:

- **`terraform-plan.yml`** (this repo, `yarichard/infra-mountain-race`): assumes `GitHubActionTerraformRole` (bootstrap) to run `terraform plan/apply`.
- **`ci.yml`** (`yarichard/mountain-race`): assumes `GitHubActionECRPushRoleForMountainRace` to push Docker images to ECR.

Both authenticate via OIDC — no long-lived credentials.

### Secrets

Prod secrets are stored as a single JSON object in `mountain-race/prod` (Secrets Manager, eu-west-3). Active keys: `OPENAI_API_KEY`, `LLM_PROVIDER`. MeteoFrance and Gemini keys are commented out.

### Key variables (`variables.tf`)

| Variable | Default | Purpose |
|---|---|---|
| `region` | `eu-west-3` | AWS region |
| `mountain_race_ecr_repo` | `mountain-race` | ECR repo name |
| `aws_account_id` | `704496393752` | used in resource ARNs |
| `github_repositories` | `["mountain-race"]` | repos allowed to assume the ECR push role |
| `openai_api_key` | — | sensitive, no default |
| `llm_provider` | `openai` | active LLM provider |
