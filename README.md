# AWS DevOps Assessment Solution

This repository implements the requested assessment architecture with Terraform modules and Terragrunt live configuration.

## Architecture Implemented

- **Authentication (only `us-east-1`)**
	- Cognito User Pool
	- Cognito User Pool Client
	- Cognito test user (email configured from `account.hcl`)
	- Test user temporary password secret is provisioned by dedicated `secrets-manager` module and consumed by Cognito
- **Compute and data (both `us-east-1` and `eu-west-1`)**
	- API Gateway HTTP API with:
		- `GET /greet`
		- `POST /dispatch`
		- Cognito JWT authorizer using the centralized `us-east-1` pool
	- DynamoDB regional table (`GreetingLogs-*`)
	- Lambda `greeter`:
		- writes to regional DynamoDB
		- publishes verification payload to the enabled SNS targets from `account.hcl`:
			- SNS topic created in this account
			- SNS topic provided by 3rd party `arn:aws:sns:us-east-1:637226132752:Candidate-Verification-Topic`
		- returns 200 + region
	- Lambda `dispatcher`:
		- runs standalone Fargate task using ECS `RunTask`
	- ECS:
		- cluster + Fargate task definition per region
		- no ECS Service is created by design (dispatcher uses on-demand `RunTask`)
		- both regional ECS task definitions use a single shared ECR repository hosted in `us-east-1`
		- task container is Python code from `Source/ecs`
		- task publishes SNS verification payload to the enabled SNS targets and exits
- **Cost-conscious networking**
	- VPC module supports public subnets plus optional private subnets controlled by boolean inputs
	- Private subnets are currently disabled in the live configuration for both regions
	- NAT Gateway creation is also controlled by a boolean input and is currently disabled in both regions
	- dispatcher task runs with public IP in public subnets
- **CI/CD alternatives (only `us-east-1`)**
	- CodePipeline + CodeBuild for ECS image build/push
	- CodePipeline + CodeBuild for Lambda package update
	- Single CI/CD artifact S3 bucket is provisioned in `us-east-1` and used by pipelines
	- Uses single existing CodeStar Connection in `us-east-1`
- **SNS verification topic (only `us-east-1`)**
	- Created via dedicated `sns` module
	- Email subscribers are configured from a variable list in `account.hcl`
- **Security hardening**
	- GitHub deploy role uses least-privilege inline policy (no `AdministratorAccess`)
	- Lambda runtime IAM policy is scoped for DynamoDB/SNS/ECS/PassRole patterns
	- API Gateway stage throttling enabled
	- Optional WAF association supported by HCL inputs (disabled by default)

## Important Input Values

Update these in `live-infrastructure-terragrunt/dev/account.hcl` before apply:

- `candidate_email` 
- `candidate_test_password_secret_name`
- `candidate_repo_url`
- `unleash_verification_topic_arn`
- `sns_topic_name`
- `use_candidate_sns_topic`
- `use_assessor_sns_topic`
- `sns_email_subscribers` 
- `api_throttling_burst_limit`
- `api_throttling_rate_limit`
- `api_enable_waf`
- `api_waf_web_acl_arn` (when WAF is enabled)

SNS routing switches in `live-infrastructure-terragrunt/dev/account.hcl`:

- `use_candidate_sns_topic = true` enables publishing to your SNS topic created by the `sns` stack.
- `use_assessor_sns_topic = true` enables publishing to the assessor topic in `unleash_verification_topic_arn`.
- Set either value to `false` to disable that destination.
- If both are `true`, Lambda and ECS publish to both topics.
- If both are `false`, no SNS publish target is configured.

Already set:

- `codestar_connection_arn = arn:aws:codestar-connections:us-east-1:693389441907:connection/101aea7b-0f41-495b-85f7-3b4f9ba182ef`

## Folder Highlights

