# ADR-001: Portfolio hosting architecture

**Status:** Accepted
**Context:** Personal portfolio site, low/spiky traffic, single contact form, near-zero ongoing budget, must be rebuildable from code (Terraform) rather than console clicks.

---

## Decision 1 — CloudFront in front of S3, not S3 alone

**Decision:** Serve the site through a CloudFront distribution with a private S3 origin (Origin Access Control), rather than enabling S3 static website hosting directly.

**Why:** S3 website endpoints don't support HTTPS on a custom domain — TLS has to terminate somewhere, and CloudFront is that layer. CloudFront also caches at edge locations close to the visitor, so the recruiter or interviewer loading the page gets sub-100ms response times regardless of which AWS region the bucket lives in, rather than a single round trip to one region. The free tier (1TB transfer, 10M requests/month) comfortably covers a portfolio's traffic, so this costs nothing extra. The trade-off is one more moving part to understand and one layer of cache invalidation to manage on deploy — both of which are exactly the kind of operational detail worth being able to explain in an interview.

**Alternative considered:** A public S3 bucket with website hosting enabled, fronted by nothing. Rejected because it has no HTTPS option for a custom domain, no edge caching, and leaves the bucket policy public — a posture that's hard to defend even for a low-stakes static site.

---

## Decision 2 — Lambda + SES, not a backend server, for the contact form

**Decision:** A single Lambda function calls the SES SendEmail API; there is no EC2 instance, container, or always-on process behind the form.

**Why:** The contact form is invoked rarely and unpredictably — most months, a handful of times. A server sized for that workload is either over-provisioned (paying for idle capacity) or under-provisioned (cold for most of its life, then needs patching anyway). Lambda's pricing and lifecycle match the actual usage pattern: it runs only when someone submits the form, costs nothing between submissions, and there's no OS to patch, no server to monitor for uptime. SES is the natural complement — it's a managed email-sending API, not a mail server to operate. Together they remove every piece of infrastructure that would otherwise sit idle 99.9% of the time.

**Trade-off:** cold starts add roughly 200-500ms of latency on the first invocation after idling, and SES sandbox mode requires manually verifying both sender and recipient addresses before launch (or requesting production access). For a contact form, both are acceptable.

---

## Decision 3 — API Gateway HTTP API, not REST API

**Decision:** The Lambda is fronted by an API Gateway HTTP API with a single `POST /contact` route, rather than a REST API.

**Why:** REST API's extra features — usage plans, request/response transformation templates, API keys, WAF integration at the API Gateway layer — solve problems this project doesn't have: there's one route, one consumer (the site's own JavaScript), and no need for per-client throttling tiers. HTTP API gives the same Lambda-proxy integration and built-in CORS configuration at roughly a third of the cost and with lower latency, because it does less work per request. If this evolves into something with multiple API consumers, fine-grained auth, or request validation needs, migrating that one route to REST API is a contained change — not a reason to pay for those features now.

---

*Each decision optimizes for the same thing: match the infrastructure's cost and operational weight to a portfolio site's actual traffic and risk profile, while keeping every piece defined in Terraform so the whole stack is reproducible from this repository alone.*
