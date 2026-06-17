# Personal Portfolio — AWS, fully as code

A portfolio site hosted on AWS, with the entire stack defined in Terraform:

```
User → Route 53 → CloudFront (HTTPS) → S3 (static site)
                       ↓
            API Gateway → Lambda → SES (contact form)
```

Nothing here is clicked into existence in a console — running `terraform apply`
builds (or rebuilds) the whole thing. See `docs/ADR.md` for the reasoning
behind the three biggest architecture choices.

## Repo layout

```
site/            index.html, styles.css, script.js — the actual page
lambda/          Python Lambda source for the contact form
infra/           Terraform for every AWS resource
scripts/         deploy.sh / destroy.sh — one-command operations
.github/         GitHub Actions: auto-deploy on push, plan on PR
docs/ADR.md      the architecture decision record
```

## Prerequisites

- An AWS account, with the AWS CLI configured (`aws configure`) using credentials that can create the resources below.
- A registered domain. If you registered it through Route 53, a hosted zone already exists for it — use `create_hosted_zone = false`. If it's registered elsewhere, either delegate it to a new Route 53 zone (`create_hosted_zone = true`, then update your registrar's name servers using the `name_servers` output) or use Route 53 as the registrar going forward.
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5.

## First deploy

1. **Configure variables.**

   ```bash
   cp infra/terraform.tfvars.example infra/terraform.tfvars
   ```

   Edit `infra/terraform.tfvars` with your domain and email addresses.

2. **Personalize the site.** Open `site/index.html` and replace every
   `[bracketed placeholder]` — name, role, email, GitHub/LinkedIn handles,
   domain, certification details.

3. **Provision infrastructure and deploy the site in one step:**

   ```bash
   ./scripts/deploy.sh
   ```

   This runs `terraform apply`, then syncs `site/` to the new S3 bucket and
   invalidates the CloudFront cache. It prints the `api_endpoint` output —
   copy that into the `API_ENDPOINT` constant at the top of `site/script.js`,
   then run `./scripts/deploy.sh` again so the updated file ships.

4. **Verify your SES identities.** SES starts in sandbox mode, which requires
   both the sender and recipient addresses to be verified. AWS emails a
   confirmation link to each address right after `apply` — click both. Check
   status anytime with:

   ```bash
   aws ses list-identities --identity-type EmailAddress
   ```

   When you're ready to receive messages from anyone (not just verified
   addresses), request SES production access from the SES console — it's a
   short form, usually approved within a day.

5. **Confirm the CloudWatch alarm subscription.** AWS also emails
   `recipient_email` a subscription-confirmation link for the SNS topic
   behind the Lambda error alarm. Click it, or you won't get notified if the
   contact form starts failing.

6. **Test end to end.** Visit `https://yourdomain.com`, submit the contact
   form, confirm the email arrives. ACM validation and DNS propagation can
   take a few minutes on first deploy — if the site doesn't load immediately,
   wait and retry before debugging.

## Updating the site later

Push to `main` after editing anything in `site/`, and
`.github/workflows/deploy-site.yml` syncs it to S3 and invalidates the
CloudFront cache automatically. For that to work, set these repository
secrets (Settings → Secrets and variables → Actions):

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Credentials for a deploy-scoped IAM user (s3:PutObject/DeleteObject on the bucket, cloudfront:CreateInvalidation on the distribution — not your root or admin keys) |
| `AWS_REGION` | The region from `infra/terraform.tfvars` |
| `S3_BUCKET` | `terraform -chdir=infra output -raw s3_bucket_name` |
| `CLOUDFRONT_DISTRIBUTION_ID` | `terraform -chdir=infra output -raw cloudfront_distribution_id` |

Changing anything under `infra/` instead opens a `terraform plan` on the pull
request (via `terraform-plan.yml`) so you can review what would change before
running `./scripts/deploy.sh` locally to apply it. Add these secrets too if
you want that workflow to run:

| Secret | Value |
|---|---|
| `TF_VAR_DOMAIN_NAME` | your domain |
| `TF_VAR_SENDER_EMAIL` / `TF_VAR_RECIPIENT_EMAIL` | your verified addresses |

## Tearing it down

```bash
./scripts/destroy.sh
```

Destroys every resource Terraform created. Asks you to type the domain name
first, as a confirmation.

## Estimated monthly cost

| Service | Cost |
|---|---|
| Route 53 hosted zone | $0.50/mo |
| S3 (tiny static site) | < $0.01/mo |
| CloudFront (free tier: 1TB, 10M requests) | $0 |
| ACM certificate | $0 |
| Lambda (free tier: 1M requests) | $0 |
| API Gateway (free tier: 1M calls) | $0 |
| SES (free tier: 62,000 emails/mo) | $0 |
| **Total** | **~$0.50–$2/mo** |

Domain registration itself (~$9–$14/yr for `.com`) is separate and one-time
per year, not included above.

## Pushing this to GitHub

This repo is already initialized with one commit. To push it:

```bash
git remote add origin https://github.com/<your-username>/<repo-name>.git
git branch -M main
git push -u origin main
```

Create the empty repository on GitHub first (no README/license/.gitignore —
this repo already has those) and swap in the actual URL above.
