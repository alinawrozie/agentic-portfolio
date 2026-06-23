# Portfolio — AWS Infrastructure as Code

A personal portfolio site, hosted entirely on AWS, fully defined in Terraform. No manual console steps. 

This repository supports two deployment workflows:
1. **Automated CI/CD**: Deployed via GitHub Actions using OIDC federation (no static AWS access keys are stored in secrets).
2. **Manual Local CLI**: Deployed and managed directly from your local terminal using the AWS CLI and Terraform.

```
User → Route 53 → CloudFront (HTTPS) → S3 (private, OAC-only)
                        |
                   API Gateway (HTTP API) → Lambda (Python) → SES → your inbox
```

See [`ADR.md`](./ADR.md) for the reasoning behind the core architectural decisions (serverless backend, CloudFront CDN, and HTTP API Gateway).

---

## Repository Layout

```
infra/bootstrap/   Terraform state backend (S3 + DynamoDB) + GitHub OIDC
                    trust + deploy IAM role (hardened for least-privilege).
infra/              Main infrastructure: ACM, S3, CloudFront, Route 53,
                    Lambda, API Gateway, SES, CloudWatch alarm.
lambda/             Python contact-form handler, packaged by Terraform.
frontend/           Static site (HTML/CSS/JS) synced to S3.
.github/workflows/  CI/CD pipeline: terraform plan/apply, then sync + invalidate.
```

---

## Step 1: Prerequisites & Configuration

Before deploying, make sure you have:
1. An AWS account with credentials configured locally (`aws configure`).
2. [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6 installed.
3. A domain name registered in AWS Route 53.
4. Replace bracketed placeholders inside [frontend/index.html](./frontend/index.html) (name, email, certification links).

---

## Step 2: Bootstrap Remote State & OIDC Trust

To create the secure S3 state backend and configure GitHub OIDC federation:
1. Navigate to the bootstrap folder:
   ```bash
   cd infra/bootstrap
   ```
2. Copy `terraform.tfvars.example` to `terraform.tfvars`:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
3. Edit `terraform.tfvars` with your details (use `agentic-portfolio` as `github_repo`).
4. Initialize and apply:
   ```bash
   terraform init
   terraform apply
   ```
Record the outputs: `state_bucket_name`, `lock_table_name`, and `github_deploy_role_arn`.

---

## Step 3: Reference the Remote State Backend

Open [infra/backend.tf](./infra/backend.tf) and update the values with your bootstrap outputs:
* Set `bucket` to your `state_bucket_name`.
* Set `use_lockfile = true` (or `dynamodb_table` to your `lock_table_name`).

---

## Step 4: Choose Your Deployment Path

Choose **one** of the two paths below to deploy the main portfolio infrastructure and website files:

### Path A: Automated Deploy (GitHub Actions CI/CD)
1. **Configure GitHub Repository Variables**:
   In your repository: **Settings → Secrets and variables → Actions → Variables**, add:
   * `AWS_DEPLOY_ROLE_ARN`: Your `github_deploy_role_arn` output.
   * `DOMAIN_NAME`: e.g. `nawrozie.com`
   * `CONTACT_FORM_RECIPIENT_EMAIL`: Where contact form emails land.
   * `SES_SENDER_EMAIL`: The "from" address SES sends with (can match recipient email).
   * `ALARM_NOTIFICATION_EMAIL`: Where CloudWatch alarm emails go.
2. **Push to main**:
   ```bash
   git add .
   git commit -m "Initial portfolio setup"
   git branch -M main
   git remote add origin https://github.com/<your-username>/agentic-portfolio.git
   git push -u origin main --force
   ```
   GitHub Actions will automatically run `terraform apply`, sync your files, and invalidate the CDN cache.

---

### Path B: Manual Deploy (Local Terminal)
1. **Configure Local Variables**:
   ```bash
   cd infra
   cp terraform.tfvars.example terraform.tfvars
   ```
   Edit `terraform.tfvars` and set your domain name, emails, and set `create_route53_zone = false` (since Route 53 domain registration already created your hosted zone).
2. **Run Terraform**:
   ```bash
   terraform init
   terraform apply
   ```
3. **Configure the Frontend API Endpoint**:
   Get the `contact_api_endpoint` output and update `API_ENDPOINT` on line 6 of [frontend/script.js](./frontend/script.js).
4. **Sync Frontend Files to S3**:
   From the repository root:
   ```bash
   aws s3 sync frontend/ s3://nawrozie.com --delete
   ```
5. **Invalidate CloudFront Cache**:
   ```bash
   aws cloudfront create-invalidation --distribution-id <cloudfront_distribution_id> --paths "/*"
   ```

---

## Step 5: Post-Deployment Verification

1. **Verify SES Sender Email**: Check the inbox of your sender email for an AWS SES verification message and click the verification link.
2. **Confirm SNS Alarm Subscription**: Check the inbox of your alarm email and click the confirmation link from AWS SNS to enable alerts.

---

## Troubleshooting: Error Acquiring State Lock
If a network disconnect occurs during an active apply, Terraform may fail to release the state lock. 
1. Note the lock ID from the terminal error message.
2. Run the unlock command:
   ```bash
   terraform force-unlock <lock-id>
   ```

---

## Estimated Monthly Cost

| Service | Cost |
|---|---|
| Route 53 Hosted Zone | $0.50/mo |
| S3 | < $0.01/mo |
| CloudFront | $0 (Free Tier: 1TB bandwidth) |
| ACM | $0 |
| Lambda | $0 (Free Tier: 1M invocations) |
| API Gateway | $0 (Free Tier: 1M calls) |
| SES | $0 (Free Tier: 62,000 emails/mo) |
| **Total** | **~$0.50/mo** |
