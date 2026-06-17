#!/usr/bin/env bash
# Single-command deploy: infra + site content.
# Usage: ./scripts/deploy.sh
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f infra/terraform.tfvars ]; then
  echo "Missing infra/terraform.tfvars — copy infra/terraform.tfvars.example and fill it in first."
  exit 1
fi

echo "==> terraform init / apply"
terraform -chdir=infra init -upgrade
terraform -chdir=infra apply

BUCKET=$(terraform -chdir=infra output -raw s3_bucket_name)
DISTRIBUTION_ID=$(terraform -chdir=infra output -raw cloudfront_distribution_id)
API_ENDPOINT=$(terraform -chdir=infra output -raw api_endpoint)

echo
echo "==> API endpoint: ${API_ENDPOINT}"
echo "    Make sure site/script.js's API_ENDPOINT constant matches this value."
echo

echo "==> syncing site/ to s3://${BUCKET}"
aws s3 sync site/ "s3://${BUCKET}" --delete

echo "==> invalidating CloudFront cache (${DISTRIBUTION_ID})"
aws cloudfront create-invalidation --distribution-id "${DISTRIBUTION_ID}" --paths "/*" >/dev/null

echo
echo "Done. Site URL: $(terraform -chdir=infra output -raw site_url)"
echo "Note: DNS propagation and first-time ACM validation can take a few minutes."
