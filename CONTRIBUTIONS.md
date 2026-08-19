# CONTRIBUTIONS.md

## Group platform (shared repo: mercykilonzo/regional-health-platform)

| Module | Sole author | Reviewed by |
|---|---|---|
| modules/data — Secrets Manager + Aiven creds | Mercy (PR-1) | Immaculate |
| .github/workflows/golden-pipeline.yml | Mercy (PR-2) | Immaculate |
| modules/service — EC2 + ALB + SGs | Immaculate (PR-3) | Mercy |

## Individual rehost (this repo)

| Item | Owner |
|---|---|
| terraform/main.tf — root module composing modules/data + modules/service | Immaculate (PR-4) |
| api/secrets.js — GetSecretValue at boot | Immaculate |
| Makefile — make up / make verify | Immaculate |
| FIDELITY.md | Immaculate |
| evidence/ bundle | Immaculate |
