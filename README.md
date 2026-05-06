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

Stored as a single JSON object in AWS Secrets Manager at `mountain-race/prod`. Terraform owns the secret *resource* (ARN, policy) but **not the value** — the value is managed out-of-band so it never touches the Terraform state file.

Active keys injected as env vars into the running container:

| Key | Description |
|---|---|
| `OPENAI_API_KEY` | OpenAI API key |
| `LLM_PROVIDER` | Active LLM provider (`openai` or `gemini`) |

### Updating secrets

Use the AWS CLI from a machine with appropriate IAM permissions. Always provide the full JSON object — partial updates will overwrite the other keys.

**Read current value:**
```sh
aws secretsmanager get-secret-value \
  --secret-id mountain-race/prod \
  --region eu-west-3 \
  --query SecretString \
  --output text
```

**Update (replace with full object):**
```sh
aws secretsmanager put-secret-value \
  --secret-id mountain-race/prod \
  --region eu-west-3 \
  --secret-string '{"OPENAI_API_KEY":"sk-...","LLM_PROVIDER":"openai"}'
```

Changes take effect on the next AppRunner deployment — no `terraform apply` needed.

## CI/CD

GitHub Actions authenticates via OIDC (no long-lived credentials):

- `yarichard/infra-mountain-race` assumes `GitHubActionTerraformRole` (bootstrap) to run `terraform plan/apply`
- `yarichard/mountain-race` assumes `GitHubActionECRPushRoleForMountainRace` to push Docker images to ECR

## Usage

```sh
terraform init
terraform plan
terraform apply
```

No secret variables required — secret values are managed directly in Secrets Manager (see above).
