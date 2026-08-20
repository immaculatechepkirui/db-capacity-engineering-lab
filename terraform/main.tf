terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket                      = "regional-health-tfstate"
    key                         = "immaculate/terraform.tfstate"
    region                      = "us-east-1"
    endpoint                    = "http://localhost:4566"
    access_key                  = "test"
    secret_key                  = "test"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
    dynamodb_table              = "regional-health-tflock"
    dynamodb_endpoint           = "http://localhost:4566"
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    ec2            = "http://localhost:4566"
    iam            = "http://localhost:4566"
    s3             = "http://localhost:4566"
    secretsmanager = "http://localhost:4566"
    sts            = "http://localhost:4566"
    elbv2          = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
  }
}

locals {
  tags = {
    Project     = "regional-health"
    Environment = "localstack"
    Owner       = "immaculate"
  }
}

module "data" {
  source = "./modules/data"

  db_host     = var.db_host
  db_port     = var.db_port
  db_username = var.db_username
  db_password = var.db_password
  db_name     = var.db_name

  tags = local.tags
}

module "service" {
  source = "./modules/service"

  service_name = "regional-health-immaculate"
  app_ami_id   = var.app_ami_id
  app_port     = 3000
  secret_arn   = module.data.secret_arn
  db_port      = var.db_port
  db_name      = var.db_name

  tags = local.tags
}

# =============================================================================
# E2 — OIDC production path (design deliverable, not infrastructure)
#
# In production, the deploy job would authenticate to AWS via OIDC instead of
# static credentials. The block below shows the production configuration —
# commented out because LocalStack does not implement OIDC token exchange.
#
# - configure-aws-credentials@v4 exchanges the GitHub OIDC token for temporary
#   AWS credentials via STS AssumeRoleWithWebIdentity.
# - The IAM trust policy below grants access ONLY from the main branch of this
#   specific repo, not from any branch (repo:<org>/*) or any repo.
#
# What breaks if `sub` is `repo:<org>/*`:
#   Any branch in any repo in the org can assume the deploy role. A developer
#   pushing to a feature branch on a fork could trigger a deploy to production.
#   The `sub` condition must be scoped to `ref:refs/heads/main` so only merges
#   to main trigger the role assumption. Wildcards on the subject are the most
#   common OIDC misconfiguration in GitHub Actions pipelines.
#
# Production IAM trust policy:
# {
#   "Version": "2012-10-17",
#   "Statement": [{
#     "Effect": "Allow",
#     "Principal": { "Federated": "arn:aws:iam::<account>:oidc-provider/token.actions.githubusercontent.com" },
#     "Action": "sts:AssumeRoleWithWebIdentity",
#     "Condition": {
#       "StringEquals": {
#         "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
#         "token.actions.githubusercontent.com:sub": "repo:immaculatechepkirui/db-capacity-engineering-lab:ref:refs/heads/main"
#       }
#     }
#   }]
# }
#
# Production workflow step (commented — LocalStack does not support this):
# - uses: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e067355b6578555
#   with:
#     role-to-assume: arn:aws:iam::<account>:role/regional-health-deploy
#     aws-region: us-east-1
# =============================================================================
