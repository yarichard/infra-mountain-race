## Terraform infrastructure for mountain-race project

Manages AWS resources for the mountain-race app. The application code lives at `../../mountain-race`; see its CLAUDE.md for app-level details.

### Infrastructure diagram

```
                          ┌─────────────────────────────────────────────────────┐
                          │ OVH (eravest.fr)                                    │
                          │  mountain-race NS → Route53 (one-time delegation)   │
                          └──────────────────────┬──────────────────────────────┘
                                                 │
                          ┌──────────────────────▼──────────────────────────────┐
                          │ Route53 zone: mountain-race.eravest.fr              │
                          │                                                     │
                          │  mountain-race.eravest.fr  A alias → CloudFront     │
                          │  origin.mountain-race.eravest.fr  A → Fargate IP   │◄─── Lambda updates
                          │  (ACM validation CNAME — managed by Terraform)      │     on task start
                          └──────────┬──────────────────────┬───────────────────┘
                                     │                      │
               ┌─────────────────────▼──────┐              │
               │ CloudFront                 │              │
               │ HTTPS (TLSv1.2)            │              │
               │ ACM cert (us-east-1)       │              │
               │ PriceClass_100             │              │
               │ No cache (TTL=0)           │              │
               └─────────────────────┬──────┘              │
                                     │ HTTP:8003            │
               ┌─────────────────────▼──────────────────────▼──────────────────┐
               │ ECS Fargate task (eu-west-3, default VPC, public IP)          │
               │  0.25 vCPU / 512 MB  •  port 8003                            │
               │  Go/Gin + Next.js static + headless Chromium                  │
               │                                                               │
               │  Secrets injected at start via SSM SecureString:              │
               │    /mountain-race/OPENAI_API_KEY                              │
               │    /mountain-race/LLM_PROVIDER                                │
               └───────────────────────────────────────────────────────────────┘
                         ▲                            ▲
                         │ pull image                 │ EventBridge: task RUNNING
               ┌─────────┴──────────┐     ┌──────────┴──────────────────────────┐
               │ ECR                │     │ Lambda: mountain-race-dns-updater   │
               │ mountain-race      │     │  resolves ENI → public IP           │
               └────────────────────┘     │  upserts Route53 A record           │
                                          └─────────────────────────────────────┘

  App Auto Scaling:  scale to 0 at 21:00 UTC  •  scale to 1 at 06:00 UTC (Paris)
  GitHub Actions CI: push image to ECR → force-new-deployment → Lambda fires → DNS updated
```

### Terraform architecture

Two projects, both backed by the same S3 bucket (`terraform-state-bucket-yrichard`, eu-west-3):

| Project | Path | State key | Purpose |
|---|---|---|---|
| `terraform-bootstrap` | `../terraform-bootstrap` | `bootstrap/terraform.tfstate` | Shared foundations: S3 state bucket, GitHub OIDC provider, `GitHubActionTerraformRole` |
| `infra-mountain-race` | `.` (this project) | `mountain-race/terraform.tfstate` | App-specific resources: ECS, ECR, CloudFront, Route53, ACM, SSM, Lambda |

This project reads bootstrap outputs via `terraform_remote_state` to get `github_oidc_provider_arn`, `github_actions_terraform_role_name`, and `ecr_push_pull_policy_arn`.

### AWS resources managed

| Resource | Name | Notes |
|---|---|---|
| ECS Cluster | `mountain-race` | Fargate launch type |
| ECS Service | `mountain-race` | scale-to-zero via App Auto Scaling; `assign_public_ip = true`, no ALB |
| ECS Task Definition | `mountain-race` | 0.25 vCPU / 512 MB, port 8003 |
| App Auto Scaling | `mountain-race` | scale to 0 at 21:00 UTC, scale to 1 at 06:00 UTC |
| ECR repository | `mountain-race` | scan on push, AES256 encryption, force_delete=true |
| SSM Parameter | `/mountain-race/OPENAI_API_KEY` | SecureString, free tier |
| SSM Parameter | `/mountain-race/LLM_PROVIDER` | SecureString, free tier |
| Route53 hosted zone | `mountain-race.eravest.fr` | $0.50/month; OVH delegates this subdomain via NS records |
| Route53 record | `mountain-race.eravest.fr` | A alias → CloudFront distribution |
| Route53 record | `origin.mountain-race.eravest.fr` | A → Fargate task public IP; updated by Lambda on each restart |
| ACM certificate | `mountain-race.eravest.fr` | free; provisioned in us-east-1 for CloudFront; auto-validated via Route53 |
| CloudFront distribution | `mountain-race` | HTTPS termination; origin = `origin.mountain-race.eravest.fr:8003`; no cache (TTL=0) |
| Lambda | `mountain-race-dns-updater` | updates Route53 origin A record when ECS task reaches RUNNING |
| EventBridge rule | `mountain-race-task-running` | triggers Lambda on ECS task state → RUNNING |
| IAM role | `MountainRaceECSExecutionRole` | ECS control plane: pulls ECR image, injects SSM secrets |
| IAM role | `MountainRaceECSTaskRole` | running container role (empty — add policies if app needs AWS APIs) |
| IAM role | `MountainRaceDNSUpdaterRole` | Lambda role: ecs:DescribeTasks, ec2:DescribeNetworkInterfaces, route53:ChangeResourceRecordSets |
| IAM role | `GitHubActionECRPushRoleForMountainRace` | lets `yarichard/mountain-race` push images via OIDC; managed via `module.ecr_app` |
| IAM policy | `GithubMountainRaceTerraformStatePolicy` | least-privilege `terraform apply` permissions; attached to `GitHubActionTerraformRole` |
| CloudWatch Log Group | `/ecs/mountain-race` | ECS container logs, 7-day retention |
| CloudWatch Log Group | `/aws/lambda/mountain-race-dns-updater` | Lambda logs, 7-day retention |

