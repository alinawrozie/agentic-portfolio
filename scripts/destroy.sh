#!/usr/bin/env bash
# Tears down every AWS resource this project created.
# Usage: ./scripts/destroy.sh
set -euo pipefail

cd "$(dirname "$0")/.."

echo "This will DESTROY all AWS resources for this project (S3 bucket, CloudFront,"
echo "Route 53 records, Lambda, API Gateway, SES identities, CloudWatch alarm/SNS)."
read -rp "Type the domain name to confirm: " confirm_domain

domain_in_state=$(terraform -chdir=infra output -raw site_url 2>/dev/null | sed 's#https://##' || true)

if [ "$confirm_domain" != "$domain_in_state" ]; then
  echo "Domain didn't match (${domain_in_state:-unknown}). Aborting."
  exit 1
fi

terraform -chdir=infra destroy
