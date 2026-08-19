terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "regional-health-tfstate"
    key            = "immaculate/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "regional-health-tflock"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
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
