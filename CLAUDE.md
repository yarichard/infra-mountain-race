## Terraform infrastructure for mountain-race project

Manages AWS resources for the mountain-race app. The application code lives at `../../mountain-race`; see its CLAUDE.md for app-level details.

### Current state

AppRunner service is active in `main.tf` with Secrets Manager injection and an instance role.

### AWS resources managed

| Resource | Name | Notes |
|---|---|---|
| ECR repository | `mountain-race` | scan on push, AES256 encryption, force_delete=true |
| AppRunner service | `mountain-race` | port 3000, 256 CPU / 512 MB |
| Secrets Manager secret | `mountain-race/prod` | JSON object: METEOFRANCE_USER/PASS, OPENAI_API_KEY, GEMINI_API_KEY, LLM_PROVIDER |
| IAM role | `MountainRaceAppRunnerECRRole` | lets AppRunner pull from ECR (ECRReadOnly) |
| IAM role | `AppRunnerInstanceRoleMountainRace` | instance role for the running container; allows `secretsmanager:GetSecretValue` on the prod secret |
| IAM role | `GitHubActionECRPushRoleForMountainRace` | lets GitHub Actions push/pull images via OIDC |
| IAM policy | `GitHubECRPushPolicyForMountainRace` | full ECR push/pull permissions, attached to the role above |
| IAM policy | `GithubMountainECRTerraformStatePolicy` | least-privilege `terraform apply` permissions for this module; attached to the bootstrap GitHub Actions Terraform role |

Region: `eu-west-3` (Paris). Account: `704496393752`.

### CI/CD wiring

GitHub Actions authenticates via OIDC (no long-lived credentials). The trust policy on `GitHubActionECRPushRoleForMountainRace` allows all branches, tags, and pull requests from `yarichard/mountain-race`. The OIDC provider ARN is read from the bootstrap remote state.

### Tfstate backend

Remote state is stored in S3 bucket `terraform-state-bucket-yrichard` (managed by the `terraform-bootstrap` project). This module reads the bootstrap state to retrieve `github_oidc_provider_arn` and `github_actions_terraform_role_name`.

### Secrets

Prod secrets are stored as a single JSON object in `mountain-race/prod` (Secrets Manager, eu-west-3). AppRunner injects each key as an individual env var via `runtime_environment_secrets`. OLLAMA_* vars are excluded — local dev only. `APP_ENV=production` is set as a plain env var so the Go backend skips `godotenv.Load`.

### Key variables (`variables.tf`)

| Variable | Default | Purpose |
|---|---|---|
| `region` | `eu-west-3` | AWS region |
| `mountain_race_ecr_repo` | `mountain-race` | ECR repo name |
| `aws_account_id` | `704496393752` | used in resource ARNs |
| `github_repositories` | `["mountain-race"]` | repos allowed to assume the ECR push role |
| `meteofrance_user` | — | sensitive, no default |
| `meteofrance_pass` | — | sensitive, no default |
| `openai_api_key` | — | sensitive, no default |
| `gemini_api_key` | — | sensitive, no default |
| `llm_provider` | `openai` | active LLM provider |
