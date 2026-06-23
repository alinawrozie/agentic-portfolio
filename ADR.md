# Architecture Decision Record: Personal Portfolio Infrastructure

**Status:** Accepted
**Date:** 2026-06-21

## Context

This document records the reasoning behind three infrastructure decisions made
while building a portfolio site on AWS, hosted at a custom domain, with a
serverless contact form. The full system is defined in Terraform under
`infra/` and deployed via GitHub Actions using OIDC federation (no static
AWS credentials stored anywhere).

---

## Decision 1: CloudFront in front of S3, rather than serving S3 directly

**Decision:** All traffic is routed through a CloudFront distribution. The S3
bucket is private and only readable by CloudFront via Origin Access Control
(OAC); it is not configured for S3's legacy "static website hosting" feature.

**Why:**

- **HTTPS.** S3 static website hosting endpoints only serve plain HTTP. A
  portfolio with no TLS would fail a basic security review on sight.
  CloudFront is what lets a free ACM certificate attach to the domain at
  all.
- **Custom domain with HTTPS together.** S3 REST endpoints support HTTPS, but
  not on a custom domain name without giving up encryption at the apex.
  CloudFront resolves this by terminating TLS at the edge using the ACM
  certificate.
- **Latency and cost.** CloudFront caches content at edge locations close to
  the visitor, rather than every request crossing the Atlantic (or wherever)
  to a single S3 region. For a CV-facing site, the first impression of "the
  page loaded instantly" matters more than it might seem.
- **Reduced attack surface.** Because the bucket is private and only
  CloudFront's OAC has read access, there's no public bucket policy to
  misconfigure, no risk of someone discovering and scraping the bucket
  directly, and no path that bypasses caching/TLS.

**Trade-off accepted:** Cache invalidation adds a small amount of deploy
complexity (the CI/CD pipeline calls `cloudfront create-invalidation` after
every sync) and CloudFront introduces a layer that has to be understood when
debugging. Worth it for the security and performance gain.

---

## Decision 2: Lambda + SES instead of a backend server for the contact form

**Decision:** Form submissions are handled by a single Lambda function that
validates input and calls the SES `SendEmail` API directly. There is no
EC2 instance, container, or always-on backend process.

**Why:**

- **Workload shape.** A personal contact form might receive a handful of
  submissions a week. An EC2 instance or container running 24/7 to handle
  that is almost entirely idle compute - the AWS free tier covers Lambda's
  1M monthly invocations and SES's 62,000 monthly emails, so the realistic
  cost is $0, versus a minimum of several dollars a month for the smallest
  EC2 instance, even idle.
- **No infrastructure to patch or run.** There's no OS to patch, no process
  to keep alive, no server to harden. AWS manages the Lambda execution
  environment; the only thing to maintain is the ~120 lines of Python in
  `lambda/handler.py`.
- **Built-in scaling and isolation.** If the form were ever linked from
  somewhere with real traffic, Lambda scales out automatically per request
  rather than needing a load balancer and auto-scaling group configured by
  hand. Each invocation is isolated, which also limits blast radius if
  something misbehaves.
- **SES over a third-party form/email API.** Using SES directly, rather than
  a SaaS form backend or general email API, means the entire path stays
  inside AWS, fits the project's IAM/least-privilege model (the Lambda's
  execution role can only call `ses:SendEmail` from one verified identity),
  and costs nothing within free tier limits.

**Trade-off accepted:** Cold starts add a small amount of latency (typically
under a second) to the first request after idle, which is irrelevant for a
contact form a visitor fills in once. SES also starts in "sandbox" mode,
requiring manually verified sender/recipient addresses until production
access is requested - acceptable since this form only ever needs to deliver
mail to one inbox.

---

## Decision 3: API Gateway HTTP API instead of REST API

**Decision:** The contact form endpoint is built on API Gateway's **HTTP
API** product (`aws_apigatewayv2_*` resources), not the older **REST API**
product (`aws_api_gateway_*`).

**Why:**

- **Cost.** HTTP APIs are roughly 70% cheaper per request than REST APIs,
  and within the free tier (1M HTTP API calls/month) it's free either way -
  but it's the right default for any project where traffic might eventually
  exceed the free tier.
- **Built-in CORS.** REST APIs require manually defining an `OPTIONS` method
  with a mock integration and matching response headers to support
  cross-origin requests from the frontend's JavaScript `fetch()` call. HTTP
  APIs support CORS as a first-class block in the API resource itself
  (`cors_configuration { ... }` in `infra/api_gateway.tf`), which is less
  Terraform, less to get wrong, and easier to read.
- **Simpler integration model.** This project needs exactly one route
  (`POST /contact`) proxying to exactly one Lambda function. HTTP API's
  Lambda proxy integration (payload format 2.0) is a more direct mapping for
  that shape than REST API's resource/method/integration/deployment/stage
  hierarchy, which exists to support API behaviors (request/response
  transformation, API keys, usage plans, WAF integration at the API Gateway
  layer) this project doesn't need.

**Trade-off accepted:** REST API has some features HTTP API still lacks
(e.g. request validation models, more granular usage plans, native AWS WAF
association at time of writing). None of those are relevant to a single
public POST endpoint with input validation handled in the Lambda itself, so
HTTP API is the better fit here, with the explicit understanding that a
future project needing those features would warrant REST API instead.

---

## Summary

| Decision | Chosen | Rejected | Primary reason |
|---|---|---|---|
| CDN/origin | CloudFront → private S3 (OAC) | Direct S3 website hosting | HTTPS on a custom domain; reduced attack surface |
| Contact form compute | Lambda + SES | EC2/container backend | Idle-cost elimination; nothing to patch |
| API layer | API Gateway HTTP API | API Gateway REST API | Cost; native CORS; simpler for one route |