Region: `eu-west-3` (Paris). Account: `704496393752`. Domain: `mountain-race.eravest.fr`.

### DNS flow

OVH delegates `mountain-race.eravest.fr` to Route53 via NS records (one-time manual setup). Route53 then owns the zone and manages:
- The public A alias record → CloudFront
- The origin A record → Fargate task IP (Lambda-updated, TTL 60s)
- The ACM validation CNAME (Terraform-managed)

When the ECS task restarts (scheduled scale-up, CI deploy, or manual), EventBridge fires the Lambda which resolves the task's ENI public IP and upserts the `origin.mountain-race.eravest.fr` A record. CloudFront resolves the origin hostname on each request, so traffic resumes within 60 seconds (Route53 TTL).

### Cost (~$0.63–0.70/month)

| Item | Cost |
|---|---|
| Fargate compute | ~$0.012/hour when running, $0 when scaled to 0 (~$0.12/month at 10h use) |
| Route53 hosted zone | $0.50/month |
| CloudFront | $0 (free tier: 1 TB/month + 10M requests) |
| ACM certificate | $0 (free) |
| Lambda + EventBridge | $0 (free tier) |
| SSM SecureString | $0 (Standard tier) |
| ECR | ~$0.01/month |

vs App Runner: ~$5–8/month regardless of traffic.

### File layout

| File | Purpose |
|---|---|
| `main.tf` | Provider aliases, ECS cluster, task definition, service, security group, auto-scaling |
| `data.tf` | Remote state reference, default VPC/subnet data sources |
| `roles.tf` | `module.ecr_app`, GitHub Actions Terraform IAM policy, ECS execution/task roles |
| `secrets.tf` | SSM parameters for app secrets (OPENAI_API_KEY, LLM_PROVIDER) |
| `dns.tf` | Route53 zone + records, ACM cert, CloudFront distribution, Lambda + EventBridge |
| `ecr.tf` | ECR repository |
| `variables.tf` | Input variables |
| `terraform.tf` | Provider versions, S3 backend |
| `lambda/dns_updater/handler.py` | Lambda: resolves Fargate task IP → updates Route53 origin A record |

### CI/CD wiring

Two GitHub Actions workflows:

- **`terraform-plan.yml`** (this repo, `yarichard/infra-mountain-race`): assumes `GitHubActionTerraformRole` to run `terraform plan/apply`.
- **`ci.yml`** (`yarichard/mountain-race`): assumes `GitHubActionECRPushRoleForMountainRace` to push images to ECR, then calls `aws ecs update-service --force-new-deployment` to deploy. The Lambda fires automatically after the new task reaches RUNNING.

Both authenticate via OIDC — no long-lived credentials.

### Key variables (`variables.tf`)

| Variable | Default | Purpose |
|---|---|---|
| `region` | `eu-west-3` | AWS region |
| `mountain_race_ecr_repo` | `mountain-race` | ECR repo name |
| `aws_account_id` | `704496393752` | used in resource ARNs |
| `github_repositories` | `["mountain-race"]` | repos allowed to assume the ECR push role |
| `openai_api_key` | — | sensitive, no default; written to SSM at first apply |
| `llm_provider` | `openai` | active LLM provider; written to SSM |

### Manual operations

**Scale down immediately** (outside scheduled window):
```bash
aws ecs update-service --cluster mountain-race --service mountain-race --desired-count 0 --region eu-west-3
```

**Scale up immediately**:
```bash
aws ecs update-service --cluster mountain-race --service mountain-race --desired-count 1 --region eu-west-3
```

**Force a new deployment** (e.g. after config change):
```bash
aws ecs update-service --cluster mountain-race --service mountain-race --force-new-deployment --region eu-west-3
```

**Check current task IP**:
```bash
TASK=$(aws ecs list-tasks --cluster mountain-race --service-name mountain-race --region eu-west-3 --query 'taskArns[0]' --output text)
ENI=$(aws ecs describe-tasks --cluster mountain-race --tasks $TASK --region eu-west-3 --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text)
aws ec2 describe-network-interfaces --network-interface-ids $ENI --region eu-west-3 --query 'NetworkInterfaces[0].Association.PublicIp' --output text
```
