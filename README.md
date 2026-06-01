# infra/mountain-race

Terraform module managing AWS infrastructure for the [mountain-race](../../mountain-race) application.

- **Region:** `eu-west-3` (Paris)
- **Account:** `704496393752`
- **Remote state:** S3 bucket `terraform-state-bucket-yrichard`, key `states/mountain-race.tfstate`
- **Domain:** `mountain-race.eravest.fr` (OVH registrar, Route53 zone)

## Architecture

```
User → CloudFront (HTTPS) → origin.mountain-race.eravest.fr:8003 → ECS Fargate task
                                        ↑
                              Route53 A record (TTL 60s)
                                        ↑
                              Lambda (fires on task RUNNING via EventBridge)
```

See `CLAUDE.md` for the full diagram and resource inventory.

## First-time setup (from scratch)

Prerequisites:
- AWS CLI configured with admin credentials
- Terraform ≥ 1.2
- `terraform-bootstrap` applied (provides OIDC provider, S3 state bucket)
- OVH control panel access for `eravest.fr`

### Step 1 — Initialise Terraform

```sh
terraform init
```

### Step 2 — Store app secrets in SSM

Migrate existing values or set them fresh. These are managed outside Terraform so they never touch the state file.

```sh
aws ssm put-parameter \
  --name "/mountain-race/OPENAI_API_KEY" \
  --type SecureString \
  --value "sk-..." \
  --overwrite \
  --region eu-west-3

aws ssm put-parameter \
  --name "/mountain-race/LLM_PROVIDER" \
  --type SecureString \
  --value "openai" \
  --overwrite \
  --region eu-west-3
```

### Step 3 — Create the Route53 zone and get NS records

```sh
terraform apply -target=aws_route53_zone.mountain_race
terraform output route53_name_servers
```

### Step 4 — Delegate the subdomain in OVH

In the OVH control panel, open the `eravest.fr` DNS zone and add **4 NS records** for the `mountain-race` subdomain:

| Field | Value |
|---|---|
| Type | `NS` |
| Subdomain | `mountain-race` |
| Target | each of the 4 nameservers from `terraform output route53_name_servers` |
| TTL | 3600 |

Wait ~5 minutes for propagation before continuing.

### Step 5 — Apply everything

```sh
terraform apply -var="openai_api_key=sk-..." -var="llm_provider=openai"
```

Terraform will:
1. Create the ACM certificate and auto-validate it via Route53
2. Create the CloudFront distribution (waits for the cert — takes 5–15 minutes)
3. Create the ECS cluster, service, Lambda, EventBridge rule, and all IAM roles

### Step 6 — Trigger a deployment to activate DNS

Force a new ECS task so the Lambda fires and sets the real origin IP:

```sh
aws ecs update-service \
  --cluster mountain-race \
  --service mountain-race \
  --force-new-deployment \
  --region eu-west-3
```

Wait ~60 seconds for the task to reach RUNNING, then verify:

```sh
curl https://mountain-race.eravest.fr
```

---

## Day-to-day operations

### Scale down / up manually

```sh
# Stop (outside scheduled window)
aws ecs update-service --cluster mountain-race --service mountain-race \
  --desired-count 0 --region eu-west-3

# Start
aws ecs update-service --cluster mountain-race --service mountain-race \
  --desired-count 1 --region eu-west-3
```

The service scales automatically via App Auto Scaling:
- **Scale to 0** at 21:00 UTC (23:00 Paris CEST)
- **Scale to 1** at 06:00 UTC (08:00 Paris CEST)

To change the scale-up schedule:

```sh
aws application-autoscaling put-scheduled-action \
  --service-namespace ecs \
  --resource-id "service/mountain-race/mountain-race" \
  --scalable-dimension ecs:service:DesiredCount \
  --scheduled-action-name "mountain-race-scale-up" \
  --schedule "cron(0 6 * * ? *)" \
  --scalable-target-action MinCapacity=1,MaxCapacity=1 \
  --region eu-west-3
```

Same command for scale-down: replace the action name with `mountain-race-scale-down` and set `MinCapacity=0,MaxCapacity=0`.

### Update app secrets

```sh
aws ssm put-parameter \
  --name "/mountain-race/OPENAI_API_KEY" \
  --type SecureString \
  --value "sk-new-key" \
  --overwrite \
  --region eu-west-3
```

Changes take effect on the next task restart (force a new deployment to apply immediately).

### Deploy a new image

Push to ECR via GitHub Actions (`ci.yml` in `yarichard/mountain-race`) — it calls `aws ecs update-service --force-new-deployment` automatically. The Lambda then updates the Route53 origin record.

### Rotate OVH API credentials

```sh
aws ssm put-parameter \
  --name "/mountain-race/ovh-consumer-key" \
  --type SecureString \
  --value "new-consumer-key" \
  --overwrite \
  --region eu-west-3
```

The three OVH credential parameters (`ovh-application-key`, `ovh-application-secret`, `ovh-consumer-key`) are stored manually in SSM — **not managed by Terraform**.

## CI/CD

GitHub Actions authenticates via OIDC — no long-lived credentials:

| Workflow | Repo | Role assumed | Purpose |
|---|---|---|---|
| `terraform-plan.yml` | `yarichard/infra-mountain-race` | `GitHubActionTerraformRole` (bootstrap) | `terraform plan/apply` |
| `ci.yml` | `yarichard/mountain-race` | `GitHubActionECRPushRoleForMountainRace` | Build + push image to ECR, deploy to ECS |
