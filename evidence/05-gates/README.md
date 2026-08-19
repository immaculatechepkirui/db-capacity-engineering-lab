# Gate evidence — three PRs that went red

## Gate 1: gitleaks
PR: [link to test/gitleaks-gate PR]
Change introduced: fake DB_PASSWORD in .env.example
Scanner output: gitleaks detected 1 finding — Generic API Key pattern
Fix: removed .env.example, added to .gitignore

What gitleaks does NOT catch:
- Secrets already committed before gitleaks was added (unless --no-git is used)
- Secrets in binary files
- Custom secret patterns not in its default ruleset

## Gate 2: trivy (config)
PR: [link to test/trivy-gate PR]
Change introduced: 0.0.0.0/0 on instance SG ingress
Scanner output: trivy flagged AVD-AWS-0107 — security group allows ingress from anywhere
Fix: scoped ingress to VPC CIDR, added documented exception to .trivyignore for ALB only

What trivy config does NOT catch:
- Runtime misconfigurations (e.g. IAM policies granted via console after apply)
- Secrets in application code (gitleaks covers this)
- Vulnerabilities introduced after the image is built

## Gate 3: zizmor
PR: [link to test/zizmor-gate PR]
Change introduced: actions/checkout@main (unpinned tag)
Scanner output: zizmor flagged unpinned action reference
Fix: pinned to full commit SHA

What zizmor does NOT catch:
- A pinned SHA that is itself malicious (integrity, not trust)
- Secrets leaked via environment variables at runtime
- Non-GitHub CI platforms