- Infra modules: `modules-terraform/*`
- Live env: `live-infrastructure-terragrunt/dev/*`
- Lambda source: `Source/lambda/*`
- ECS task source: `Source/ecs/*`
- Test automation script: `scripts/test_deployment.py`
- CI workflow: `.github/workflows/deploy.yml`

## Multi-region Provider Structure

- Provider configuration is centralized in `live-infrastructure-terragrunt/root.hcl` using a Terragrunt `generate "provider"` block.
- Each stack inherits that generated `provider.tf` through `include "root"`.
- Region selection is driven by `region.hcl` per region (`dev/us-east-1/region.hcl`, `dev/eu-west-1/region.hcl`), so the same Terraform modules run in different regions without duplicating provider blocks.
- Global stacks that do not have a `region.hcl` (for example under `_global`) automatically fall back to `state_region` from `account.hcl`.
- Result: one provider pattern, region-specific execution by Terragrunt live hierarchy.

## Deploy

0) Initial run (this will create the S3 bucket for the .tfstate file)

```bash
# run from the repo root
checkov -d . --framework terraform --quiet --soft-fail --output sarif
cd live-infrastructure-terragrunt
terragrunt.exe run --all init --backend-bootstrap
```

1) Global IAM

```bash
cd live-infrastructure-terragrunt/dev/_global
terragrunt run --all validate
terragrunt run --all plan
terragrunt run --all apply --terragrunt-non-interactive
```

2) `us-east-1` (includes Cognito + CodePipelines + shared ECR + CI/CD S3 artifact bucket)

```bash
cd ../us-east-1
terragrunt run --all validate
terragrunt run --all plan
terragrunt run --all apply --terragrunt-non-interactive
```

3) `eu-west-1` (compute/data only; reuses the shared `us-east-1` ECR)

```bash
cd ../eu-west-1
terragrunt run --all validate
terragrunt run --all plan
terragrunt run --all apply --terragrunt-non-interactive
```

## Build Lambda Bundle (local helper)

```bash
cd Source/lambda
python -m zipfile -c lambda_bundle.zip greeter.py dispatcher.py
```

## Run the Automated Test Script

Install deps:

```bash
pip install -r scripts/requirements.txt
```

Execute:

```bash
USER_POOL_ID=$(cd live-infrastructure-terragrunt/dev/us-east-1/cognito && terragrunt output -raw user_pool_id)
USER_POOL_CLIENT_ID=$(cd live-infrastructure-terragrunt/dev/us-east-1/cognito && terragrunt output -raw user_pool_client_id)
COGNITO_PASSWORD_SECRET_ID=$(cd live-infrastructure-terragrunt/dev/us-east-1/secrets-manager && terragrunt output -raw secret_arn)
API_US_EAST_1=$(cd live-infrastructure-terragrunt/dev/us-east-1/api-gateway && terragrunt output -raw api_endpoint)
API_EU_WEST_1=$(cd live-infrastructure-terragrunt/dev/eu-west-1/api-gateway && terragrunt output -raw api_endpoint)
USERNAME=$(grep -E 'candidate_email\s*=' live-infrastructure-terragrunt/dev/account.hcl | sed -E 's/.*=\s*"([^"]+)".*/\1/')

python scripts/test_deployment.py \
  --cognito-user-pool-id "$USER_POOL_ID" \
  --cognito-client-id "$USER_POOL_CLIENT_ID" \
  --username "$USERNAME" \
  --password-secret-id "$COGNITO_PASSWORD_SECRET_ID" \
  --api-us-east-1 "$API_US_EAST_1" \
  --api-eu-west-1 "$API_EU_WEST_1" \
  --set-password
```

The script does all required checks:

- Authenticates with Cognito and retrieves JWT
- Concurrently calls `/greet` in both regions
- Concurrently calls `/dispatch` in both regions
- Asserts response region matches target region
- Prints latency per call and full response payloads
- Triggers Lambda and ECS flows that publish SNS payloads containing `email` and `repo` values sourced from `candidate_email` and `candidate_repo_url` in `live-infrastructure-terragrunt/dev/account.hcl`

