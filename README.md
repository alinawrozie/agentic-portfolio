# Portfolio — AWS Infrastructure as Code

A personal portfolio site, hosted entirely on AWS, fully defined in
Terraform. No manual console steps. Deployed via GitHub Actions using OIDC
federation — there is no AWS access key sitting in this repo's secrets at
any point.

```
User → Route 53 → CloudFront (HTTPS) → S3 (private, OAC-only)
                        |
                   API Gateway (HTTP API) → Lambda (Python) → SES → your inbox
```

See [`ADR.md`](./ADR.md) for the reasoning behind the three core architecture
decisions.

## Repository layout

```
infra/bootstrap/   Terraform state backend (S3 + DynamoDB) + GitHub OIDC
                    trust + deploy IAM role. Applied manually, ONCE, by you.
infra/              Main infrastructure: ACM, S3, CloudFront, Route 53,
                    Lambda, API Gateway, SES, CloudWatch alarm. Applied by
                    GitHub Actions (and optionally by you locally).
lambda/             Python contact-form handler, packaged by Terraform.
frontend/           Static site (HTML/CSS/JS) synced to S3 on every deploy.
.github/workflows/  CI/CD pipeline: terraform plan/apply, then sync + invalidate.
```

## One-time setup

### 1. Prerequisites

- An AWS account with credentials configured locally (`aws configure`) —
  used only for the one-time bootstrap step below, never stored anywhere
  after.
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6
- A domain name you control (registered via Route 53 or elsewhere)
- This repo pushed to GitHub

### 2. Bootstrap: state backend + GitHub OIDC trust

```bash
cd infra/bootstrap
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: state_bucket_name, github_org, github_repo, github_branch

terraform init
terraform apply
```

This creates:
- An S3 bucket + DynamoDB table to hold the main config's remote Terraform
  state (with locking, so a local `apply` and a CI `apply` can't collide).
- An IAM OIDC identity provider trusting `token.actions.githubusercontent.com`.
- An IAM role (`<repo>-github-actions-deploy`) that only your exact
  `org/repo` on your exact branch can assume — and only via a short-lived
  token GitHub mints per workflow run. No access key, no secret, nothing to
  rotate or leak.

Note the two outputs `state_bucket_name` and `github_deploy_role_arn` — you need them next.

### 3. Point the main config at that state backend

Edit `infra/backend.tf`: replace the placeholder `bucket` and
`dynamodb_table` values with the bootstrap outputs.

### 4. Configure GitHub repository variables

In your GitHub repo: **Settings → Secrets and variables → Actions → Variables**, add:

| Variable | Value |
|---|---|
| `AWS_DEPLOY_ROLE_ARN` | the `github_deploy_role_arn` bootstrap output |
| `DOMAIN_NAME` | e.g. `yourname.com` |
| `CONTACT_FORM_RECIPIENT_EMAIL` | where form submissions land |
| `SES_SENDER_EMAIL` | the SES "from" address (can match the above) |
| `ALARM_NOTIFICATION_EMAIL` | where CloudWatch alarm emails go |

These are plain repository **variables**, not secrets — nothing here is
sensitive (it's a domain name and email addresses), and the workflow reads
them as `vars.*`.

### 5. Push to `main`

```bash
git add .
git commit -m "Initial infrastructure and site content"
git branch -M main
git remote add origin https://github.com/<your-org>/<your-repo>.git
git push -u origin main
```

GitHub Actions takes it from there: `terraform plan` → `terraform apply` →
sync `frontend/` to S3 → invalidate the CloudFront cache.

### 6. After the first apply

A few things Terraform deliberately can't automate, because AWS requires a
human in the loop:

- **Nameservers** (only if `create_route53_zone = true`): run
  `terraform output route53_nameservers` and update your domain registrar to
  point at them. DNS propagation can take up to 48 hours, though it's
  usually much faster.
- **SES verification**: check the inbox for `SES_SENDER_EMAIL` (and the
  recipient address, if different) for an AWS verification email, and click
  the link. The contact form will fail until this is done.
- **SNS alarm subscription**: check the inbox for `ALARM_NOTIFICATION_EMAIL`
  for an SNS subscription confirmation email, and confirm it.

### 7. Wire up the frontend's API endpoint

After the first successful apply, get the contact form endpoint:

```bash
cd infra
terraform output contact_api_endpoint
```

Put that value into `CONTACT_API_ENDPOINT` in `frontend/script.js`, commit,
and push — the next CI run syncs it to S3 and invalidates the cache.

Also replace the `REPLACE_ME` placeholders in `frontend/index.html` (GitHub
link) with your actual repo URL.

## Local development / manual apply (optional)

CI handles deploys, but you can also run Terraform locally against the same
remote state:

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # fill in your values
terraform init
terraform plan
terraform apply
```

Because state is remote and locked (via the DynamoDB table from bootstrap),
this is safe to do even with CI also configured — Terraform will queue
rather than corrupt state if both run close together.

## Updating the site after this initial setup

- **Content changes** (new project, new certification): edit
  `frontend/index.html`, push to `main`. CI syncs S3 and invalidates the
  CloudFront cache automatically — no Terraform involved.
- **Infrastructure changes** (e.g. a new CloudWatch alarm, a new Lambda
  environment variable): edit the relevant `.tf` file, push to `main`. CI
  runs `terraform plan` then `terraform apply`.
- **Pull requests**: the workflow runs `terraform plan` (not `apply`) on PRs
  against `main`, so you get a preview of infrastructure changes before
  merging.

## Estimated monthly cost

| Service | Cost |
|---|---|
| Route 53 hosted zone | $0.50/mo |
| S3 | < $0.01/mo |
| CloudFront | $0 (free tier: 1TB/10M requests) |
| ACM | $0 |
| Lambda | $0 (free tier: 1M requests) |
| API Gateway | $0 (free tier: 1M calls) |
| SES | $0 (free tier: 62,000 emails/mo) |
| **Total** | **~$0.50–$2/mo** |

(Excludes one-time domain registration, ~$9–$14/yr for `.com`.)