## Validate Deployment with the Test Script

Use this sequence to validate a fresh deployment end-to-end:

1. Deploy stacks in order (`_global` → `us-east-1` → `eu-west-1`) using the commands in the Deploy section.
2. Retrieve runtime values:

```bash
cd live-infrastructure-terragrunt/dev/us-east-1/cognito
terragrunt output -raw user_pool_id
terragrunt output -raw user_pool_client_id

cd ../api-gateway
terragrunt output -raw api_endpoint

cd ../../eu-west-1/api-gateway
terragrunt output -raw api_endpoint
```

3. Run `scripts/test_deployment.py` with those values, the Cognito test username, and the Secrets Manager secret ID/ARN that stores the Cognito test password.
4. Confirm both `/greet` and `/dispatch` succeed in both regions and region assertions pass.
5. Confirm SNS subscription emails are received and payload includes email + GitHub repo link.

## Post-Validation Rotation / Removal

After validation completes, remove test credentials:

1. Rotate or delete the Secrets Manager secret value used for the temporary password.
2. Disable test-user stack by setting:
	- `post_validation_disable_test_user = true` in `live-infrastructure-terragrunt/dev/account.hcl`
3. Re-apply `us-east-1` stack so the Cognito test-user resource is no longer managed/deployed.

## CI/CD Workflow

`.github/workflows/deploy.yml` includes:

- IaC lint/format check (`terraform fmt -check -recursive`)
- Terragrunt validation
- Security scan (Checkov)
- Terragrunt plan commands for both regions (non-blocking in CI without AWS credentials)
- A documented post-deployment test stage showing where `scripts/test_deployment.py` executes in the pipeline
- Optional real execution of that same test stage when OIDC and GitHub environment secrets are configured

## GitHub OIDC Setup for Actions

The workflow uses GitHub OIDC to assume an AWS IAM role at runtime (no long-lived AWS keys in GitHub).

1. Apply global IAM stack first so the OIDC provider and deploy role exist:

```bash
cd live-infrastructure-terragrunt/dev/_global
terragrunt run-all apply --terragrunt-non-interactive
```

2. Get the deploy role ARN output:

```bash
cd live-infrastructure-terragrunt/dev/_global/iam
terragrunt output -raw github_actions_role_arn
```

1. Configure GitHub environment-level secrets:

- In GitHub: `Settings -> Environments` and create `dev`, `stage`, `prod`.
- For each environment, add these secrets:

- `AWS_ROLE_TO_ASSUME` = output from `github_actions_role_arn`
- `COGNITO_TEST_USERNAME` = test Cognito username/email

The workflow binds to the selected environment input, so it automatically reads secrets from that environment and applies any required reviewers/protection rules.

4. Run workflow manually from GitHub Actions (`workflow_dispatch`) and choose:

- `environment`: `dev` / `stage` / `prod`
- `run_apply`: `true` when you want deployment
- `run_tests`: `true` to execute `scripts/test_deployment.py`
- `run_destroy`: `true` for teardown (kept separate from apply)

Notes:

- The workflow blocks running `run_apply=true` and `run_destroy=true` in the same run.
- OIDC trust subjects are configured in `live-infrastructure-terragrunt/dev/account.hcl` (`github_oidc_subjects`).
- The IAM module variable `github_oidc_thumbprints` stores the GitHub Actions OIDC TLS thumbprint used by the AWS IAM OpenID Connect provider. If GitHub rotates certificates in the future, verify the current issuer and metadata from these sources and update the variable if required:
	- https://token.actions.githubusercontent.com
	- https://token.actions.githubusercontent.com/.well-known/openid-configuration
	- https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws
- This satisfies the requirement for a test-execution placeholder for review, while also supporting real post-deploy test execution in the same workflow when credentials are intentionally provided.
